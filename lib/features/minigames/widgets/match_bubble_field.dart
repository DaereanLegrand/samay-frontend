import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:samay/core/config/env_config.dart';
import 'package:samay/features/minigames/logic/match_preview.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Bubbles whose avatar image has genuinely resolved (or which carry no photo).
///
/// Module-level ON PURPOSE: the deck recycles each slot's widget as it scrolls,
/// so a bubble that has already appeared must not re-run its reveal, and a
/// mega's completion must stay stable. This records real loads only — no
/// timers, no fallbacks.
final Set<String> _resolvedBubbles = <String>{};

/// The Games-tab card's match bubbles: one **mega bubble** per recent match,
/// each nesting the small avatar bubbles of that match's players.
///
/// Behaviour (user directives 2026-09-22):
///
/// - A mega bubble is **sized to its inner bubbles**: the avatars are packed
///   into a tight cluster first, then the mega circle is drawn around the
///   result (+ padding).
/// - An avatar bubble renders **only once its image has resolved** — never a
///   placeholder — and pops in one by one. Resolution is recorded in
///   [_resolvedBubbles], so scrolling can never make a bubble disappear and
///   reappear.
/// - A mega **ring is drawn only once all of its avatars have resolved**
///   (read from [_resolvedBubbles], so it cannot get stuck).
/// - Inner avatars have a **minimum size floor** so none read as specks.
///
/// Mega placement stays deterministic and collision-free: circles avoid each
/// other, the centred play button and the top/bottom band zones; newest
/// matches are tried first and only the ones that fit are drawn (cap 5).
class MatchBubbleField extends StatefulWidget {
  const MatchBubbleField({
    super.key,
    required this.matches,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  /// Newest-first recent matches of the card's game.
  final List<MatchPreview> matches;

  /// Reserved top strip (the name band) the bubbles must not enter.
  final double topInset;

  /// Reserved bottom strip (the name band) the bubbles must not enter.
  final double bottomInset;

  @override
  State<MatchBubbleField> createState() => _MatchBubbleFieldState();
}

class _MatchBubbleFieldState extends State<MatchBubbleField> {
  /// Cap on drawn mega bubbles — the most that read cleanly on a card.
  static const int _maxMegaBubbles = 5;

  /// Avatar bubbles nested per mega before the `+N` overflow.
  static const int _maxPlayersPerMega = 6;

  /// Clearance kept between circles.
  static const double _gap = 4;

  String? _signature;
  Size? _size;
  _BubbleLayout? _layout;

  /// A bubble's image resolved — re-evaluate mega completion.
  void _onBubbleResolved() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
        );
        final signature = _signatureOf(widget.matches, size);
        if (_layout == null || _signature != signature || _size != size) {
          _layout = _pack(widget.matches, size);
          _signature = signature;
          _size = size;
        }
        final layout = _layout!;
        return Stack(
          clipBehavior: Clip.none,
          children: [for (final mega in layout.megas) _megaWidget(mega)],
        );
      },
    );
  }

  Widget _megaWidget(_Mega mega) {
    final complete = mega.pendingKeys.every(_resolvedBubbles.contains);
    final size = mega.radius * 2;
    return Positioned(
      key: ValueKey('mega:${mega.sessionId}'),
      left: mega.center.dx - mega.radius,
      top: mega.center.dy - mega.radius,
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The ring/fill appears only once every avatar in this match has
          // resolved.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: complete ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.palette.background.withValues(alpha: 0.65),
                  border: Border.all(color: context.palette.mutedForeground),
                ),
              ),
            ),
          ),
          for (final inner in mega.inners) _innerWidget(inner),
        ],
      ),
    );
  }

  Widget _innerWidget(_Inner inner) {
    final size = inner.radius * 2;
    final player = inner.player;
    // Keys live on the Stack's direct children (the Positioned wrappers) so an
    // inner keeps its element — and its resolved state — across repacks.
    final Widget child = player == null
        ? _OverflowBubble(
            key: ValueKey('overflow:${inner.sessionId}'),
            size: size,
            count: inner.overflowCount ?? 0,
          )
        : _AvatarBubble(
            key: ValueKey('avatar:${inner.key}'),
            bubbleKey: inner.key!,
            player: player,
            size: size,
            delay: inner.delay,
            onResolved: _onBubbleResolved,
          );
    return Positioned(
      key: ValueKey('inner:${inner.sessionId}:${inner.key ?? 'overflow'}'),
      left: inner.center.dx - inner.radius,
      top: inner.center.dy - inner.radius,
      width: size,
      height: size,
      child: child,
    );
  }

  /// Deterministic placement of the mega bubbles (sized to their contents).
  _BubbleLayout _pack(List<MatchPreview> matches, Size size) {
    if (matches.isEmpty || size.width <= 0 || size.height <= 0) {
      return const _BubbleLayout([]);
    }

    final ordered = [...matches]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final rng = math.Random(_seed(ordered.map((m) => m.sessionId).join('|')));

    final playCenter = Offset(size.width / 2, size.height / 2);
    final playRadius = size.width * 0.13;
    final freeLeft = 6.0;
    final freeTop = widget.topInset + _gap;
    final freeRight = size.width - 6.0;
    final freeBottom = size.height - widget.bottomInset - _gap;
    final freeW = freeRight - freeLeft;
    final freeH = freeBottom - freeTop;

    // Size floor: avatars never render as specks.
    final minDia = (size.width * 0.09).clamp(22.0, 30.0);
    final maxDia = (size.width * 0.15).clamp(minDia + 6.0, 44.0);

    // Deterministic candidate centres across the free zone (shuffled so megas
    // spread instead of hugging one edge). Placement scans this list, so the
    // space genuinely fills — random probing left slots empty (only 2 of 5
    // megas ever appeared).
    final step = math.max(14.0, minDia * 0.7);
    final candidates = <Offset>[
      for (var y = freeTop; y <= freeBottom; y += step)
        for (var x = freeLeft; x <= freeRight; x += step) Offset(x, y),
    ]..shuffle(rng);

    final megas = <_Mega>[];
    for (final match in ordered) {
      if (megas.length >= _maxMegaBubbles) break;

      final shown = math.min(match.players.length, _maxPlayersPerMega);
      final overflow = match.totalPlayers - shown;

      final specs = <_InnerSpec>[
        for (var i = 0; i < shown; i++)
          _InnerSpec(
            sessionId: match.sessionId,
            player: match.players[i],
            delay: Duration(milliseconds: 60 * i),
            radius: (minDia + rng.nextDouble() * (maxDia - minDia)) / 2,
          ),
        if (overflow > 0)
          _InnerSpec(
            sessionId: match.sessionId,
            overflowCount: overflow,
            radius: (minDia + maxDia) / 4.8,
          ),
      ];
      if (specs.isEmpty) continue;

      final cluster = _packCluster(specs, rng);
      var megaRadius = cluster.radius;
      megaRadius = math.min(megaRadius, math.min(freeW, freeH) / 2 - 1);
      if (megaRadius <= 0) continue;

      Offset? center;
      for (final candidate in candidates) {
        if (candidate.dx < freeLeft + megaRadius ||
            candidate.dx > freeRight - megaRadius) {
          continue;
        }
        if (candidate.dy < freeTop + megaRadius ||
            candidate.dy > freeBottom - megaRadius) {
          continue;
        }
        if ((candidate - playCenter).distance <=
            playRadius + megaRadius + _gap) {
          continue;
        }
        final clearsMegas = megas.every(
          (m) => (m.center - candidate).distance > m.radius + megaRadius + _gap,
        );
        if (clearsMegas) {
          center = candidate;
          break;
        }
      }
      if (center == null) continue;
      megas.add(
        _Mega(
          sessionId: match.sessionId,
          center: center,
          radius: megaRadius,
          inners: cluster.inners,
          pendingKeys: [
            for (final s in specs)
              if (s.player != null) '${match.sessionId}:${s.player!.id}',
          ],
        ),
      );
    }
    return _BubbleLayout(megas);
  }

  /// Packs [specs] into a tight cluster (local space, origin at 0) and returns
  /// the inners re-centred inside a circle of the cluster's own radius.
  _Cluster _packCluster(List<_InnerSpec> specs, math.Random rng) {
    // Largest first → compact packing.
    final ordered = [...specs]..sort((a, b) => b.radius.compareTo(a.radius));

    final placed = <_Placed>[];
    for (final spec in ordered) {
      final r = spec.radius;
      Offset? best;
      outer:
      for (var ring = 0.0; ring <= r * 40; ring += 1.5) {
        const steps = 24;
        for (var i = 0; i < steps; i++) {
          final angle = i / steps * math.pi * 2;
          final candidate = Offset(
            math.cos(angle) * ring,
            math.sin(angle) * ring,
          );
          final clear = placed.every(
            (p) => (p.center - candidate).distance >= p.radius + r + _gap,
          );
          if (clear) {
            best = candidate;
            break outer;
          }
        }
      }
      best ??= Offset(r + _gap, r + _gap) * placed.length.toDouble();
      placed.add(_Placed(center: best, radius: r, spec: spec));
    }

    // Bounding box → recentre so the mega circle hugs the cluster.
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in placed) {
      minX = math.min(minX, p.center.dx - p.radius);
      minY = math.min(minY, p.center.dy - p.radius);
      maxX = math.max(maxX, p.center.dx + p.radius);
      maxY = math.max(maxY, p.center.dy + p.radius);
    }
    final shift = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    var radius = 0.0;
    final inners = <_Inner>[];
    for (final p in placed) {
      final local = p.center - shift;
      radius = math.max(radius, local.distance + p.radius);
      inners.add(
        _Inner(
          player: p.spec.player,
          overflowCount: p.spec.overflowCount,
          sessionId: p.spec.sessionId,
          key: p.spec.player == null
              ? null
              : '${p.spec.sessionId}:${p.spec.player!.id}',
          delay: p.spec.delay,
          center: local,
          radius: p.radius,
        ),
      );
    }
    radius += math.max(_gap, 7.0); // padding ring
    return _Cluster(
      radius: radius,
      inners: [
        for (final i in inners)
          i.copyWith(center: i.center + Offset(radius, radius)),
      ],
    );
  }

  static String _signatureOf(List<MatchPreview> matches, Size size) {
    final b = StringBuffer('${size.width}x${size.height}');
    for (final m in matches) {
      b
        ..write('|')
        ..write(m.sessionId)
        ..write(':')
        ..write(m.totalPlayers)
        ..write(':')
        ..write(m.players.length);
    }
    return b.toString();
  }
}

