import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_theme_provider.dart';
import 'package:samay/core/theme/app_theme_scope.dart';
import 'package:samay/core/theme/themed_data.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/theme/group_theme_colors.dart';

/// Whether the server's `get_group_theme` is still the untouched default.
///
/// Default = the black page the server hands out until a host picks a colour
/// (`background_color '#000000'`, accent `#FFFFFF`). Picking black explicitly
/// paints the same thing, so this doubles as "the group has no colour of its
/// own" — which is exactly the condition the owner rule cares about.
bool isDefaultGroupTheme(GroupTheme theme) =>
    theme.backgroundColor.toUpperCase() == '#000000';

/// Wraps [child] in a themed Material surface.
///
/// Mounts the [AppThemeScope] AND the re-mapped `ThemeData` above [child].
///
/// **Group ↔ app interaction (owner rule):** a group whose theme is still the
/// server DEFAULT inherits the app-wide theme, so the app reads as one surface
/// everywhere. A group with a real custom theme overrides the app theme inside
/// its own screens.
///
/// When there is nothing to paint (no group, the theme is still loading, a
/// non-member cannot read it, the RPC failed, or the group is default while the
/// app theme is classic) [child] renders unchanged.
class GroupThemeSurface extends ConsumerWidget {
  const GroupThemeSurface({
    super.key,
    this.groupId,
    this.palette,
    this.followAppThemeWhenDefault = true,
    required this.child,
  });

  /// The group whose theme paints [child]; null keeps the ambient theme.
  final String? groupId;

  /// An already-derived palette (e.g. one the caller is previewing).
  final AppPalette? palette;

  /// When the group theme is the server default, fall through to the ambient
  /// app-wide theme instead of painting the standard tokens.
  final bool followAppThemeWhenDefault;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = palette ?? _resolve(context, ref);
    if (resolved == null) return child;
    return AppThemeScope(
      palette: resolved,
      child: Theme(
        data: themedData(Theme.of(context), resolved),
        child: child,
      ),
    );
  }

  AppPalette? _resolve(BuildContext context, WidgetRef ref) {
    final id = groupId;
    if (id == null) return null;
    final theme = ref.watch(groupThemeProvider(id)).valueOrNull;
    // Loading / not a member / error: keep whatever ambient theme is active.
    if (theme == null) return null;
    if (followAppThemeWhenDefault && isDefaultGroupTheme(theme)) {
      final app = ref.watch(appPaletteProvider);
      return app == AppPalette.standard ? null : app;
    }
    return groupThemePaletteOf(theme);
  }
}

/// The palette a group surface should paint, applying the owner rule: a group
/// still on the server default inherits the app-wide theme; a custom group uses
/// its own derived scale.
///
/// Screens that need the palette for their own paints (Scaffold background,
/// banner inks, action rows) call this instead of `groupThemePaletteOf` so they
/// match the [GroupThemeSurface] they mount.
AppPalette groupSurfacePalette(
  GroupTheme theme, {
  required AppPalette appPalette,
}) =>
    isDefaultGroupTheme(theme) ? appPalette : groupThemePaletteOf(theme);
