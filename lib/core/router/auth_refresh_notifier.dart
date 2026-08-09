import 'package:flutter/foundation.dart';

/// Bridges auth state changes into `GoRouter`'s `refreshListenable`
/// (finding NAV-07 / M-09).
///
/// `routerProvider` feeds this notifier via `ref.listen(authStateProvider, ...)`;
/// every auth state emission triggers a redirect re-evaluation, so login,
/// logout, token refresh and profile-creation land immediately instead of on
/// the next navigation.
class AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
