import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Samay deep-link handling (EINV — `samay://event/{invite_token}`, MVP §6.3).
///
/// Two-layer parsing:
/// * [parseDeepLink] is the **scheme gate** — "does the app own this link?"
///   (`samay://` any shape, plus the https universal-link fallback restricted
///   to event-shaped paths). Future link types (profiles, groups…) extend
///   here without touching [handleDeepLink].
/// * [extractEventToken] is the **event-shape gate** — "is this an event
///   invite link?" (`event/<token>` path), returning the token or null.
///
/// [handleDeepLink] composes both, resolves the token to an event id through
/// an injectable callback, and navigates with `router.go` to
/// `RoutePaths.eventDetail(eventId)` — the single `/event/:eventId` route
/// then renders the detail. On failure a snackbar is shown through the
/// router's navigator context (localized via [AppLocalizations], falling back
/// to [failureMessage] when provided — injectable for tests).
final class DeepLinkHandler {
  const DeepLinkHandler();

  /// Returns the parsed URI when [raw] is a Samay deep link (scheme gate);
  /// null for everything else.
  Uri? parseDeepLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.isEmpty) return null;
    if (uri.scheme == 'samay') return uri;
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return extractEventToken(uri) == null ? null : uri;
    }
    return null;
  }

  /// Extracts the invite token from an event deep link; null for any other
  /// shape. Trailing slashes are tolerated (common when links are copied).
  String? extractEventToken(Uri uri) {
    final segments = List<String>.of(uri.pathSegments);
    while (segments.isNotEmpty && segments.last.isEmpty) {
      segments.removeLast();
    }
    if (uri.scheme == 'samay') {
      if (uri.host != 'event' || segments.length != 1) return null;
      return segments.single.isEmpty ? null : segments.single;
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      if (segments.length != 2 || segments[0] != 'event') return null;
      return segments[1].isEmpty ? null : segments[1];
    }
    return null;
  }

  /// Handles [raw]: parses it, resolves the invite token via
  /// [resolveEventId], and navigates to the event detail route. Returns true
  /// when navigation happened. Unknown tokens, non-Samay links, and resolver
  /// failures return false (with a snackbar for the failure cases, using
  /// [failureMessage] when provided, else the localized invalid-invite copy).
  Future<bool> handleDeepLink(
    String raw, {
    required GoRouter router,
    required Future<String?> Function(String token) resolveEventId,
    String? failureMessage,
  }) async {
    final uri = parseDeepLink(raw);
    final token = uri == null ? null : extractEventToken(uri);
    if (token == null) return false;

    String? eventId;
    try {
      eventId = await resolveEventId(token);
    } catch (e, st) {
      // The failure is surfaced to the user below; it is also logged so the
      // token-resolution error is never silent.
      AppLogger.instance.error('invite token resolution failed: $e', '$st');
      eventId = null;
    }
    if (eventId == null) {
      _showFailure(router, failureMessage);
      return false;
    }

    router.go(RoutePaths.eventDetail(eventId));
    return true;
  }

  void _showFailure(GoRouter router, String? failureMessage) {
    // go_router 14.x keeps the root navigator key on the delegate (the
    // `navigatorKey` constructor param is not exposed as a router getter).
    // The navigator context can be absent (cold start, mocked routers in
    // tests) — the failure is still reported through handleDeepLink's return
    // value, so the snackbar degrades gracefully.
    try {
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context == null) return;
      final message = failureMessage ??
          AppLocalizations.of(context).routerInvalidInvite;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      // No usable navigator context — nothing to attach the snackbar to.
    }
  }
}

/// Raw deep-link stream (String URIs) feeding [DeepLinkListener].
///
/// **Null until the app_links wiring lands** — `main.dart` overrides this
/// provider with `AppLinks().uriLinkStream` (the package resolves transitively
/// via supabase_flutter and is a registered native
/// plugin on every platform). A controlled
/// [StreamController] can override it. The seam keeps the handler and listener
/// platform-free; `app_links` is only imported by `main.dart`.
final deepLinkStreamProvider = Provider<Stream<String>?>((ref) => null);

/// App-root subscription widget: forwards every raw link from
/// [deepLinkStreamProvider] to [DeepLinkHandler]. Inert — a zero-size
/// [SizedBox.shrink] — when the provider is null.
///
/// Mounted inside `SamayApp`'s `MaterialApp.router` `builder:` (below
/// `Localizations`, so the localized failure snackbar resolves) — see
/// `lib/app.dart`.
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
    final router = ref.read(routerProvider);
    final service = ref.read(eventServiceProvider);
    await const DeepLinkHandler().handleDeepLink(
      raw,
      router: router,
      failureMessage: AppLocalizations.of(context).routerInvalidInvite,
      resolveEventId: (token) async =>
          (await service.getEventByInviteToken(token))?.id,
    );
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
