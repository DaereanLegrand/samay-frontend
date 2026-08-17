import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/event_photo.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/photos/providers/photos_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// COLL (phase-08 / R1 events sweep): the event photo-wall — every photo of
/// the event (the [eventPhotosProvider] signed-URL gallery) in a tight grid
/// with the event title overlaid on the wall.
///
/// LUXE v2: photos own the **mint** family — a faint mint wash + the mint
/// display voice in the title overlay; the wall itself stays pure photo.
class EventCollageScreen extends ConsumerWidget {
  const EventCollageScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final photosAsync = ref.watch(eventPhotosProvider(eventId));
    final title = ref.watch(eventDetailProvider(eventId)).valueOrNull?.name;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.collageTitle)),
      body: photosAsync.when(
        loading: () => const VLoadingView(),
        error: (e, _) => ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(eventPhotosProvider(eventId)),
        ),
        data: (photos) => photos.isEmpty
            ? VEmptyView(
                icon: Icons.photo_library_outlined,
                title: l10n.collageEmpty,
                description: l10n.collageEmptyBody,
              )
            : _CollageWall(photos: photos, title: title ?? l10n.collageTitle),
      ),
    );
  }
}

/// The photo-wall: a full-bleed 3-column grid with the event title overlaid
/// as a translucent strip on top of the photos.
class _CollageWall extends StatelessWidget {
  const _CollageWall({required this.photos, required this.title});

  final List<EventPhoto> photos;
  final String title;

  /// The overlay strip's vertical footprint — the grid starts below it so
  /// the top row never hides behind the title.
  static const double _overlayHeight = 128;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GridView.builder(
            padding: const EdgeInsets.only(top: _overlayHeight),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final url = photo.signedUrl;
              return ColoredBox(
                key: ValueKey('photo-tile-${photo.id}'),
                color: AppColors.surfaceAlt,
                child: (url == null || url.isEmpty)
                    ? const Icon(
                        Icons.photo_outlined,
                        color: AppColors.mutedStrong,
                        size: AppIconSizes.lg,
                      )
                    : VNetworkImage(imageUrl: url, fit: BoxFit.cover),
              );
            },
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            color: AppColors.discoBlack.withValues(alpha: 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VDisplayText(
                  text: title,
                  size: 28,
                  gradient: AppGradients.mint,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.collagePhotoCount(photos.length),
                  style: const TextStyle(
                    color: AppColors.mutedStrong,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
