import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/core/utils/debouncer.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/friends/friends_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/show_app_error.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final Debouncer _debouncer = Debouncer();
  String _query = '';

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final config = ref.read(appConfigProvider).valueOrNull;
    final debounceMs = int.tryParse(config?['app.search_debounce_ms'] ?? '') ?? 300;
    _debouncer.delay = Duration(milliseconds: debounceMs);
    _debouncer.run(() {
      if (mounted) {
        setState(() {
          _query = InputSanitizer.sanitize(
            query,
            maxLength: InputSanitizer.searchQueryMaxLength,
          );
        });
      }
    });
  }

  Future<void> _sendFriendRequest(Map<String, dynamic> user) async {
    final userId = user['id'] as String;
    final l10n = AppLocalizations.of(context);
    try {
      await SupabaseService.instance.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.friendsRequestSent)),
        );
      }
      ref.invalidate(searchResultsProvider(_query));
    } catch (e, st) {
      AppLogger.instance.error('sendFriendRequest error: $e', '$st');
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsSearchUsers)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.friendsSearchPlaceholder,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (query.isEmpty)
            const Expanded(child: SizedBox.shrink())
          else
            Expanded(
              child: ref.watch(searchResultsProvider(query)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(
                  message: e.toAppError().message,
                  onRetry: () => ref.invalidate(searchResultsProvider(query)),
                ),
                data: (results) {
                  if (results.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.friendsNoUsersFound),
                    );
                  }
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final u = results[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                          ),
                        ),
                        title: Text('@${u['username']}'),
                        onTap: () => context.push(RoutePaths.userProfile(u['id'] as String)),
                        trailing: _buildButton(u),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(Map<String, dynamic> user) {
    final l10n = AppLocalizations.of(context);
    final status = user['friendship_status'] as String?;
    if (status == 'accepted') {
      return TextButton(onPressed: null, child: Text(l10n.friendsStatusAccepted));
    }
    if (status == 'pending') {
      return TextButton(onPressed: null, child: Text(l10n.friendsStatusPending));
    }
    if (status == 'blocked') {
      return TextButton(onPressed: null, child: Text(l10n.friendsStatusBlocked));
    }
    return TextButton(
      onPressed: () => _sendFriendRequest(user),
      child: Text(l10n.friendsAddFriendButton),
    );
  }
}
