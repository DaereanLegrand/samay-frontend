import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';

/// Q9 canonical link host. The API host is never used for share links.
const String kSamayLinkHost = 'samay.qallariy.lat';

enum InviteLinkKind { event, group, profile }

/// A parsed bearer link (`/e/`, `/g/`, `/u/`). The token is opaque.
class InviteLink {
  const InviteLink({required this.kind, required this.token});

  final InviteLinkKind kind;
  final String token;

  String get kindSegment => switch (kind) {
    InviteLinkKind.event => 'e',
    InviteLinkKind.group => 'g',
    InviteLinkKind.profile => 'u',
  };
}

/// Samay link handling (Q9).
///
/// Accepted shapes:
///   `https://samay.qallariy.lat/e/<token>`   event invite
///   `https://samay.qallariy.lat/g/<token>`   group invite
///   `https://samay.qallariy.lat/u/<token>`   profile friend link
///   `samay://e|g|u/<token>`                  in-app/dev scheme
///   `samay://event/<token>`                  legacy event scheme
///
/// `http` is rejected, as is every host other than [kSamayLinkHost]. Parsing
/// never follows a redirect/`next` parameter, so there is no open redirect.
class DeepLinkHandler {
  const DeepLinkHandler();

  InviteLink? parseInviteLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    final segments = List<String>.of(uri.pathSegments)
      ..removeWhere((s) => s.isEmpty);

    if (uri.scheme == 'samay') {
      if (uri.host == 'event' && segments.length == 1) {
        return InviteLink(kind: InviteLinkKind.event, token: segments[0]);
      }
      final kind = _kindFromSegment(uri.host);
      if (kind != null && segments.length == 1 && segments[0].isNotEmpty) {
        return InviteLink(kind: kind, token: segments[0]);
      }
      return null;
    }

    // Only HTTPS on the canonical host. HTTP and unknown hosts are rejected.
    if (uri.scheme != 'https' || uri.host.toLowerCase() != kSamayLinkHost) {
      return null;
    }
    if (segments.length != 2 || segments[1].isEmpty) return null;
    final kind = _kindFromSegment(segments[0]);
    if (kind == null) return null;
    return InviteLink(kind: kind, token: segments[1]);
  }

  InviteLinkKind? _kindFromSegment(String segment) => switch (segment) {
    'e' || 'event' => InviteLinkKind.event,
    'g' || 'group' => InviteLinkKind.group,
    'u' || 'user' || 'profile' => InviteLinkKind.profile,
    _ => null,
  };

  /// Validates the token and opens the consent screen. No join happens here.
  Future<bool> handleDeepLink(
    String raw, {
    required GoRouter router,
    required bool isAuthenticated,
    required Future<bool> Function(InviteLink link) resolveLink,
    String? failureMessage,
  }) async {
    final link = parseInviteLink(raw);
    if (link == null) return false;

    // Authentication is mandatory: never render a preview to anon users.
    if (!isAuthenticated) {
      router.go(RoutePaths.login);
      return false;
    }

    bool valid = false;
    try {
      valid = await resolveLink(link);
    } catch (e, st) {
      AppLogger.instance.error('invite link resolution failed: $e', '$st');
      valid = false;
    }
    if (!valid) {
      // Still open the consent screen: it renders the localized invalid/expired
      // state for the token (replacing any engine-level "route not found").
      _showFailure(router, failureMessage);
      router.go(RoutePaths.inviteLink(link.kindSegment, link.token));
      return false;
    }

    router.go(RoutePaths.inviteLink(link.kindSegment, link.token));
    return true;
  }

  void _showFailure(GoRouter router, String? failureMessage) {
    try {
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context == null) return;
      final message =
          failureMessage ?? AppLocalizations.of(context).routerInvalidInvite;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      // No navigator context — the false return is still authoritative.
    }
  }
}

/// Raw deep-link stream (String URIs) feeding [DeepLinkListener].
final deepLinkStreamProvider = Provider<Stream<String>?>((ref) => null);

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
    final auth = ref.read(authStateProvider).valueOrNull;
    await const DeepLinkHandler().handleDeepLink(
      raw,
      router: router,
      isAuthenticated: auth?.authenticated ?? false,
      failureMessage: AppLocalizations.of(context).routerInvalidInvite,
      resolveLink: (link) async {
        final resolved = await service.resolveShareLink(link.token);
        return resolved != null;
      },
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
