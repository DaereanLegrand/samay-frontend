import 'dart:io';
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
    final path =
        'group_covers/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('groups').uploadBinary(path, processed);
    return client.storage.from('groups').getPublicUrl(path);
  }

  /// Uploads an event cover into the `events` bucket and returns its public
  /// URL (ECRT step 2 — I-54).
  ///
  /// Mirrors [uploadGroupCover]: the payload is downscaled client-side first
  /// ([ImageProcessor.compressBytes]) and the stored object is always a PNG.
  /// The ECRT spec's `events/{event_id}/cover` layout cannot be used from the
  /// creation form because `event_id` only exists after `createEvent` returns
  /// — the timestamped `event_covers/` layout is uploaded *before* the event
  /// row and its public URL is passed in as `events.cover_url`.
  Future<String> uploadEventCover(Uint8List bytes) async {
    final processed = await ImageProcessor.compressBytes(bytes);
    final path =
        'event_covers/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('events').uploadBinary(path, processed);
    return client.storage.from('events').getPublicUrl(path);
  }

  /// Uploads the current user's avatar into the `avatars` bucket and returns
  /// its public URL (PRFL avatar-upload gap — I-36).
  ///
  /// Mirrors [uploadGroupCover]: the payload is downscaled client-side first
  /// ([ImageProcessor.compressBytes]), the stored object is always a PNG, and
  /// the path is namespaced per user so one bucket serves every avatar
  /// (`avatars/<userId>/<timestamp>.png`). Requires the `avatars` storage
  /// bucket to exist (creation is out of scope for the app layer — see the
  /// I-36 daily log).
  Future<String> uploadUserAvatar(String userId, Uint8List bytes) async {
    final processed = await ImageProcessor.compressBytes(bytes);
    final path =
        'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.png';
    await client.storage.from('avatars').uploadBinary(path, processed);
    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Uploads an event photo from a local [filePath] into the `events` bucket
  /// and records the `event_photos` row.
  Future<void> uploadEventPhoto(String eventId, String filePath) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final bytes = await _readFileBytes(filePath);
    final extension = filePath.split('.').last;
    final storagePath = '$eventId/photos/${const Uuid().v4()}.$extension';

    await client.storage.from('events').uploadBinary(storagePath, bytes);
    await client.from('event_photos').insert({
      'event_id': eventId,
      'uploaded_by_user_id': user.id,
      'storage_path': storagePath,
      'likes_count': 0,
      'reported': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> getSignedPhotoUrl(String storagePath) async {
    final res = await client.storage.from('events').createSignedUrl(storagePath, 3600);
    return res;
  }

  Future<Uint8List> _readFileBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }
}
