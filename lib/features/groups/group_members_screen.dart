import 'package:flutter/material.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/l10n/app_localizations.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;

  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await SupabaseService.instance.getGroupMembers(widget.groupId);
      if (!mounted) return;
      setState(() => _members = members);
    } catch (e, st) {
      AppLogger.instance.error('GroupMembersScreen._load error: $e', st.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsMembersTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
              ? Center(
                  child: Text(
                    l10n.groupsNoMembers,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final m = _members[index];
                    final user = m['users'] as Map<String, dynamic>?;
                    final rawUsername = user?['username'] as String?;
                    final userId = m['user_id']?.toString() ?? '';
                    final username = (rawUsername == null || rawUsername.isEmpty)
                        ? (userId.isEmpty
                            ? l10n.commonUser
                            : userId.substring(0, userId.length < 8 ? userId.length : 8))
                        : rawUsername;
                    final initials = username.substring(0, 1).toUpperCase();
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[800],
                        child: Text(initials, style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(username),
                      subtitle: Text(m['role'] as String? ?? 'member'),
                    );
                  },
                ),
    );
  }
}
