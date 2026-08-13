import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/features/events/screens/event_detail_screen.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';

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

  /// The events ambient background (LUXE v2): black + a faint peach aurora —
  /// the peach accent for the loading/error/not-found states.
  static Widget _ambient(Widget child) {
    return VAurora(
      gradients: const [AppGradients.peach],
      opacity: 0.08,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(eventByInviteTokenProvider(token));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.eventDetailTitle)),
        body: _ambient(const VLoadingView()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.eventDetailTitle)),
        body: _ambient(
          ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(eventByInviteTokenProvider(token)),
          ),
        ),
      ),
      data: (event) {
        if (event == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.eventDetailTitle)),
            body: _ambient(
              VEmptyView(
                icon: Icons.link_off_outlined,
                title: l10n.routerInvalidInvite,
                actionLabel: l10n.commonBack,
                onAction: () => Navigator.of(context).maybePop(),
              ),
            ),
          );
        }
        return EventDetailScreen(eventId: event.id);
      },
    );
  }
}
