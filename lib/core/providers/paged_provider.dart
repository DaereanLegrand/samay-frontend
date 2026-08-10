import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/utils/pagination.dart';

/// Base class for paginated-list feature providers (I-72): the Riverpod seam
/// over the pure-Dart [PageLoader] engine.
///
/// A feature notifier extends this and implements [createLoader] (its
/// repository/service fetch seam + id extractor + page size + cap); the
/// paging lifecycle comes for free:
///
/// - [build] loads the first page ([PageLoader.loadFirst]),
/// - [loadOlder] fetches the next page, guarded against an in-flight fetch
///   ([PagedState.loadingMore]), an exhausted list ([PagedState.hasMore]) and
///   the `maxItems` cap ([PageLoader]),
/// - [refresh] re-runs [build] (SM-09 contract, `ref.invalidateSelf()`).
///
/// Failures leave the previous state intact (the loading flag is cleared) and
/// are rethrown so the UI can surface them — [build] failures surface as the
/// provider's `AsyncError` automatically.
///
/// Non-family lists extend this directly. Family features (per-chat, per-event
/// lists) extend `FamilyAsyncNotifier<PagedState<T>, Arg>` and use
/// [PageLoader] directly — see `ChatMessagesNotifier` in
/// `lib/features/chat/chat_providers.dart` (I-56's state shape is preserved
/// there via the `PagedState`-wrapping `ChatMessagesState`).
abstract class PagedProvider<T> extends AsyncNotifier<PagedState<T>> {
  late PageLoader<T> _loader;

  /// Builds this feature's page loader: the fetch seam
  /// (`(offset, limit) => repository.list(limit: limit, offset: offset)`),
  /// the dedupe id extractor, the [PageLoader.pageSize] and the
  /// [PageLoader.maxItems] cap. Called fresh from every [build], so a
  /// refresh restarts from the first page.
  PageLoader<T> createLoader();

  @override
  Future<PagedState<T>> build() async {
    _loader = createLoader();
    return _loader.loadFirst();
  }

  /// Re-runs [build] (SM-09 refresh contract).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Fetches the next page, prepending it to the current list. Guards: no-op
  /// when the list is not loaded yet, already loading, or has no more pages
  /// (including the cap — see [PageLoader]). On failure the previous state is
  /// kept (loading flag cleared) and the error is rethrown.
  Future<void> loadOlder() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      state = AsyncData(await _loader.loadMore(current));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}
