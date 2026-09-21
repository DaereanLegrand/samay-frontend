import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forge2d/forge2d.dart' as f2d;
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';

/// The match card's participant bubbles as a tiny Box2D (forge2d) world:
/// circular bodies that collide and pile against the card's right wall under a
/// rightward base gravity. Feed scrolling kicks the bodies so the pile surges
/// and settles as the timeline moves. There is deliberately NO direct bubble
/// drag and NO accelerometer coupling (2026-09-20 directives).
///
/// The world is built once per card layout, steps on a [Ticker], and stops the
/// ticker once every body has fallen asleep (Box2D sleeping) so an idle card
/// costs nothing. On first appearance each bubble pops in with a ~100 ms
/// stagger plus a small random offset. Under OS reduced motion the whole
/// simulation is skipped in favour of a deterministic static scatter.
class AvatarPhysicsCluster extends ConsumerStatefulWidget {
  const AvatarPhysicsCluster({
    super.key,
    required this.participants,
    this.height = 128,
  });

  final List<MinigameParticipant> participants;

  /// Height of the simulation box in logical px. The host passes the card's
  /// content height so the bubbles fill the whole card (2026-09-20 directive).
  final double height;

  @override
  ConsumerState<AvatarPhysicsCluster> createState() =>
      _AvatarPhysicsClusterState();
}

