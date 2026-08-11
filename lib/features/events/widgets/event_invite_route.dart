import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/features/events/screens/event_detail_screen.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/route_error_screen.dart';
import 'package:samay/shared/widgets/state_views.dart';

/// EINV (I-66): resolves a `/event/<invite_token>` deep link into the event
/// detail screen.
///
/// The single `/event/:eventId` route branches here for token-shaped params
/// (non-UUID — UUID params are event ids and render [EventDetailScreen]
/// directly). The former `/event/:inviteToken` route was SHADOWED by
/// `/event/:eventId` (I-55's documented ordering issue) and has been
/// removed; the token path shows a loading state while resolving, then the
/// detail screen, a not-found fallback for unknown tokens, or an error view
/// with retry for resolution failures.
class EventInviteRoute extends ConsumerWidget {
  const EventInviteRoute({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(eventByInviteTokenProvider(token));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.eventDetailTitle)),
        body: const VLoadingView(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.eventDetailTitle)),
        body: ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(eventByInviteTokenProvider(token)),
        ),
      ),
      data: (event) {
        if (event == null) {
          return RouteErrorScreen(message: l10n.routerInvalidInvite);
        }
        return EventDetailScreen(eventId: event.id);
      },
    );
  }
}
