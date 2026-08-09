import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/events/event_formatters.dart';
import 'package:samay/features/events/events_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// Event detail (EDET): header, date/location, preshard pool status,
/// promotores, own invite status and role-based actions (edit/cancel for
/// promotores). Invitee actions (accept/decline) and the QR/scanner buttons
/// ship with EINV/QRAT.
class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _cancelling = false;

  Future<void> _cancelEvent() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.discoBlack,
        title: Text(
          l10n.eventCancelDialogTitle,
          style: const TextStyle(color: AppColors.white),
        ),
        content: Text(
          l10n.eventCancelDialogBody,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.eventCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      // NOTE (I-55): the client only flips the status. Returning the pool to
      // the promotores (preshard_ledger `event_pool_returned` + pool=0) is
      // server-side logic (Go admin CancelEvent / EEDG) — see the I-55 daily
      // log for the S-07/EEDG gap flag.
      await ref
          .read(eventDetailProvider(widget.eventId).notifier)
          .patch({'status': 'cancelled'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventCancelledSnack)),
      );
    } catch (e, _) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Widget _scaffold(Widget body) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).eventDetailTitle)),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(eventDetailProvider(widget.eventId));

    return detailAsync.when(
      loading: () => _scaffold(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _scaffold(ErrorView(
        message: e.toAppError().message,
        onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
      )),
      data: (event) {
        final promotoresAsync = ref.watch(eventPromotoresProvider(widget.eventId));
        final inviteAsync = ref.watch(myEventInviteProvider(widget.eventId));
        return _buildDetail(event, promotoresAsync, inviteAsync);
      },
    );
  }

  Widget _buildDetail(
    Map<String, dynamic> event,
    AsyncValue<List<Map<String, dynamic>>> promotoresAsync,
    AsyncValue<Map<String, dynamic>?> inviteAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final uid = ref
        .watch(authStateProvider)
        .valueOrNull
        ?.user?['id'] as String?;
    final status = event['status'] as String? ?? 'draft';
    final type = event['type'] as String? ?? 'casual';

    return Scaffold(
      appBar: AppBar(
        title: Text(event['name'] as String? ?? l10n.eventDetailTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          if (event['cover_url'] != null) ...[
            VNetworkImage(
              imageUrl: event['cover_url'] as String,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            event['name'] as String? ?? l10n.eventDetailTitle,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _TypeBadge(_typeLabel(l10n, type)),
              _StatusBadge(_statusLabel(l10n, status), status: status),
              if (event['group_id'] != null) _TypeBadge(l10n.eventGroupScoped),
            ],
          ),
          if (event['description'] != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              event['description'] as String,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.schedule,
            text: formatEventDateRange(
              DateTime.tryParse(event['starts_at'] as String? ?? '') ??
                  DateTime.now(),
              DateTime.tryParse(event['ends_at'] as String? ?? '') ??
                  DateTime.now(),
              Localizations.localeOf(context).languageCode,
            ),
          ),
          _InfoRow(
            icon: Icons.place_outlined,
            text: event['location_name'] as String? ?? l10n.eventNoLocation,
          ),
          if (event['group_id'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    context.push(RoutePaths.groupDetail(event['group_id'] as String)),
                icon: const Icon(Icons.group_outlined, size: 18),
                label: Text(l10n.eventViewGroup),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _buildPoolSection(event),
          const SizedBox(height: AppSpacing.xl),
          _buildPromotoresSection(promotoresAsync),
          if (inviteAsync.valueOrNull case final invite? when invite.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _InfoRow(
              icon: Icons.mail_outline,
              text: l10n.eventInviteStatus(
                _inviteStatusLabel(
                  l10n,
                  invite['status'] as String? ?? 'pending',
                ),
              ),
            ),
          ],
          if (_canEdit(uid, status, promotoresAsync.valueOrNull)) ...[
            const SizedBox(height: AppSpacing.xxl),
            VButton(
              label: l10n.eventEditButton,
              onPressed: () => context.push(RoutePaths.eventEdit(widget.eventId)),
            ),
          ],
          if (_canCancel(uid, status, promotoresAsync.valueOrNull)) ...[
            const SizedBox(height: AppSpacing.sm),
            VButton.outlined(
              label: l10n.eventCancelButton,
              loading: _cancelling,
              onPressed: _cancelling ? null : _cancelEvent,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  bool _canEdit(
    String? uid,
    String status,
    List<Map<String, dynamic>>? promotores,
  ) {
    if (uid == null || promotores == null) return false;
    if (status == 'ended' || status == 'cancelled') return false;
    return promotores.any(
      (p) => p['user_id'] == uid && p['role'] == 'promotor',
    );
  }

  bool _canCancel(String? uid, String status, List<Map<String, dynamic>>? promotores) {
    return _canEdit(uid, status, promotores);
  }

  Widget _buildPoolSection(Map<String, dynamic> event) {
    final l10n = AppLocalizations.of(context);
    final pool = (event['preshards_pool'] as num?)?.toInt() ?? 0;
    final distributed = event['preshards_distributed'] == true;
    final cap = event['preshards_cap_per_user'] as num?;
    final remainder = event['preshards_remainder_action'] as String?;

    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventsPreshardsPoolLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (pool <= 0)
            Text(l10n.eventNoPool,
                style: Theme.of(context).textTheme.bodyMedium)
          else ...[
            Row(
              children: [
                const VShardIcon(),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.eventPoolAmount(pool),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              distributed
                  ? l10n.eventPoolDistributed
                  : l10n.eventPoolNotDistributed,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (cap != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.eventCapPerUser(cap.toInt()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (remainder != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.eventRemainderAction(
                  remainder == 'redistribute'
                      ? l10n.eventsRemainderRedistribute
                      : l10n.eventsRemainderReturn,
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPromotoresSection(AsyncValue<List<Map<String, dynamic>>> async) {
    final l10n = AppLocalizations.of(context);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(
        l10n.eventPromotoresError,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      data: (promotores) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.eventPromotores,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (promotores.isEmpty)
            Text(
              l10n.eventNoPromotores,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final p in promotores)
                  _PromotorAvatar(
                    username: p['users']?['username'] as String? ??
                        '${p['user_id']}'.substring(0, 8),
                    role: p['role'] as String? ?? 'promotor',
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    return switch (type) {
      'casual' => l10n.eventsTypeCasual,
      'tono' => l10n.eventsTypeTono,
      _ => l10n.eventsTypeJuerga,
    };
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'draft' => l10n.eventStatusDraft,
      'live' => l10n.eventStatusLive,
      'ended' => l10n.eventStatusEnded,
      'cancelled' => l10n.eventStatusCancelled,
      _ => l10n.eventStatusUpcoming,
    };
  }

  String _inviteStatusLabel(AppLocalizations l10n, String status) {
    return switch (status) {
      'accepted' => l10n.eventInviteAccepted,
      'declined' => l10n.eventInviteDeclined,
      'attended' => l10n.eventInviteAttended,
      _ => l10n.eventInvitePending,
    };
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedStrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Status badge (ESTA §1): upcoming gray, live emphasized (white fill),
/// ended dark, cancelled red accent. Color is never the only signal — the
/// label carries the state (design doc §2.5 rule 5).
class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const _StatusBadge(this.label, {required this.status});

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (status) {
      'live' => (AppColors.discoBlack, AppColors.white),
      'cancelled' => (AppColors.discoBlack, AppColors.glowPink),
      'ended' => (AppColors.mutedStrong, AppColors.surfaceAlt),
      'draft' => (AppColors.mutedStrong, AppColors.surfaceAlt),
      _ => (AppColors.white, Colors.transparent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: status == 'cancelled' ? AppColors.glowPink : AppColors.white,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: AppColors.white),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PromotorAvatar extends StatelessWidget {
  final String username;
  final String role;

  const _PromotorAvatar({required this.username, required this.role});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roleLabel =
        role == 'promotor' ? l10n.eventRolePromotor : l10n.eventRoleCoPromotor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceAlt,
          child: Text(
            username.substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 16, color: AppColors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(username, style: Theme.of(context).textTheme.bodySmall),
        Text(
          roleLabel,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