/// One avatar bubble that renders only once its image has resolved, then pops
/// in after a small stagger.
///
/// Resolution is written to [_resolvedBubbles] the moment the first frame is
/// available, so a bubble that already appeared renders instantly on any later
/// mount (deck scrolling) and a mega's completion stays stable.
class _AvatarBubble extends StatefulWidget {
  const _AvatarBubble({
    super.key,
    required this.bubbleKey,
    required this.player,
    required this.size,
    required this.delay,
    required this.onResolved,
  });

  final String bubbleKey;
  final MatchPlayer player;
  final double size;
  final Duration delay;
  final VoidCallback onResolved;

  @override
  State<_AvatarBubble> createState() => _AvatarBubbleState();
}

class _AvatarBubbleState extends State<_AvatarBubble> {
  bool _visible = false;
  bool _resolved = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    final hasUrl = (widget.player.avatarUrl ?? '').trim().isNotEmpty;
    // Already-appeared bubbles (or players without a photo) show immediately.
    _visible = !hasUrl || _resolvedBubbles.contains(widget.bubbleKey);
    if (!hasUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  /// Records the real load and schedules the (one-time) staggered pop-in.
  void _resolve() {
    if (_resolved) return;
    _resolved = true;
    final firstTime = _resolvedBubbles.add(widget.bubbleKey);
    if (firstTime) {
      // Never mutate an ancestor during build/layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onResolved();
      });
    }
    if (_visible) return;
    _revealTimer?.cancel();
    _revealTimer = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = (widget.player.avatarUrl ?? '').trim();
    if (url.isEmpty) {
      return _visible ? _face(null) : const SizedBox.shrink();
    }
    final resolved = VNetworkImage.resolveStorageUrl(url);
    return Image(
      image: CachedNetworkImageProvider(
        resolved,
        headers: VNetworkImage.storageHeadersFor(
          resolved,
          EnvConfig.supabaseAnonKeyRaw,
        ),
      ),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final ready = wasSynchronouslyLoaded || frame != null;
        if (ready) _resolve();
        if (!_visible) return const SizedBox.shrink();
        // A cached bubble whose frame has not painted yet shows its initials
        // rather than an empty hole.
        return ready ? _face(child) : _face(null);
      },
      errorBuilder: (context, _, _) {
        if (!_resolved) _resolve();
        return _visible ? _face(null) : const SizedBox.shrink();
      },
    );
  }

  /// The circle: a black ring separating overlapping bubbles, then the photo
  /// (or initials when there is no image).
  Widget _face(Widget? image) {
    final size = widget.size;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.background,
      ),
      padding: const EdgeInsets.all(1),
      child: ClipOval(
        child: SizedBox.expand(
          child:
              image ??
              ColoredBox(
                color: context.palette.surfaceAlt,
                child: Center(
                  child: Text(
                    _initials(widget.player.username),
                    style: TextStyle(
                      fontSize: size * 0.3,
                      color: context.palette.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

/// Pre-placement spec (radius may shrink during packing).
class _InnerSpec {
  _InnerSpec({
    required this.sessionId,
    this.player,
    this.overflowCount,
    this.delay = Duration.zero,
    required this.radius,
  });

  final String sessionId;
  final MatchPlayer? player;
  final int? overflowCount;
  final Duration delay;
  double radius;
}

/// A placed bubble during cluster packing.
class _Placed {
  const _Placed({
    required this.center,
    required this.radius,
    required this.spec,
  });

  final Offset center;
  final double radius;
  final _InnerSpec spec;
}

/// The packed cluster: its bounding-circle radius + the inners in local space.
class _Cluster {
  const _Cluster({required this.radius, required this.inners});

  final double radius;
  final List<_Inner> inners;
}

/// A match's mega bubble: centre, radius, its inner bubbles and the bubble
/// keys that must have resolved before its ring is drawn.
class _Mega {
  const _Mega({
    required this.sessionId,
    required this.center,
    required this.radius,
    required this.inners,
    required this.pendingKeys,
  });

  final String sessionId;
  final Offset center;
  final double radius;
  final List<_Inner> inners;
  final List<String> pendingKeys;
}

/// One bubble nested inside a mega (an avatar, or the `+N` overflow).
class _Inner {
  const _Inner({
    required this.center,
    required this.radius,
    required this.sessionId,
    required this.delay,
    this.player,
    this.overflowCount,
    this.key,
  });

  final Offset center;
  final double radius;
  final String sessionId;
  final Duration delay;
  final MatchPlayer? player;
  final int? overflowCount;
  final String? key;

  _Inner copyWith({Offset? center}) => _Inner(
    center: center ?? this.center,
    radius: radius,
    sessionId: sessionId,
    delay: delay,
    player: player,
    overflowCount: overflowCount,
    key: key,
  );
}

/// The packed result for one box size + match set.
class _BubbleLayout {
  const _BubbleLayout(this.megas);

  final List<_Mega> megas;
}

/// The white `+N` bubble (same treatment as the feed's overflow circle).
class _OverflowBubble extends StatelessWidget {
  const _OverflowBubble({super.key, required this.size, required this.count});

  final double size;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.palette.foreground,
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: context.palette.background,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

int _seed(String id) {
  var hash = 17;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

String _initials(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'[\s_.-]+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0]).join();
  return (letters.isEmpty ? trimmed[0] : letters).toUpperCase();
}
