import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';

/// Paints a minigame screen with its session's GROUP theme, when it has one.
///
/// A minigame session carries an optional `group_id`; a group partida must read
/// as part of the group surface (same derived page/inks as group chat and the
/// member list), while a DIRECT partida stays on the standard black theme.
/// Resolving the group happens here once, so every lobby/play screen only wraps
/// its Scaffold.
class MinigameSessionSurface extends ConsumerWidget {
  const MinigameSessionSurface({
    super.key,
    required this.sessionId,
    required this.child,
  });

  final String sessionId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupId =
        ref.watch(sessionStatusProvider(sessionId)).valueOrNull?['group_id']
            as String?;
    // A session that is still loading, or a direct partida, keeps the standard
    // theme; GroupThemeSurface falls through unchanged.
    return GroupThemeSurface(groupId: groupId, child: child);
  }
}

/// The themed inks a minigame surface paints, resolved from the ambient group
/// scope. Outside a themed surface these are the app's design tokens.
class MinigameInks {
  const MinigameInks._({
    required this.primary,
    required this.muted,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.border,
    required this.themed,
  });

  factory MinigameInks.of(BuildContext context) {
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    return MinigameInks._(
      primary: palette.foreground,
      muted: palette.mutedForeground,
      surface: palette.surface,
      surfaceAlt: palette.surfaceAlt,
      hairline: palette.hairline,
      border: palette.border,
      themed: themed,
    );
  }

  final Color primary;
  final Color muted;
  final Color surface;
  final Color surfaceAlt;
  final Color hairline;
  final Color border;
  final bool themed;
}
