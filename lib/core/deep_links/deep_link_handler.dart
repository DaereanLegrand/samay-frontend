import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Canonical link host for share links.
const String kSamayLinkHost = 'samay.qallariy.lat';

/// The 6-character partida join code alphabet (matches the server RPC).
final RegExp kJoinCodePattern = RegExp(
  r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$',
);

/// Parses a partida link into its join code.
///
/// Accepted shapes:
///   `samay://join/<CODE>`                      in-app / QR
///   `https://samay.qallariy.lat/j/<CODE>`      shared link
///   `<CODE>`                                   bare code (paste / screenshot)
///
/// `http` and every other host are rejected, and no query parameter is ever
/// followed, so there is no open redirect. Returns null for any non-match.
String? parseJoinCodeLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final bare = trimmed.toUpperCase();
  if (kJoinCodePattern.hasMatch(bare)) return bare;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
  final segments = List<String>.of(uri.pathSegments)
    ..removeWhere((s) => s.isEmpty);

  if (uri.scheme == 'samay') {
    if (uri.host.toLowerCase() != 'join' || segments.length != 1) return null;
    final code = segments.first.toUpperCase();
    return kJoinCodePattern.hasMatch(code) ? code : null;
  }

  if (uri.scheme != 'https' || uri.host.toLowerCase() != kSamayLinkHost) {
    return null;
  }
  if (segments.length != 2 || segments[0] != 'j') return null;
  final code = segments[1].toUpperCase();
  return kJoinCodePattern.hasMatch(code) ? code : null;
}

/// Raw deep-link stream (String URIs) feeding [DeepLinkListener].
final deepLinkStreamProvider = Provider<Stream<String>?>((ref) => null);

/// Routes an incoming link to the ONE deep link this build supports: joining a
/// multi-device partida by its 6-character code.
///
/// Chat/event/profile invite links belonged to removed features, so a link in
/// any other shape is ignored (never navigates, never crashes).
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key});

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _resubscribe(ref.read(deepLinkStreamProvider));
  }

  void _resubscribe(Stream<String>? stream) {
    final previous = _subscription;
    _subscription = stream?.listen(_handle);
    if (previous != null) unawaited(previous.cancel());
  }

  Future<void> _handle(String raw) async {
    final code = parseJoinCodeLink(raw);
    if (code == null) return;

    final router = ref.read(routerProvider);
    final messaging = ScaffoldMessenger.maybeOf(
      router.routerDelegate.navigatorKey.currentContext ?? context,
    );

    // A link must never join on its own: the player lands on the lobby only
    // after the server accepts the code, which is the explicit action.
    final auth = ref.read(authStateProvider).valueOrNull;
    if (auth == null || !auth.authenticated) {
      router.go(RoutePaths.onboarding);
      return;
    }

    final invalidCode = AppLocalizations.of(context).minigamesErrorInvalidCode;
    final invalidInvite = AppLocalizations.of(context).routerInvalidInvite;
    try {
      final sessionId = await ref.read(minigameServiceProvider).joinByCode(code);
      router.go(RoutePaths.minigameSession(sessionId));
    } catch (e, st) {
      AppLogger.instance.error('join-by-link failed: $e', '$st');
      final message = e is MinigameSessionRejectedException
          ? invalidCode
          : invalidInvite;
      messaging?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
