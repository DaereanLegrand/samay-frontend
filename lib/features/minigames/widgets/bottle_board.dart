import 'dart:math';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// One seat on the bottle board — the minimal shape the board paints.
///
/// Deliberately NOT the server `MinigameParticipant`: the same board is used by
/// the multi-device bottle (server seats) and by the single-device one (local
/// seats), so it must not know about sessions.
@immutable
class BottleBoardPlayer {
  const BottleBoardPlayer({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isMe = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isMe;
}

/// The bottle table seen at an angle.
///
/// The pizza is drawn as an ELLIPSE (the circle foreshortened by cos(tilt))
/// sitting on a solid rim, so the board reads as a real table instead of a flat
/// wheel. Seats are dealt onto equal slices, so wherever the bottle stops it
/// always stops inside exactly one player's slice. Only the board is tilted —
/// names and avatars stay upright so they remain readable.
///
/// Pure widget: the caller owns the angle (free spin + deceleration), so the
/// server game and the pass-the-phone game animate identically.
class BottleBoard extends StatelessWidget {
  const BottleBoard({
    super.key,
    required this.seated,
    required this.angle,
    this.selectedId,
  });

  final List<BottleBoardPlayer> seated;

  /// Bottle rotation in radians (0 = pointing at slice 0, which starts at 12
  /// o'clock).
  final double angle;

  /// The winning seat, when the result may already be shown.
  final String? selectedId;

  /// How far the table is tilted away from the viewer. Enough to read as
  /// perspective, shallow enough that the slices near the horizon do not
  /// collapse into slivers.
  static const double kTilt = 0.62;

  /// Vertical foreshortening of the board.
  static double get squash => cos(kTilt);

  /// Slice palette — the app's pastel set, cycled so neighbours differ.
  static const List<Color> slice = [
    AppColors.pastelRose,
    AppColors.pastelViolet,
    AppColors.pastelCyan,
    AppColors.pastelGold,
    AppColors.pastelMint,
    AppColors.pastelPeach,
  ];

  @override
  Widget build(BuildContext context) {
    final n = seated.length;
    if (n == 0) return const SizedBox.shrink();
    final step = 2 * pi / n;
    final selectedIndex = selectedId == null
        ? -1
        : seated.indexWhere((p) => p.id == selectedId);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The board leaves a margin, and the seats sit well inside the rim:
        // a name tag is wider than the avatar it labels, so seating players
        // ON the edge either pushed the 3- and 9-o'clock names off the screen
        // or forced them to ellipsize. Pulling the ring in buys the tag its
        // full width while the table still fills the view.
        final radius =
            min(constraints.maxWidth, constraints.maxHeight / squash) / 2 * 0.88;
        final avatarRadius = radius * 0.62;
        return Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(radius * 2, radius * 2 * squash + BottlePizzaPainter.kRim),
              painter: BottlePizzaPainter(
                count: n,
                colors: slice,
                selectedIndex: selectedIndex,
                squash: squash,
              ),
            ),
            // One avatar per slice, seated on the ellipse at the slice's
            // middle. Kept upright on purpose: tilted text is unreadable.
            for (var i = 0; i < n; i++)
              Transform.translate(
                offset: Offset(
                  cos(i * step + step / 2 - pi / 2) * avatarRadius,
                  sin(i * step + step / 2 - pi / 2) * avatarRadius * squash,
                ),
                child: BottleSeat(
                  player: seated[i],
                  isWinner: i == selectedIndex,
                  maxLabelWidth: radius * 0.80,
                ),
              ),
            // The bottle lying on the table: squashed with the board, then
            // rotated to the current angle.
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..scaleByDouble(1.0, squash, 1.0, 1.0),
              child: Transform.rotate(
                angle: angle,
                child: CustomPaint(
                  size: Size(radius * 0.32, radius * 0.98),
                  painter: BottleBottlePainter(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One player seated on their slice: avatar ring, name tag.
class BottleSeat extends StatelessWidget {
  const BottleSeat({
    super.key,
    required this.player,
    required this.isWinner,
    required this.maxLabelWidth,
  });

  final BottleBoardPlayer player;
  final bool isWinner;

  /// Cap for the name tag, so a long username stays on the board instead of
  /// running off the table (and, near the edges, off the screen).
  final double maxLabelWidth;

  @override
  Widget build(BuildContext context) {
    final initials = player.name.isEmpty ? '?' : player.name[0];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.palette.background,
            border: Border.all(
              color: isWinner
                  ? context.palette.foreground
                  : player.isMe
                  ? context.palette.foreground.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: isWinner ? 3 : 2,
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: context.palette.foreground.withValues(alpha: 0.5),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: _SeatAvatar(
            size: isWinner ? 50 : 42,
            initials: initials,
            imageUrl: player.avatarUrl,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          constraints: BoxConstraints(maxWidth: maxLabelWidth),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: context.palette.background.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isWinner
                  ? context.palette.foreground
                  : context.palette.mutedForeground,
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular avatar: the remote photo when there is one, initials otherwise.
///
/// Kept local (instead of [ProfileAvatar]) so the board renders instantly for
/// the pass-the-phone seats, which never carry a photo.
class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({
    required this.size,
    required this.initials,
    required this.imageUrl,
  });

  final double size;
  final String initials;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? ColoredBox(
                color: context.palette.surfaceAlt,
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                      color: context.palette.foreground,
                    ),
                  ),
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: context.palette.surfaceAlt,
                  child: Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontSize: size * 0.36,
                        fontWeight: FontWeight.w700,
                        color: context.palette.foreground,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The table surface: slices, dimmed non-winners, dividers, rim light.
class BottlePizzaPainter extends CustomPainter {
  BottlePizzaPainter({
    required this.count,
    required this.colors,
    required this.selectedIndex,
    required this.squash,
  });

  final int count;
  final List<Color> colors;
  final int selectedIndex;
  final double squash;

  /// Thickness of the table edge, in pixels.
  static const double kRim = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final centre = Offset(radius, (size.height - kRim) / 2);
    final board = Rect.fromCenter(
      center: centre,
      width: radius * 2,
      height: radius * 2 * squash,
    );
    final step = 2 * pi / count;

    // 1. The edge: the same ellipse pushed down in darker tones, so the board
    //    has a visible thickness instead of floating flat.
    canvas.drawOval(
      board.shift(const Offset(0, kRim)),
      Paint()..color = const Color(0xFF15131C),
    );
    canvas.drawOval(
      board.shift(const Offset(0, kRim * 0.5)),
      Paint()..color = const Color(0xFF241F30),
    );

    // 2. The slices.
    for (var i = 0; i < count; i++) {
      // Canvas angles start at 3 o'clock; the game's 0 is 12 o'clock.
      final start = i * step - pi / 2;
      final isWinner = i == selectedIndex;
      final base = colors[i % colors.length];
      if (isWinner) {
        // A soft bloom under the winning slice so the reveal reads from
        // across a table.
        canvas.drawArc(
          board,
          start,
          step,
          true,
          Paint()
            ..color = base.withValues(alpha: 0.40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
        );
      }
      canvas.drawArc(
        board,
        start,
        step,
        true,
        Paint()
          ..style = PaintingStyle.fill
          ..color = isWinner
              ? base.withValues(alpha: 0.92)
              : base.withValues(alpha: 0.20),
      );
    }

    // 3. Slice dividers.
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.discoBlack.withValues(alpha: 0.55);
    for (var i = 0; i < count; i++) {
      final a = i * step - pi / 2;
      canvas.drawLine(
        centre,
        centre + Offset(cos(a) * radius, sin(a) * radius * squash),
        divider,
      );
    }

    // 4. Rim light around the board.
    canvas.drawOval(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.white.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(BottlePizzaPainter old) =>
      old.count != count ||
      old.selectedIndex != selectedIndex ||
      old.squash != squash;
}

/// A bottle silhouette pointing up, shaded so it reads as a solid object
/// resting on the table rather than a flat cut-out. The cap end is the pointer
/// the sector maths uses.
class BottleBottlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Contact shadow: the bottle sits ON the board.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.02, h * 0.34, w * 1.06, h * 0.68),
      Paint()
        ..color = AppColors.discoBlack.withValues(alpha: 0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Glass: a left-to-right gradient gives the cylinder its roundness.
    final glass = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0xFFB3BAC2),
          Color(0xFFFFFFFF),
          Color(0xFFF2F4F6),
          Color(0xFF9AA3AC),
        ],
        stops: [0.0, 0.30, 0.58, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final body = Path()
      ..moveTo(w * 0.16, h * 0.46)
      ..quadraticBezierTo(w * 0.16, h * 0.99, w * 0.50, h * 0.99)
      ..quadraticBezierTo(w * 0.84, h * 0.99, w * 0.84, h * 0.46)
      // Shoulders taper into the neck.
      ..quadraticBezierTo(w * 0.81, h * 0.25, w * 0.63, h * 0.19)
      ..lineTo(w * 0.37, h * 0.19)
      ..quadraticBezierTo(w * 0.19, h * 0.25, w * 0.16, h * 0.46)
      ..close();
    canvas.drawPath(body, glass);

    // Neck + cap.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.38, h * 0.08, w * 0.24, h * 0.14),
        Radius.circular(w * 0.06),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.32, 0, w * 0.36, h * 0.10),
        Radius.circular(w * 0.09),
      ),
      Paint()..color = AppColors.discoSilver,
    );

    // Specular highlight down the left side.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.25, h * 0.32, w * 0.07, h * 0.54),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.80),
    );

    // Label band.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.64, w * 0.68, h * 0.17),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xFF6B6776),
    );
  }

  @override
  bool shouldRepaint(BottleBottlePainter old) => false;
}
