import 'package:flutter/material.dart';

/// Pull-to-refresh wrapper for content that is shorter than the viewport —
/// the R13 (F3) "every list refreshes, including empty states" pattern.
///
/// Wraps [child] in a `RefreshIndicator` over an always-scrollable view that
/// fills the available height, so a centered `VEmptyView` (or any short
/// content) still answers a drag. Lists already scrollable on their own
/// should keep their `RefreshIndicator` directly around the `ListView`.
class VRefreshable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const VRefreshable({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}