class _AvatarPhysicsClusterState extends ConsumerState<AvatarPhysicsCluster>
    with SingleTickerProviderStateMixin {
  /// Bubble diameters in logical px. Kept close together (2026-09-20: the
  /// random size spread was deliberately reduced).
  static const double _minDiameter = 44;
  static const double _maxDiameter = 52;

  /// Box2D swims in meters; 100 px = 1 m keeps circles in the 0.2–0.3 m band
  /// Box2D is tuned for.
  static const double _pixelsPerMeter = 100;

  /// At most this many avatars become bodies; the rest collapse to `+N`.
  static const int _maxShown = 6;

  /// Rightward base gravity (m/s²) — the bubbles pile on the right wall.
  static const double _baseGravityX = 7.0;

  /// Scroll-delta → velocity kick scale. The raw delta is in px; the clamp
  /// keeps a fast fling from launching bodies through the walls.
  static const double _scrollKick = 14.0;

  /// Pop-in: each bubble scales up over this long, starting [_popStagger] apart
  /// (± a random offset) so the cluster appears one bubble at a time.
  static const double _popDuration = 0.26;
  static const double _popStagger = 0.1;
  static const double _popJitter = 0.04;

  f2d.World? _world;
  final List<_Bubble> _bubbles = [];
  double _boxWidthPx = 0;

  /// Seconds since the world was built — drives the staggered pop-in.
  double _age = 0;
  double _popTotal = 0;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _accumulator = 0;

  ScrollPosition? _scroll;
  double _lastPixels = 0;

  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (_reduced) _teardown();
    }
    _bindScroll();
  }

  @override
  void didUpdateWidget(covariant AvatarPhysicsCluster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameParticipants(oldWidget.participants, widget.participants)) {
      _teardown();
    }
  }

  @override
  void dispose() {
    _teardown();
    _scroll?.removeListener(_onScroll);
    _scroll = null;
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) {
      return _StaticScatter(
        participants: widget.participants,
        maxShown: _maxShown,
        minDiameter: _minDiameter,
        maxDiameter: _maxDiameter,
        height: widget.height,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (!width.isFinite || width <= 0) {
          return SizedBox(height: widget.height);
        }
        if (_world == null || (width - _boxWidthPx).abs() > 0.5) {
          _buildWorld(width);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _attach();
            setState(() {});
          });
        }
        return SizedBox(
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [for (final bubble in _bubbles) _positioned(bubble)],
          ),
        );
      },
    );
  }

  Widget _positioned(_Bubble bubble) {
    final size = bubble.radius * 2 * _pixelsPerMeter;
    final center = bubble.body.position;
    // Staggered pop-in: 0 before this bubble's delay, then an ease-out-back
    // scale overshoot to full size.
    final t = ((_age - bubble.popStart) / _popDuration).clamp(0.0, 1.0);
    final child = bubble.overflowCount != null
        ? _OverflowBubble(size: size, count: bubble.overflowCount!)
        : _AvatarBubble(
            size: size,
            imageUrl: bubble.avatarUrl,
            initials: bubble.initials,
          );
    return Positioned(
      left: center.x * _pixelsPerMeter - size / 2,
      top: center.y * _pixelsPerMeter - size / 2,
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: Curves.easeOutBack.transform(t),
          child: child,
        ),
      ),
    );
  }

  void _buildWorld(double widthPx) {
    _teardown();
    _age = 0;
    _boxWidthPx = widthPx;
    final width = widthPx / _pixelsPerMeter;
    final height = widget.height / _pixelsPerMeter;
    final world = f2d.World(f2d.Vector2(_baseGravityX, 0));

    final walls = world.createBody(f2d.BodyDef(type: f2d.BodyType.static));
    for (final edge in [
      f2d.EdgeShape()..set(f2d.Vector2(0, 0), f2d.Vector2(width, 0)),
      f2d.EdgeShape()..set(f2d.Vector2(0, height), f2d.Vector2(width, height)),
      f2d.EdgeShape()..set(f2d.Vector2(width, 0), f2d.Vector2(width, height)),
      f2d.EdgeShape()..set(f2d.Vector2(0, 0), f2d.Vector2(0, height)),
    ]) {
      walls.createFixture(f2d.FixtureDef(edge, friction: 0.4, restitution: 0.4));
    }

    final shown = widget.participants.take(_maxShown).toList();
    final overflow = widget.participants.length - shown.length;
    // Unseeded: every card instance gets a fresh random starting scatter
    // (2026-09-20 directive). The world is built once per layout, so the pile
    // does not re-scatter on rebuilds.
    final rng = math.Random();

    void addBubble({
      String? avatarUrl,
      String initials = '',
      int? overflowCount,
      required double diameterPx,
      required double popStart,
    }) {
      final radius = diameterPx / 2 / _pixelsPerMeter;
      final maxX = math.max(radius, width - radius);
      final maxY = math.max(radius, height - radius);
      final body = world.createBody(
        f2d.BodyDef(
          type: f2d.BodyType.dynamic,
          position: f2d.Vector2(
            radius + rng.nextDouble() * (maxX - radius),
            radius + rng.nextDouble() * (maxY - radius),
          ),
          linearDamping: 0.7,
          angularDamping: 1.0,
          fixedRotation: true,
          allowSleep: true,
        ),
      );
      body.createFixture(
        f2d.FixtureDef(
          f2d.CircleShape(radius: radius),
          density: 1,
          friction: 0.35,
          restitution: 0.45,
        ),
      );
      _bubbles.add(
        _Bubble(
          body: body,
          radius: radius,
          avatarUrl: avatarUrl,
          initials: initials,
          overflowCount: overflowCount,
          popStart: popStart,
        ),
      );
    }

    for (var i = 0; i < shown.length; i++) {
      final participant = shown[i];
      addBubble(
        avatarUrl: participant.avatarUrl,
        initials: _initials(participant.username),
        diameterPx: _minDiameter + rng.nextDouble() * (_maxDiameter - _minDiameter),
        popStart: _popDelay(i, rng),
      );
    }
    if (overflow > 0) {
      addBubble(
        overflowCount: overflow,
        diameterPx: _maxDiameter - 6,
        popStart: _popDelay(shown.length, rng),
      );
    }
    _popTotal = _bubbles.isEmpty
        ? 0
        : _bubbles.last.popStart + _popDuration;

    _world = world;
    // Re-anchor the scroll cursor: the previously built world may have been
    // torn down while the feed scrolled on.
    _lastPixels = _scroll?.pixels ?? 0;
  }

  /// Starts the ticker once the world exists. Called post-frame (the world is
  /// built during layout).
  void _attach() {
    if (_reduced || _world == null) return;
    _bindScroll();
    _ensureTicker();
  }

  void _teardown() {
    _stopTicker();
    _bubbles.clear();
    _world = null;
  }

  /// Binds the enclosing feed's scroll position (inherited dependency, so this
  /// re-binds if the cluster is ever reparented into another scrollable).
  void _bindScroll() {
    ScrollPosition? scroll;
    try {
      scroll = Scrollable.maybeOf(context)?.position;
    } catch (_) {
      scroll = null;
    }
    if (identical(scroll, _scroll)) return;
    _scroll?.removeListener(_onScroll);
    _scroll = scroll;
    _scroll?.addListener(_onScroll);
    _lastPixels = scroll?.pixels ?? 0;
  }

  /// Every scroll frame, jolt the pile: the faster the feed moves, the bigger
  /// the kick. Damping then brings the bodies back to a right-wall rest, so the
  /// cluster visibly surges while the timeline scrolls.
  void _onScroll() {
    if (_world == null) return;
    final position = _scroll;
    if (position == null) return;
    final pixels = position.pixels;
    final delta = pixels - _lastPixels;
    _lastPixels = pixels;
    if (delta == 0) return;
    final kick = (-delta / _pixelsPerMeter).clamp(-8.0, 8.0) * _scrollKick;
    const maxSpeed = 8.0;
    for (final bubble in _bubbles) {
      final velocity = bubble.body.linearVelocity;
      bubble.body.linearVelocity = f2d.Vector2(
        (velocity.x + kick * 0.5).clamp(-maxSpeed, maxSpeed),
        (velocity.y + kick).clamp(-maxSpeed, maxSpeed),
      );
    }
    _ensureTicker();
  }

  void _ensureTicker() {
    if (_reduced || _world == null) return;
    _ticker ??= createTicker(_onTick);
    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _accumulator = 0;
      _ticker!.start();
    }
  }

  void _stopTicker() {
    if (_ticker?.isActive ?? false) _ticker!.stop();
  }

  void _onTick(Duration elapsed) {
    final world = _world;
    if (world == null) return;
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == Duration.zero) return;
    var dt = (elapsed - previous).inMicroseconds / 1e6;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    _age += dt;
    _accumulator = (_accumulator + dt).clamp(0.0, 0.1);
    const step = 1 / 60;
    var steps = 0;
    while (_accumulator >= step && steps < 4) {
      world.stepDt(step);
      _accumulator -= step;
      steps++;
    }
    if (!mounted) return;
    setState(() {});
    final popped = _age >= _popTotal;
    if (popped && _bubbles.every((bubble) => !bubble.body.isAwake)) {
      _stopTicker();
    }
  }

  /// Pop-in start for bubble [index]: a fixed stagger plus a small random
  /// offset, never negative.
  static double _popDelay(int index, math.Random rng) {
    final jitter = (rng.nextDouble() * 2 - 1) * _popJitter;
    return math.max(0, index * _popStagger + jitter);
  }

  static bool _sameParticipants(
    List<MinigameParticipant> a,
    List<MinigameParticipant> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

/// One simulated avatar (or the `+N` overflow) in the world.
class _Bubble {
  const _Bubble({
    required this.body,
    required this.radius,
    required this.popStart,
    this.avatarUrl,
    this.initials = '',
    this.overflowCount,
  });

  final f2d.Body body;

  /// Radius in meters.
  final double radius;

  /// Seconds after the world is built before this bubble pops in.
  final double popStart;

  final String? avatarUrl;
  final String initials;
  final int? overflowCount;
}

/// Static, deterministic scatter used under OS reduced motion (no simulation).
///
/// Same sizes/overlap/scatter as the physics pile's starting positions, but
/// laid out once with no ticker and no sensor/scroll subscriptions.
class _StaticScatter extends StatelessWidget {
  const _StaticScatter({
    required this.participants,
    required this.maxShown,
    required this.minDiameter,
    required this.maxDiameter,
    required this.height,
  });

  final List<MinigameParticipant> participants;
  final int maxShown;
  final double minDiameter;
  final double maxDiameter;
  final double height;

  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return SizedBox(height: height);

    final shown = participants.take(maxShown).toList();
    final overflow = participants.length - shown.length;

    final sizes = <double>[];
    final tops = <double>[];
    for (final participant in shown) {
      final seed = _seed(participant.id);
      final size =
          minDiameter + (seed % ((maxDiameter - minDiameter).toInt() + 1));
      sizes.add(size);
      final travel = height - size;
      tops.add(travel <= 0 ? 0 : ((seed >> 8) % (travel.toInt() + 1)).toDouble());
    }
    if (overflow > 0) {
      const size = 50.0;
      sizes.add(size);
      tops.add((height - size) / 2);
    }

    final lefts = <double>[];
    var x = 0.0;
    for (final size in sizes) {
      lefts.add(x);
      x += size - _overlap;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: lefts.last + sizes.last,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: lefts[i],
                top: tops[i],
                child: _AvatarBubble(
                  size: sizes[i],
                  imageUrl: shown[i].avatarUrl,
                  initials: _initials(shown[i].username),
                ),
              ),
            if (overflow > 0)
              Positioned(
                left: lefts[shown.length],
                top: tops[shown.length],
                child: _OverflowBubble(
                  size: sizes[shown.length],
                  count: overflow,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping avatar bubbles used by the reduced-motion fallback.
class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.size,
    required this.imageUrl,
    required this.initials,
  });

  final double size;
  final String? imageUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    // A black ring separates overlapping bubbles (Apple Watch treatment).
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.discoBlack,
      ),
      padding: const EdgeInsets.all(2),
      child: ProfileAvatar(
        size: size - 4,
        imageUrl: imageUrl,
        initials: initials,
      ),
    );
  }
}

class _OverflowBubble extends StatelessWidget {
  const _OverflowBubble({required this.size, required this.count});

  final double size;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceAlt,
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          color: AppColors.white,
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
