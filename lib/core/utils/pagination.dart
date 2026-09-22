/// Reusable pagination primitives for list-style features.
///
/// The chat pagination pattern (`ChatMessagesState` +
/// offset/hasMore bookkeeping), shared so other list features — events list,
/// leaderboard, notifications history — get infinite-scroll pagination.
///
/// Pure Dart on purpose: no Riverpod import here, so the state machine stays
/// pure. Feature providers wire the fetch seam.
library;

/// One page-window of a paginated list: the accumulated rows plus the paging
/// flags a screen renders (a loader row, a "load more" button, an end-of-list
/// marker).
///
/// Immutable: every transformation returns a new instance with the untouched
/// fields carried over. `idOf` (optional) is the dedupe key extractor — when
/// provided, [append]/[prepend] drop incoming rows whose key already exists
/// (realtime rows can overlap page boundaries). Rows whose key is null are
/// never deduped and always kept.
class PagedState<T> {
  const PagedState({
    required this.items,
    required this.hasMore,
    required this.pageSize,
    this.loadingMore = false,
    this.nextOffset = 0,
    this.idOf,
  });

  /// Accumulated rows in display order (oldest first for history lists).
  final List<T> items;

  /// Whether the server may hold another page (a full page came back on the
  /// last fetch and the cap has not been reached).
  final bool hasMore;

  /// True while the next page is being fetched (loader row in the UI).
  final bool loadingMore;

  /// Rows requested per fetch.
  final int pageSize;

  /// Server offset of the next page (rows already consumed).
  final int nextOffset;

  /// Dedupe key extractor (row id); null disables dedupe. Rows whose key is
  /// null are never deduped and always kept.
  final String? Function(T)? idOf;

  /// Returns a copy with only the provided fields replaced. The id extractor
  /// is carried over, so dedupe keeps working on the new instance.
  PagedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
    int? pageSize,
    int? nextOffset,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      pageSize: pageSize ?? this.pageSize,
      nextOffset: nextOffset ?? this.nextOffset,
      idOf: idOf,
    );
  }

  /// Appends [newItems] at the end (newest end), dropping rows whose id
  /// already exists in [items] (the existing instance wins).
  PagedState<T> append(List<T> newItems) {
    return copyWith(items: [...items, ..._fresh(newItems)]);
  }

  /// Prepends [newItems] at the front (oldest end — older history pages),
  /// dropping rows whose id already exists in [items].
  PagedState<T> prepend(List<T> newItems) {
    return copyWith(items: [..._fresh(newItems), ...items]);
  }

  /// Resets to a fresh first-page state: no rows, `hasMore` true, offset 0.
  /// [pageSize] and the id extractor are preserved.
  PagedState<T> reset() {
    return copyWith(
      items: const [],
      hasMore: true,
      loadingMore: false,
      nextOffset: 0,
    );
  }

  /// [incoming] rows whose key is not already in [items] (null-key rows are
  /// always kept — they have no dedupe identity).
  List<T> _fresh(List<T> incoming) {
    final idOf = this.idOf;
    if (idOf == null) return incoming;
    final seen = <String>{
      for (final item in items) ?idOf(item),
    };
    final fresh = <T>[];
    for (final item in incoming) {
      final id = idOf(item);
      if (id == null || !seen.contains(id)) fresh.add(item);
    }
    return fresh;
  }
}

/// Plain paging-logic engine: owns the fetch seam ([fetch]), the dedupe key
/// ([idOf]), the page size and the `maxItems` cap, and produces the next
/// [PagedState] for [loadFirst]/[loadMore].
///
///
/// The DB rolling window stores at most `maxItems` rows per list (chat:
/// `chat.message_cap` = 1000, enforced by the `enforce_message_cap` trigger).
/// Pagination must never exceed it, so `hasMore` flips false once the
/// accumulated list reaches `maxItems` or the next page comes back short, and
/// [loadMore] refuses to fetch at/past the cap even against a stale state.
///
/// Failures are propagated unchanged: the caller (a provider) decides how to
/// surface them, keeping the last good state.
class PageLoader<T> {
  PageLoader({
    required this.fetch,
    required this.idOf,
    this.pageSize = 50,
    this.maxItems = 1000,
  });

  /// Loads one page: `(offset, limit)` → rows in display order (the feature
  /// seam — chat's repository already reverses DESC server order here).
  final Future<List<T>> Function(int offset, int limit) fetch;

  /// Dedupe key extractor (row id).
  final String? Function(T) idOf;

  /// Rows per fetch.
  final int pageSize;

  /// Hard cap on accumulated rows (see the message-cap note above).
  final int maxItems;

  /// Loads the first page (offset 0). `hasMore` = a full page came back and
  /// the cap was not reached.
  Future<PagedState<T>> loadFirst() async {
    final first = await fetch(0, pageSize);
    final nextOffset = first.length;
    return PagedState<T>(
      items: first,
      hasMore: nextOffset == pageSize && nextOffset < maxItems,
      pageSize: pageSize,
      nextOffset: nextOffset,
      idOf: idOf,
    );
  }

  /// Loads the page after [current] (at `current.nextOffset`), prepends it
  /// (deduplicated — realtime rows may overlap page boundaries) and returns
  /// the merged state with recomputed [PagedState.hasMore].
  ///
  /// Guards: a no-op (same state returned) when [current] has no more pages
  /// or is already loading; never fetches at/past [maxItems] (flips
  /// `hasMore` false instead — defensive against a stale flag).
  Future<PagedState<T>> loadMore(PagedState<T> current) async {
    if (!current.hasMore || current.loadingMore) return current;
    if (current.nextOffset >= maxItems) {
      return current.copyWith(hasMore: false, loadingMore: false);
    }
    final older = await fetch(current.nextOffset, pageSize);
    final nextOffset = current.nextOffset + older.length;
    final merged = current.prepend(older);
    final hasMore = older.length == pageSize &&
        nextOffset < maxItems &&
        merged.items.length < maxItems;
    return merged.copyWith(
      hasMore: hasMore,
      loadingMore: false,
      nextOffset: nextOffset,
    );
  }
}
