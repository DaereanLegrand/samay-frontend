import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:samay/core/models/event_photo.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/event_service.dart';
import 'package:samay/core/services/media_service.dart';

/// `app_config` key for the post-event photo upload window (seeded as `24`
/// in seed.sql).
const photoUploadWindowHoursKey = 'events.photo_upload_window_hours';

/// Fallback when the config row is missing or unparsable.
const photoUploadWindowHoursDefault = 24;

/// Resolves the configured upload-window length in hours.
int photoUploadWindowHours(Map<String, String> appConfig) {
  return int.tryParse(appConfig[photoUploadWindowHoursKey] ?? '') ??
      photoUploadWindowHoursDefault;
}

/// Whether the upload window is open: during the event (now ≤ endsAt)
/// and up to [windowHours] after `ends_at`. A missing/unknown event end is
/// treated as closed (fail-closed — never advertise uploads for a broken
/// event row).
bool isPhotoUploadWindowOpen(DateTime now, DateTime? endsAt, int windowHours) {
  if (endsAt == null) return false;
  return !now.isAfter(endsAt.add(Duration(hours: windowHours)));
}

/// Per-photo signed-URL cache with expiry-based refresh.
///
/// Signed URLs from Supabase Storage expire after 1 hour; re-issuing one per
/// rebuild would burn a storage API call per photo per refresh. The cache
/// returns the entry while it is within its TTL (minus a [grace] window so a
/// URL is replaced *before* the storage layer starts rejecting it), and
/// re-fetches once expired. A hard 401/expiry on the image itself is healed
/// via [invalidate] (the gallery's retry path re-fetches the URL).
class SignedUrlCache {
  SignedUrlCache({
    this.ttl = const Duration(hours: 1),
    this.grace = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final Duration grace;
  final DateTime Function() _clock;

  final Map<String, _SignedUrlEntry> _entries = {};

  /// Cached URL for [photoId] when valid, otherwise [fetch] re-issues it and
  /// stores the result for the next [ttl] window.
  Future<String> urlFor(String photoId, Future<String> Function() fetch) async {
    final cached = _entries[photoId];
    final now = _clock();
    if (cached != null &&
        !now.isAfter(cached.expiresAt.subtract(grace))) {
      return cached.url;
    }
    final url = await fetch();
    _entries[photoId] = _SignedUrlEntry(url, now.add(ttl));
    return url;
  }

  /// Drops the cached entry so the next [urlFor] re-fetches (401 self-heal).
  void invalidate(String photoId) => _entries.remove(photoId);
}

class _SignedUrlEntry {
  _SignedUrlEntry(this.url, this.expiresAt);

  final String url;
  final DateTime expiresAt;
}

/// Gallery state: `event_photos` rows enriched with per-photo signed URLs and
/// the current user's `likedByMe` flag.
class EventPhotosNotifier
    extends FamilyAsyncNotifier<List<EventPhoto>, String> {
  MediaService get _media => ref.read(mediaServiceProvider);
  EventService get _events => ref.read(eventServiceProvider);

  final SignedUrlCache _urlCache = SignedUrlCache();

  @override
  Future<List<EventPhoto>> build(String eventId) async {
    final rows = await _media.listEventPhotos(eventId);
    final myLikes = (await _events.getMyPhotoLikes(eventId)).toSet();
    return Future.wait([
      for (final row in rows)
        () async {
          final photo = EventPhoto.fromJson(row);
          final url = await _urlCache.urlFor(
            photo.id,
            () => _media.getSignedPhotoUrl(photo.storagePath),
          );
          return photo.copyWith(
            signedUrl: url,
            likedByMe: myLikes.contains(photo.id),
          );
        }(),
    ]);
  }

  /// Re-runs [build] (pull-to-refresh, new uploads, recovery).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Re-issues the signed URL for [photoId] without a full reload — the
  /// self-heal path for a 401/expired tile (see [SignedUrlCache]).
  Future<void> refreshSignedUrl(String photoId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.indexWhere((p) => p.id == photoId);
    if (index < 0) return;
    _urlCache.invalidate(photoId);
    final url = await _media.getSignedPhotoUrl(current[index].storagePath);
    state = AsyncData([
      for (var i = 0; i < current.length; i++)
        i == index ? current[i].copyWith(signedUrl: url) : current[i],
    ]);
  }

  /// Optimistic like toggle with rollback: flips the tile and count
  /// immediately, reverts when the insert/delete fails.
  ///
  /// The service calls are idempotent (`event_photo_likes` has a
  /// `UNIQUE (photo_id, user_id)` constraint and [EventService.likePhoto]
  /// pre-checks), so double-taps cannot double-count.
  Future<void> toggleLike(String photoId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.indexWhere((p) => p.id == photoId);
    if (index < 0) return;

    final target = !current[index].likedByMe;
    final optimistic = [
      for (var i = 0; i < current.length; i++)
        i == index
            ? current[i].copyWith(
                likedByMe: target,
                likesCount: _boundedCount(
                  current[i].likesCount + (target ? 1 : -1),
                ),
              )
            : current[i],
    ];
    state = AsyncData(optimistic);

    try {
      if (target) {
        await _events.likePhoto(photoId);
      } else {
        await _events.unlikePhoto(photoId);
      }
    } catch (_) {
      state = AsyncData(current); // rollback
      rethrow;
    }
  }

  /// Submits a moderation report for [photoId] (long-press report →
  /// `reports` row, `target_type = 'photo'`; the photo stays visible pending
  /// admin review).
  Future<void> report(String photoId, String reason) {
    return ref
        .read(moderationServiceProvider)
        .reportContent('photo', photoId, reason);
  }

  static int _boundedCount(int count) => count < 0 ? 0 : count;
}

/// The event's photos, newest first.
final eventPhotosProvider = AsyncNotifierProvider.family<EventPhotosNotifier,
    List<EventPhoto>, String>(EventPhotosNotifier.new);

/// Upload lifecycle for the gallery's submit action.
enum PhotoUploadStatus { idle, uploading, uploaded }

class PhotoUploadState {
  const PhotoUploadState._(this.status);

  const PhotoUploadState.idle() : this._(PhotoUploadStatus.idle);
  const PhotoUploadState.uploading() : this._(PhotoUploadStatus.uploading);
  const PhotoUploadState.uploaded() : this._(PhotoUploadStatus.uploaded);

  final PhotoUploadStatus status;

  bool get isUploading => status == PhotoUploadStatus.uploading;
}

/// One-shot upload action: feed raw picked bytes to the
/// MediaService upload (which downscales + JPEG-encodes) → reload the gallery.
/// The picker + permission layer stays in the screen; this provider owns the
/// pipeline so the flow is testable without the image_picker plugin.
class PhotoUploadNotifier extends AsyncNotifier<PhotoUploadState> {
  @override
  Future<PhotoUploadState> build() async => const PhotoUploadState.idle();

  Future<void> upload(String eventId, XFile file) async {
    state = const AsyncData(PhotoUploadState.uploading());
    try {
      final bytes = await file.readAsBytes();
      // [MediaService.uploadEventPhotoBytes] owns the client-side downscale +
      // JPEG re-encode; the provider only feeds it raw picked bytes.
      await ref.read(mediaServiceProvider).uploadEventPhotoBytes(eventId, bytes);
      state = const AsyncData(PhotoUploadState.uploaded());
      ref.invalidate(eventPhotosProvider(eventId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

/// Upload state for the gallery app bar (idle → uploading → uploaded).
final uploadPhotoProvider =
    AsyncNotifierProvider<PhotoUploadNotifier, PhotoUploadState>(
        PhotoUploadNotifier.new);
