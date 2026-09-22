import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/utils/debouncer.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:samay/features/friends/providers/user_search_provider.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';

/// Reusable user multi-select picker — the shared "pick users
/// by searching" widget behind the minigame invite flow, built from the
/// proven /chat + group-invite patterns:
///
/// * the debounced search field (same `Debouncer` + `InputSanitizer` +
///   `app.search_debounce_ms` plumbing as `SearchScreen` / `InviteScreen`);
/// * the [userSearchProvider] pool — cached friends below 5 chars, backend
///   results + friends merged (dedup, friends first) above;
/// * the `ProfileAvatar` + `@username` + trailing-action row shape from
///   `SearchScreen`.
///
/// The widget is pure and callback-driven: it owns the search + selection
/// state and reports selection changes via [onSelectionChanged]; the owning
/// screen owns the scaffold, the submit action and the empty/error copy. This
/// is the `ChatThreadView` thin-scaffold architecture applied to picking
/// users — `MinigameInviteScreen` mounts it, and the group `InviteScreen` /
/// future flows can adopt it without changing the search code.
class UserPickerView extends ConsumerStatefulWidget {
  const UserPickerView({
    super.key,
    this.excludedIds = const {},
    this.maxSelection,
    this.onSelectionChanged,
    this.searchHint,
    this.trailingBuilder,
  });

  /// User ids that must not appear (e.g. already-participant members).
  final Set<String> excludedIds;

  /// Optional cap on how many users can be selected.
  final int? maxSelection;

  /// Fired with the current selection after every toggle.
  final ValueChanged<Set<String>>? onSelectionChanged;

  final String? searchHint;

  /// Optional per-row trailing widget (e.g. the minigame host picker's
  /// "sent"/"enviada" tag for already-pending invitees). When null the row
  /// falls back to the selection [Checkbox]. Kept opt-in so the shared picker
  /// (groups invite, chat) renders exactly as before.
  final Widget? Function(UserSearchResult user)? trailingBuilder;

  @override
  ConsumerState<UserPickerView> createState() => _UserPickerViewState();
}

class _UserPickerViewState extends ConsumerState<UserPickerView> {
  final _controller = TextEditingController();
  late final Debouncer _debouncer;
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final config = ref.read(appConfigProvider).valueOrNull;
    final debounceMs =
        int.tryParse(config?['app.search_debounce_ms'] ?? '') ?? 300;
    _debouncer.delay = Duration(milliseconds: debounceMs);
    _debouncer.run(() {
      if (mounted) {
        setState(() {
          _query = InputSanitizer.sanitize(
            _controller.text,
            maxLength: InputSanitizer.searchQueryMaxLength,
          );
        });
      }
    });
  }

  void _toggle(UserSearchResult user) {
    final id = user.id;
    final max = widget.maxSelection;
    if (_selected.contains(id)) {
      setState(() => _selected.remove(id));
    } else {
      if (max != null && _selected.length >= max) return;
      setState(() => _selected.add(id));
    }
    widget.onSelectionChanged?.call(Set.of(_selected));
  }

  // An empty (non-null) username would RangeError on substring — the '?'
  // initial fallback.
  String _initials(UserSearchResult user) {
    final username = user.username;
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _query;
    final excluded = widget.excludedIds;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: widget.searchHint ?? l10n.groupsSearchUsersHint,
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              filled: false,
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        ),
        Expanded(
          child: ref.watch(userSearchProvider(query)).when(
            loading: () => const VLoadingView(),
            error: (e, _) => ErrorView(
              message: e.toAppError().message,
              onRetry: () => ref.invalidate(userSearchProvider(query)),
            ),
            data: (results) {
              final filtered = results
                  .where((u) => !excluded.contains(u.id))
                  .toList();
              return _listOrEmpty(context, filtered, l10n);
            },
          ),
        ),
      ],
    );
  }

  Widget _listOrEmpty(
    BuildContext context,
    List<UserSearchResult> results,
    AppLocalizations l10n, {
    String? emptyText,
  }) {
    if (results.isEmpty) {
      return Center(
        child: Text(
          emptyText ?? l10n.groupsNoResults,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final u = results[i];
        final uid = u.id;
        final selected = _selected.contains(uid);
        final trailing = widget.trailingBuilder?.call(u);
        return VCard(
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              leading: ProfileAvatar(
                size: AppSpacing.avatar,
                initials: _initials(u),
                imageUrl: u.avatarUrl,
              ),
              title: Text('@${u.username}'),
              trailing: trailing ??
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggle(u),
                  ),
              onTap: () => _toggle(u),
            ),
          ),
        );
      },
    );
  }
}