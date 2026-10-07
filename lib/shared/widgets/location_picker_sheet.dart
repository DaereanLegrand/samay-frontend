import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/services/location_service.dart';
import 'package:samay/core/services/qallariy_tiles.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/services/maps_link_service.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

/// Default map center (Arequipa) and zoom when no initial point is supplied.
const double kDefaultLocationLat = -16.3988;
const double kDefaultLocationLng = -71.5369;
const double kDefaultLocationZoom = 15;

/// Opens the location picker and returns the chosen point, or null when the
/// sheet is dismissed without a selection.
Future<LatLng?> showLocationPicker(
  BuildContext context, {
  LatLng? initial,
}) {
  return showModalBottomSheet<LatLng>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LocationPickerSheet(initial: initial),
  );
}

enum _PickerMode { link, coords, map }

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key, this.initial});

  final LatLng? initial;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _mapController = MapController();
  final _inputController = TextEditingController();
  final _maps = MapsLinkService();
  final _location = const LocationService();

  _PickerMode _mode = _PickerMode.map;
  LatLng? _resolved;
  String? _error;
  bool _busy = false;
  bool _locating = false;

  @override
  void dispose() {
    _inputController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final l10n = AppLocalizations.of(context);
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() => _error = l10n.locationPickerPastePrompt);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _maps.resolve(input);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resolved = result;
      _error = result == null ? l10n.locationPickerResolveFailed : null;
    });
  }

  Future<void> _useMyLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _locating = true);
    try {
      final point = await _location.current();
      if (!mounted) return;
      if (point == null) {
        setState(() => _error = l10n.locationPickerDenied);
        return;
      }
      final target = LatLng(point.latitude, point.longitude);
      _mapController.move(target, kDefaultLocationZoom);
      setState(() {
        _resolved = target;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.locationPickerUnavailable);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirmMapCenter() {
    Navigator.of(context).pop(_mapController.camera.center);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.mutedStrong.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.locationPickerTitle,
                          style: AppTypography.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.mutedStrong),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      VChip(
                        label: l10n.locationPickerMapTab,
                        selected: _mode == _PickerMode.map,
                        onSelected: () =>
                            setState(() => _mode = _PickerMode.map),
                      ),
                      VChip(
                        label: l10n.locationPickerLinkTab,
                        selected: _mode == _PickerMode.link,
                        onSelected: () =>
                            setState(() => _mode = _PickerMode.link),
                      ),
                      VChip(
                        label: l10n.locationPickerCoordsTab,
                        selected: _mode == _PickerMode.coords,
                        onSelected: () =>
                            setState(() => _mode = _PickerMode.coords),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_mode == _PickerMode.map)
                    _mapSection(l10n)
                  else
                    _textSection(l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textSection(AppLocalizations l10n) {
    final isLink = _mode == _PickerMode.link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isLink ? l10n.locationPickerLinkHint : l10n.locationPickerCoordsHint,
          style: AppTypography.bodySmall.copyWith(color: AppColors.mutedStrong),
        ),
        const SizedBox(height: AppSpacing.sm),
        VInput(
          label: isLink
              ? l10n.locationPickerLinkHint
              : l10n.locationPickerCoordsHint,
          controller: _inputController,
          keyboardType: isLink ? TextInputType.url : TextInputType.text,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
        if (_resolved != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.locationPickerCoordinates(_fmt(_resolved!)),
            style: AppTypography.bodySmall.copyWith(color: AppColors.success),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: VButton.outlined(
                label: l10n.locationPickerResolve,
                onPressed: _busy ? null : _resolve,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: VButton.emphasized(
                label: l10n.locationPickerUse,
                onPressed: _resolved == null
                    ? null
                    : () => Navigator.pop(context, _resolved),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mapSection(AppLocalizations l10n) {
    final tileProvider = qallariyTileProvider();
    final center = widget.initial ??
        const LatLng(kDefaultLocationLat, kDefaultLocationLng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: AppTypography.bodySmall.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: SizedBox(
            height: 320,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: kDefaultLocationZoom,
                    maxZoom: 19,
                  ),
                  children: [
                    VectorTileLayer(
                      tileProviders: TileProviders({'protomaps': tileProvider}),
                      theme: ProtomapsThemes.darkV4(),
                      maximumZoom: 19,
                    ),
                  ],
                ),
                const IgnorePointer(child: Center(child: _Crosshair())),
                Positioned(
                  left: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: FloatingActionButton.small(
                    heroTag: 'location_picker_my_location',
                    backgroundColor: AppColors.surfaceAlt,
                    foregroundColor: AppColors.white,
                    onPressed: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        VButton.emphasized(
          label: l10n.locationPickerUseThisLocation,
          onPressed: _confirmMapCenter,
        ),
      ],
    );
  }

  String _fmt(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
}

/// The map-center aim point. White ring + cross for contrast on both themes.
class _Crosshair extends StatelessWidget {
  const _Crosshair();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 1.5),
              color: AppColors.white.withValues(alpha: 0.08),
            ),
          ),
          Container(width: 2, height: 16, color: AppColors.white),
          Container(width: 16, height: 2, color: AppColors.white),
        ],
      ),
    );
  }
}
