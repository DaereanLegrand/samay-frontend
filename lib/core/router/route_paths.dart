abstract final class RoutePaths {
  static const welcome = '/';
  static const login = '/login';
  static const banned = '/banned';
  static const signup = '/auth/signup';
  static const verify = '/auth/verify';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const ageGate = '/auth/age-gate';
  static const privacyTerms = '/auth/privacy-terms';
  static const profileSetup = '/auth/profile-setup';
  static const mainFeed = '/main/feed';
  static const mainGroups = '/main/groups';
  static const mainGames = '/main/games';
  static const mainEvents = '/main/events';
  static const mainNotifications = '/main/notifications';
  static const mainProfile = '/main/profile';
  static const groupCreate = '/group/create';
  static const rankings = '/rankings';
  static const userSearch = '/user/search';
  static const friendsRequests = '/friends/requests';
  static const friendsList = '/friends/list';
  static const blockedUsers = '/settings/blocked';
  static const mutedUsers = '/settings/muted';
  static const appeals = '/appeals';

  static String appeal({bool banAppeal = false}) =>
      banAppeal ? '/appeals?ban=1' : '/appeals';
  static const subscriptions = '/subscriptions';
  static const cosmetics = '/cosmetics';
  static const shardsLedger = '/shards/ledger';
  static const settings = '/settings';
  static const deleteAccount = '/settings/delete-account';
  static const exportData = '/settings/export-data';
  static const profileEdit = '/profile/edit';

  static String eventDetail(String eventId) => '/event/$eventId';
  static String eventEdit(String eventId) => '/event/$eventId/edit';
  static String eventInvite(String eventId) => '/event/$eventId/invite';
  static String eventPhotos(String eventId) => '/event/$eventId/photos';
  static String eventCollage(String eventId) => '/event/$eventId/collage';
  static const eventCreate = '/events/create';
  static String inviteLink(String kind, String token) => '/link/$kind/$token';
  static String groupDetail(String groupId) => '/group/$groupId';
  static String groupMembers(String groupId) => '/group/$groupId/members';
  static String donateToGroup(String groupId) => '/group/$groupId/donate';
  static String createGroupEvent(String groupId) =>
      '/group/$groupId/create-event';
  static String inviteToGroup(String groupId) => '/group/$groupId/invite';

  static String minigames(String groupId) => '/minigames/$groupId';

  /// A fixed `/game/<game_type>` segment so the game landing page can never
  /// shadow the `:groupId` hub or the `/play` routes.
  static String minigame(String gameType) => '/minigames/game/$gameType';

  static String minigameSession(String sessionId) =>
      '/minigames/session/$sessionId';

  /// The Verdad o Reto play screen (fixed `/play/truth-dare` segment).
  static String truthDare(String sessionId) =>
      '/minigames/play/truth-dare/$sessionId';

  /// The Two Lies, One Truth play screen.
  static String twoLiesOneTruth(String sessionId) =>
      '/minigames/play/two-lies/$sessionId';

  /// The Botella (drunk bottle) play screen (fixed `/play/drunk-bottle` segment).
  static String drunkBottle(String sessionId) =>
      '/minigames/play/drunk-bottle/$sessionId';

  /// The Charadas play screen (fixed `/play/charades` segment).
  static String charades(String sessionId) =>
      '/minigames/play/charades/$sessionId';

  /// The finished-match leaderboard (fixed `/leaderboard` segment). When
  /// [participantId] is given the carousel opens focused on that player.
  static String minigameLeaderboard(String sessionId, {String? participantId}) {
    final base = '/minigames/leaderboard/$sessionId';
    return participantId == null || participantId.isEmpty
        ? base
        : '$base?p=$participantId';
  }

  /// Direct (group-less) minigames hub — registered before the `:groupId`
  /// hub so the static path cannot be shadowed.
  static const minigamesDirect = '/minigames';

  static String chat(String chatId) => '/chat/$chatId';
  static const chatList = '/chats';
  static String userProfile(String userId) => '/user/$userId';
  static String qr(String eventId) => '/qr/$eventId';
  static String scanner(String eventId) => '/scanner/$eventId';
}
