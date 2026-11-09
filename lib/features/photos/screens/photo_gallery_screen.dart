import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event_photo.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/photos/providers/photos_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_spinner.dart';
import 'package:samay/shared/widgets/report_sheet.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Gallery-picking seam for tests: `image_picker` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable function
/// (same thin-wrapper pattern as `CreateEventScreen`/`CreateGroupScreen`).
typedef PhotoPicker = Future<XFile?> Function(ImageSource source);

/// Event photo gallery: grid of thumbnails served via signed
/// URLs, optimistic like hearts, long-press reporting, and the upload flow
/// (pick → preview-less upload through `uploadPhotoProvider`).
///
/// The upload button only renders while the upload window is open (live +
/// `events.photo_upload_window_hours` after `ends_at` from `app_config`);
/// the closed window renders a notice instead.
class PhotoGalleryScreen extends ConsumerStatefulWidget {
  const PhotoGalleryScreen({super.key, required this.eventId, this.picker});

  final String eventId;

  /// Injectable for tests; defaults to `ImagePicker.pickImage(gallery)`.
  final PhotoPicker? picker;

  @override
  ConsumerState<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends ConsumerState<PhotoGalleryScreen> {
  late final PhotoPicker _picker =
      widget.picker ?? ((source) => ImagePicker().pickImage(source: source));

  Future<void> _pickAndUpload() async {
    final l10n = AppLocalizations.of(context);
    final file = await _picker(ImageSource.gallery);
    if (file == null || !mounted) return;

    try {
      await ref.read(uploadPhotoProvider.notifier).upload(widget.eventId, file);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.photosUploadedSnack)));
    } catch (e, _) {
      if (mounted) showAppError(context, e);
    }
  }

  Future<void> _toggleLike(String photoId) async {
    try {
      await ref
          .read(eventPhotosProvider(widget.eventId).notifier)
          .toggleLike(photoId);
    } catch (e, _) {
      if (mounted) showAppError(context, e);
    }
  }

  Future<void> _report(EventPhoto photo) async {
    await showReportSheet(
      context,
      ref,
      targetType: 'photo',
      targetId: photo.id,
      title: AppLocalizations.of(context).photosReportTitle,
    );
  }

  bool _uploadWindowOpen(DateTime? endsAt, int windowHours) {
    return isPhotoUploadWindowOpen(DateTime.now(), endsAt, windowHours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final photosAsync = ref.watch(eventPhotosProvider(widget.eventId));
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final config = ref.watch(appConfigProvider).valueOrNull ?? const {};
    final uploadState = ref.watch(uploadPhotoProvider).valueOrNull;
    final windowHours = photoUploadWindowHours(config);
    final endsAt = eventAsync.valueOrNull?.endsAt;
    final windowOpen = _uploadWindowOpen(endsAt, windowHours);
    final uploading = uploadState?.isUploading ?? false;

    return Scaffold(
      body: VHeaderBar(
        title: l10n.photosTitle.toLowerCase(),
        actions: [
          if (windowOpen)
            IconButton(
              key: const ValueKey('photos-upload-button'),
              tooltip: l10n.photosUpload,
              onPressed: uploading ? null : _pickAndUpload,
              icon: uploading
                  ? const VSpinner(size: 18)
                  : const Icon(Icons.add_a_photo_outlined),
            ),
          // The collage auto-wall entry.
          IconButton(
            key: const ValueKey('photos-wall-button'),
            tooltip: l10n.collageTitle,
            onPressed: () =>
                context.push(RoutePaths.eventCollage(widget.eventId)),
            icon: const Icon(Icons.grid_view_outlined),
          ),
        ],
        child: Column(
          children: [
            if (!windowOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    border: Border.all(color: context.palette.hairline),
                  ),
                  child: Text(
                    l10n.photosUploadWindowClosed,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: photosAsync.when(
                loading: () => const VLoadingView(),
                error: (e, _) => ErrorView(
                  message: e.toAppError().message,
                  onRetry: () =>
                      ref.invalidate(eventPhotosProvider(widget.eventId)),
                ),
                data: (photos) => photos.isEmpty
                    ? VEmptyView(
                        icon: Icons.photo_library_outlined,
                        title: l10n.photosEmpty,
                        description: l10n.photosEmptyBody,
                        actionLabel: windowOpen ? l10n.photosUpload : null,
                        onAction: windowOpen ? _pickAndUpload : null,
                      )
                    : _PhotoGrid(
                        photos: photos,
                        onLike: _toggleLike,
                        onLongPress: _report,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onLike,
    required this.onLongPress,
  });

  final List<EventPhoto> photos;
  final ValueChanged<String> onLike;
  final ValueChanged<EventPhoto> onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _PhotoTile(
          photo: photo,
          onLike: () => onLike(photo.id),
          onLongPress: () => onLongPress(photo),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.onLike,
    required this.onLongPress,
  });

  final EventPhoto photo;
  final VoidCallback onLike;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final url = photo.signedUrl;
    return GestureDetector(
      key: ValueKey('photo-tile-${photo.id}'),
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null || url.isEmpty)
            ColoredBox(
              color: context.palette.surfaceAlt,
              child: Center(
                child: Icon(
                  Icons.photo_outlined,
                  color: context.palette.mutedForeground,
                  size: 24,
                ),
              ),
            )
          else
            VNetworkImage(imageUrl: url, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: context.palette.background.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: ValueKey('photo-like-${photo.id}'),
                    tooltip: l10n.photosLikeTooltip,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    iconSize: 18,
                    onPressed: onLike,
                    icon: Icon(
                      photo.likedByMe ? Icons.favorite : Icons.favorite_border,
                      // Monochrome: the like accent is white — the filled
                      // heart carries the liked state.
                      color: context.palette.foreground,
                    ),
                  ),
                  Text(
                    l10n.photosLikesCount(photo.likesCount),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: context.palette.foreground),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
