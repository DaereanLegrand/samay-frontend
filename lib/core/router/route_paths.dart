abstract final class RoutePaths {
  /// Guest-first entry: the games deck. Reached only once onboarding is done
  /// (a guest with a profile) — otherwise the guard lands on [onboarding].
  static const gamesHome = '/';

  /// The single onboarding screen: 18+ confirmation + terms & privacy.
  static const onboarding = '/onboarding';

  /// Optional account upgrade (Sign in with Apple / Google). Reachable from
  /// the games menu and from Settings; never required to play.
  static const signIn = '/sign-in';

  /// Store-compliance surfaces for a suspended account.
  static const banned = '/banned';
  static const appeals = '/appeals';

  static String appeal({bool banAppeal = false}) =>
      banAppeal ? '/appeals?ban=1' : '/appeals';

  // ── Games ──────────────────────────────────────────────────────────────
  /// A game's landing page: rules, packs, "nueva partida", ongoing partidas.
  static String minigame(String gameType) => '/minigames/game/$gameType';

  /// The server (multi-device) partida lobby.
  static String minigameSession(String sessionId) =>
      '/minigames/session/$sessionId';

  /// The single-device "pass the phone" setup + play surface.
  static String localMatch(String gameType) => '/minigames/local/$gameType';

  /// The multi-device hub (direct + group scopes, join-by-code).
  static const minigamesDirect = '/minigames';

  /// The group-scoped hub.
  static String minigames(String groupId) => '/minigames/$groupId';

  static String truthDare(String sessionId) =>
      '/minigames/play/truth-dare/$sessionId';

  static String twoLiesOneTruth(String sessionId) =>
      '/minigames/play/two-lies/$sessionId';

  static String drunkBottle(String sessionId) =>
      '/minigames/play/drunk-bottle/$sessionId';

  static String charades(String sessionId) =>
      '/minigames/play/charades/$sessionId';

  static String minigameLeaderboard(String sessionId, {String? participantId}) {
    final base = '/minigames/leaderboard/$sessionId';
    return participantId == null || participantId.isEmpty
        ? base
        : '$base?p=$participantId';
  }

  /// QR join: the scanner reads a partida's join code. The QR itself encodes
  /// `samay://join/<CODE>`; the code is the same 6-character code the manual
  /// entry dialog accepts.
  static const joinScanner = '/minigames/scan';

  // ── Social (friends + groups) ──────────────────────────────────────────
  static const social = '/social';
  static const groupCreate = '/group/create';
  static String groupDetail(String groupId) => '/group/$groupId';
  static String groupMembers(String groupId) => '/group/$groupId/members';
  static String groupTheme(String groupId) => '/group/$groupId/theme';
  static String inviteToGroup(String groupId) => '/group/$groupId/invite';
  static const userSearch = '/user/search';
  static String userProfile(String userId) => '/user/$userId';
  static const friendsRequests = '/friends/requests';
  static const friendsList = '/friends/list';
  static const blockedUsers = '/settings/blocked';
  static const mutedUsers = '/settings/muted';

  // ── Packs / monetization ──────────────────────────────────────────────
  static const promptPacks = '/packs';
  static const subscriptions = '/subscriptions';

  // ── Profile / settings ────────────────────────────────────────────────
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const settings = '/settings';
  static const appTheme = '/settings/appearance';
  static const deleteAccount = '/settings/delete-account';
  static const exportData = '/settings/export-data';

  // ── Notifications ─────────────────────────────────────────────────────
  static const notifications = '/notifications';
}
