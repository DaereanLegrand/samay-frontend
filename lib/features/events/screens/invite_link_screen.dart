import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/location_service.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Consent screen for `/e/`, `/g/` and `/u/` links.
///
/// Opening a link only previews it (Q9: no auto-join). The user must tap the
/// explicit action; only then does the server create a membership, join
/// request or friend request. Event previews obey Q2: city + distance before
/// acceptance, exact venue only when the viewer is already host/staff/accepted.
class InviteLinkScreen extends ConsumerStatefulWidget {
  const InviteLinkScreen({
    super.key,
    required this.kind,
    required this.token,
  });

  final String kind;
  final String token;

  @override
  ConsumerState<InviteLinkScreen> createState() => _InviteLinkScreenState();
}

class _InviteLinkScreenState extends ConsumerState<InviteLinkScreen> {
  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _done;
  String? _eventId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Distance is only meaningful for event links; a slow/denied location
      // fix must never block the consent screen.
      double? lat;
      double? lng;
      if (widget.kind == 'e') {
        final location = await const LocationService()
            .current()
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
        lat = location?.latitude;
        lng = location?.longitude;
      }
      final preview = await ref
          .read(eventServiceProvider)
          .resolveShareLink(widget.token, lat: lat, lng: lng);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
        _error = preview == null ? 'invalid' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _act() async {
    final service = ref.read(eventServiceProvider);
    setState(() => _busy = true);
    try {
      Map<String, dynamic> result;
      switch (widget.kind) {
        case 'g':
          result = await service.joinGroupByLink(widget.token);
        case 'u':
          result = await service.requestFriendByProfileLink(widget.token);
        default:
          result = await service.joinEventByLink(widget.token);
      }
      final status = result['status'] as String? ?? '';
      if (!mounted) return;
      if (status == 'joined') {
        final id = result['event_id'] as String?;
        ref.invalidate(eventDetailProvider(id ?? ''));
        ref.invalidate(myEventInviteProvider(id ?? ''));
        setState(() {
          _done = AppLocalizations.of(context).linkEventJoined;
          _eventId = id;
        });
      } else if (status == 'requested' || status == 'invited') {
        setState(() => _done = AppLocalizations.of(context).linkRequestSent);
      } else if (status == 'already_member' ||
          status == 'already_friends' ||
          status == 'already_requested' ||
          status == 'already_invited' ||
          status == 'request_pending' ||
          status == 'request_incoming') {
        setState(() => _done = AppLocalizations.of(context).linkRequestSent);
      } else if (status == 'capacity_reached') {
        setState(() => _error = 'capacity');
      } else {
        setState(() => _error = status);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        body: VHeaderBar(
          title: l10n.linkConsentTitle,
          child: const VLoadingView(),
        ),
      );
    }
    if (_error != null || _preview == null) {
      return Scaffold(
        body: VHeaderBar(
          title: l10n.linkConsentTitle,
          child: ErrorView(
            message: l10n.linkInvalid,
            onRetry: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
          ),
        ),
      );
    }

    final p = _preview!;
    final kind = switch (p['kind']) {
      'event' => 'e',
      'group' => 'g',
      'profile' => 'u',
      _ => widget.kind,
    };
    final state = p['viewer_state'] as String? ?? 'viewer';
    final canAct = p['can_join'] == true && _done == null;
    final name = p['name'] as String? ?? '';
    final city = p['location_city'] as String?;
    final venue = p['location_name'] as String?;
    final distance = p['distance_km'];

    return Scaffold(
      body: VHeaderBar(
        title: l10n.linkConsentTitle,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            VCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    switch (kind) {
                      'g' => 'Grupo · ${p['member_count'] ?? 0} miembros',
                      'u' => '@${p['username'] ?? name}',
                      _ => city ?? l10n.eventNoLocation,
                    },
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                  if (kind == 'event') ...[
                    if (distance != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.linkDistance(
                          (distance as num).toStringAsFixed(1),
                        ),
                        style: const TextStyle(color: AppColors.mutedStrong),
                      ),
                    ],
                    if (venue != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        venue,
                        style: const TextStyle(color: AppColors.white),
                      ),
                    ],
                  ],
                  if (p['description'] != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      p['description'] as String,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_done != null) ...[
              Text(
                _done!,
                style: const TextStyle(color: AppColors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_eventId != null)
                VButton.dark(
                  label: l10n.eventDetailTitle,
                  onPressed: () => context.go(RoutePaths.eventDetail(_eventId!)),
                ),
              const SizedBox(height: AppSpacing.sm),
              VButton.outlined(
                label: l10n.commonBack,
                onPressed: () => context.go(RoutePaths.mainFeed),
              ),
            ] else if (canAct)
              VButton.dark(
                label: switch (kind) {
                  'g' => l10n.linkJoinGroup,
                  'u' => l10n.linkAddFriend,
                  _ => state == 'pending'
                      ? l10n.linkRequestJoin
                      : l10n.linkJoinEvent,
                },
                loading: _busy,
                onPressed: _busy ? null : _act,
              )
            else
              Text(
                _stateLabel(l10n, kind, state),
                style: const TextStyle(color: AppColors.mutedStrong),
              ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n, String kind, String state) {
    if (state == 'self') return l10n.linkOwnProfile;
    if (state == 'friends') return l10n.linkRequestSent;
    if (state == 'member') return l10n.linkAlreadyMember;
    if (state == 'pending' || state == 'requested' || state == 'invited') {
      return l10n.linkRequestSent;
    }
    return l10n.linkInvalid;
  }
}
