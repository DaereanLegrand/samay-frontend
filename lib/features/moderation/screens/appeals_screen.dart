import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Appeals + reporter outcomes (Q6). Reachable from settings for every user
/// and from the banned screen (the AuthGuard allows this route while banned).
class AppealsScreen extends ConsumerStatefulWidget {
  const AppealsScreen({super.key, this.banAppeal = false});

  /// When true the screen focuses the ban-appeal form (no linked report).
  final bool banAppeal;

  @override
  ConsumerState<AppealsScreen> createState() => _AppealsScreenState();
}

class _AppealsScreenState extends ConsumerState<AppealsScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _appeals = const [];
  List<Map<String, dynamic>> _outcomes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(moderationServiceProvider);
      final appeals = await service.myAppeals();
      final outcomes = await service.myReportOutcomes();
      if (!mounted) return;
      setState(() {
        _appeals = appeals;
        _outcomes = outcomes;
      });
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final message = _controller.text.trim();
    if (message.length < 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.appealsMessageHint)));
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(moderationServiceProvider)
          .submitAppeal(
            message: message,
            reportId: widget.banAppeal ? null : null,
          );
      _controller.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.appealsSubmitted)));
      await _load();
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'reviewing':
        return l10n.appealStatusReviewing;
      case 'upheld':
        return l10n.appealStatusUpheld;
      case 'overturned':
        return l10n.appealStatusOverturned;
      case 'closed':
        return l10n.appealStatusClosed;
      default:
        return l10n.appealStatusOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.appealsTitle,
        child: _loading
            ? const VLoadingView()
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (widget.banAppeal) ...[
                      Text(
                        l10n.bannedAppealTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      VCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: TextField(
                            controller: _controller,
                            minLines: 3,
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: l10n.appealsMessageHint,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      VButton.outlined(
                        label: _submitting ? '…' : l10n.appealsSubmit,
                        onPressed: _submitting ? null : _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    Text(
                      l10n.appealsTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_appeals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          l10n.appealsEmpty,
                          style: TextStyle(color: context.palette.mutedForeground),
                        ),
                      )
                    else
                      for (final appeal in _appeals) ...[
                        VCard(
                          child: ListTile(
                            title: Text(
                              _statusLabel(
                                l10n,
                                appeal['status'] as String? ?? 'open',
                              ),
                            ),
                            subtitle: Text(
                              '${appeal['message'] ?? ''}\n'
                                      '${appeal['decision_note'] ?? ''}'
                                  .trim(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.reportOutcomesTitle,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_outcomes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        child: Text(
                          l10n.reportOutcomeEmpty,
                          style: TextStyle(color: context.palette.mutedForeground),
                        ),
                      )
                    else
                      for (final outcome in _outcomes)
                        VCard(
                          child: ListTile(
                            title: Text(
                              '${outcome['category'] ?? ''} · '
                              '${outcome['reporter_outcome'] ?? outcome['status'] ?? ''}',
                            ),
                            subtitle: Text(
                              outcome['resolution_note'] as String? ?? '',
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}
