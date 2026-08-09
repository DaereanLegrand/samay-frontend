import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/core/utils/debouncer.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/friends/friends_providers.dart';
import 'package:samay/features/groups/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String groupId;
  const InviteScreen({super.key, required this.groupId});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _searchController = TextEditingController();
  late final Debouncer _debouncer;
  final Set<String> _selectedIds = {};
  String _query = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final config = ref.read(appConfigProvider).valueOrNull;
    final debounceMs = int.tryParse(config?['app.search_debounce_ms'] ?? '') ?? 300;
    _debouncer.delay = Duration(milliseconds: debounceMs);
    _debouncer.run(() {
      if (mounted) {
        setState(() {
          _query = InputSanitizer.sanitize(
            _searchController.text,
            maxLength: InputSanitizer.searchQueryMaxLength,
          );
        });
      }
    });
  }

  Future<void> _invite() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      for (final id in _selectedIds) {
        await SupabaseService.instance.client.from('group_members').insert({
          'group_id': widget.groupId,
          'user_id': id,
          'role': 'member',
          'status': 'invited',
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.groupsInvitedCount(_selectedIds.length))),
        );
        context.pop();
      }
    } catch (e, st) {
      AppLogger.instance.error('invite error: $e', '$st');
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final l10n = AppLocalizations.of(context);
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final memberIds =
        membersAsync.valueOrNull?.map((m) => m['user_id'] as String).toSet() ??
            const <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.groupsInviteTitle),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _sending ? null : _invite,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.groupsInviteCount(_selectedIds.length)),
            ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(groupMembersProvider(widget.groupId)),
        ),
        data: (_) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.groupsSearchUsersHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (query.length < 2)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.groupsMinCharsHint,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Expanded(
                child: ref.watch(searchResultsProvider(query)).when(
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (e, _) => ErrorView(
                    message: e.toAppError().message,
                    onRetry: () => ref.invalidate(searchResultsProvider(query)),
                  ),
                  data: (users) {
                    final results =
                        users.where((u) => !memberIds.contains(u['id'] as String)).toList();
                    if (results.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.groupsNoResults,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final u = results[i];
                        final uid = u['id'] as String;
                        final selected = _selectedIds.contains(uid);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[800],
                            child: Text(
                              (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text('@${u['username']}'),
                          trailing: Checkbox(
                            value: selected,
                            onChanged: (_) => _toggle(uid),
                          ),
                          onTap: () => _toggle(uid),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggle(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
      } else {
        _selectedIds.add(uid);
      }
    });
  }
}
