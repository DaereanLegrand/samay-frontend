import 'package:freezed_annotation/freezed_annotation.dart';

part 'event_photo.freezed.dart';
part 'event_photo.g.dart';

@freezed
abstract class EventPhoto with _$EventPhoto {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory EventPhoto({
    required String id,
    required String eventId,
    required String uploadedByUserId,
    required String storagePath,
    @Default(0) int likesCount,
    @Default(false) bool reported,
    required DateTime createdAt,
    /// Signed URL resolved client-side by the gallery provider (PHUP — I-59).
    /// Never present in the `event_photos` row; filled via `copyWith` once the
    /// storage client issues it, null until then.
    String? signedUrl,
    /// Whether the current user has liked this photo (one like per user per
    /// photo). Resolved from `event_photo_likes` by the gallery provider, not
    /// stored on the row.
    @Default(false) bool likedByMe,
  }) = _EventPhoto;

  factory EventPhoto.fromJson(Map<String, dynamic> json) =>
      _$EventPhotoFromJson(json);
}
