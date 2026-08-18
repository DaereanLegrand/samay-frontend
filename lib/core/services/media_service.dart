import 'dart:io';

import 'package:samay/core/errors/app_error.dart';
import 'dart:typed_data';

import 'package:samay/core/utils/image_processor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Supabase Storage: group covers, event photos and signed URLs.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11). Named `MediaService` to avoid a clash with the
/// existing `SecureStorageService`/`HiveService` in
/// `lib/core/services/storage_service.dart`.
class MediaService {
  final SupabaseClient client;

  MediaService({required this.client});

  GoTrueClient get auth => client.auth;

  /// Uploads a group cover into the `groups` bucket and returns its public
  /// URL.
  ///
  /// The payload is downscaled client-side first ([ImageProcessor.compress] —
  /// finding PERF-03/M-36): full-resolution camera photos become 1920px PNGs,
  /// slashing upload size. The stored object is always a PNG, so the storage
  /// path uses the `.png` extension regardless of the source format.
  Future<String> uploadGroupCover(Uint8List bytes) async {
    final processed = await ImageProcessor.compressBytes(bytes);
    final path = 'group_covers/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('groups').uploadBinary(path, processed);
    return client.storage.from('groups').getPublicUrl(path);
  }

  /// Uploads an event cover into the public `groups` bucket and returns its
  /// public URL (ECRT step 2 — I-54; S-09 bucket bug fixed).
  ///
  /// Mirrors [uploadGroupCover]: the payload is downscaled client-side first
  /// ([ImageProcessor.compressBytes]) and the stored object is always a PNG.
  /// The ECRT spec's `events/{event_id}/cover` layout cannot be used from the
  /// creation form because `event_id` only exists after `createEvent` returns
  /// — the timestamped `event_covers/` layout is uploaded *before* the event
  /// row and its public URL is passed in as `events.cover_url`.
  ///
  /// The cover MUST live in the public `groups` bucket, not the private
  /// `events` bucket (S-09/M-08 handoff): the `events` bucket is public=false
  /// and serves only signed URLs, so `getPublicUrl` on it returns nothing —
  /// and a signed URL would expire while `events.cover_url` is stored for the
  /// event's lifetime. The `groups` bucket is public=true and its read
  /// policy (`storage_objects_public_read_avatars_groups`) plus the own-row
  /// INSERT policy (`storage_objects_insert_own`) cover this upload exactly
  /// like [uploadGroupCover]'s.
  Future<String> uploadEventCover(Uint8List bytes) async {
    final processed = await ImageProcessor.compressBytes(bytes);
    final path = 'event_covers/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('groups').uploadBinary(path, processed);
    return client.storage.from('groups').getPublicUrl(path);
  }

  /// Uploads the current user's avatar into the `avatars` bucket and returns
  /// its public URL (PRFL avatar-upload gap — I-36).
  ///
  /// Mirrors [uploadGroupCover]: the payload is downscaled client-side first
  /// ([ImageProcessor.compressBytes]), the stored object is always a PNG, and
  /// the path is namespaced per user so one bucket serves every avatar
  /// (`<userId>/<timestamp>.png`). The path is relative to the bucket — no
  /// `avatars/` prefix — because the storage RLS INSERT policy
  /// (`storage_objects_insert_own`, migration 20260810000007) requires the
  /// first path segment to equal `auth.jwt()->>'sub'`. Requires the `avatars`
  /// storage bucket to exist (creation is out of scope for the app layer —
  /// see the I-36 daily log).
  Future<String> uploadUserAvatar(String userId, Uint8List bytes) async {
    final processed = await ImageProcessor.compressBytes(bytes);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('avatars').uploadBinary(path, processed);
    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Uploads an event photo payload into the `events` bucket at
  /// `{eventId}/photos/{uuid}.png` and records the `event_photos` row (PHUP —
  /// I-59).
  ///
  /// This is the bytes variant the image_picker + [ImageProcessor] pipeline
  /// feeds (I-22): the payload is downscaled client-side first, so the stored
  /// object is always a PNG like every other MediaService upload. Requires
  /// the `events` storage bucket + the `event_photos` INSERT policy
  /// (`eph_insert_own`) to exist.
  Future<void> uploadEventPhotoBytes(String eventId, Uint8List bytes) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final processed = await ImageProcessor.compressBytes(bytes);
    final storagePath = '$eventId/photos/${const Uuid().v4()}.png';

    await client.storage.from('events').uploadBinary(storagePath, processed);
    await client.from('event_photos').insert({
      'event_id': eventId,
      'uploaded_by_user_id': user.id,
      'storage_path': storagePath,
      'likes_count': 0,
      'reported': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// File-path variant of [uploadEventPhotoBytes] for callers that hold a
  /// local file instead of bytes (kept from the pre-PHUP build; the bytes
  /// variant is the primary seam — I-59).
  Future<void> uploadEventPhoto(String eventId, String filePath) async {
    final bytes = await _readFileBytes(filePath);
    await uploadEventPhotoBytes(eventId, bytes);
  }

  /// Every photo of [eventId], newest first (`event_photos` rows; the gallery
  /// resolves signed URLs through [getSignedPhotoUrl] afterwards).
  Future<List<Map<String, dynamic>>> listEventPhotos(String eventId) async {
    final res = await client
        .from('event_photos')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: false);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<String> getSignedPhotoUrl(String storagePath) async {
    final res = await client.storage
        .from('events')
        .createSignedUrl(storagePath, 3600);
    return res;
  }

  Future<Uint8List> _readFileBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }
}
