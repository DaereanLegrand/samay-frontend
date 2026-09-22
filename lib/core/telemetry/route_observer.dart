import 'package:flutter/widgets.dart';
import 'package:samay/core/services/telemetry_service.dart';

/// Reports route changes to [TelemetryService] as `screen_view` events
///
/// Registered as a [NavigatorObserver] on the app's [GoRouter] (inside
/// `routerProvider`). go_router sets each page's `RouteSettings.name` to the
/// matched route path (parameters filled, e.g. `/event/11111111-...`), which
/// is what we report as the screen identifier.
///
/// A screen is reported only when a NEW route becomes visible
/// (`didPush`/`didReplace`); `didPop`/`didRemove` are ignored — the popped
/// route was already tracked when it was pushed, and reporting pops would
/// double-count back-navigation as fresh views. Routes without a `name`
/// (error pages, unnamed initial routes) are ignored too.
///
/// go_router pushes BOTH the shell page and the nested tab page on a shell
/// navigation (they share the same matched path) — consecutive same-screen
/// events are deduped so each screen view is recorded once.
class RouterObserver extends NavigatorObserver {
  RouterObserver(this._telemetry);

  final TelemetryService _telemetry;

  String? _lastReportedScreen;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final route = newRoute;
    if (route == null) return;
    _report(route);
  }

  void _report(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    if (name == _lastReportedScreen) return;
    _lastReportedScreen = name;
    _telemetry.track('screen_view', properties: {'screen': name});
  }
}
