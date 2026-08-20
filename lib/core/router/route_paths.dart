abstract final class RoutePaths {
  static const welcome = '/';
  static const login = '/login';
  static const banned = '/banned';
  static const signup = '/auth/signup';
  static const verify = '/auth/verify';
  // U-14 R3: the dedicated password-recovery screen (replaces login's inline
  // resetPasswordForEmail call — Juega's `/forgot-password`, `app_router.dart:37`).
  static const forgotPassword = '/forgot-password';
  static const ageGate = '/auth/age-gate';
  static const privacyTerms = '/auth/privacy-terms';
  static const profileSetup = '/auth/profile-setup';
  static const authPrefix = '/auth/';
  static const mainFeed = '/main/feed';
  static const mainGroups = '/main/groups';
  static const mainEvents = '/main/events';
  static const mainNotifications = '/main/notifications';
  static const mainProfile = '/main/profile';
  static const groupCreate = '/group/create';
  static const groupsLeaderboard = '/groups/leaderboard';
  static const userRanking = '/ranking/users';
  static const userSearch = '/user/search';
  static const friendsRequests = '/friends/requests';
  static const friendsList = '/friends/list';
  static const blockedUsers = '/settings/blocked';
  static const subscriptions = '/subscriptions';
  static const partyFinder = '/party-finder';
  static const cosmetics = '/cosmetics';
  static const shardsLedger = '/shards/ledger';
  static const settings = '/settings';
  static const deleteAccount = '/settings/delete-account';
  static const profileEdit = '/profile/edit';

  static String eventDetail(String eventId) => '/event/$eventId';
  static String eventEdit(String eventId) => '/event/$eventId/edit';
  static String eventInvite(String eventId) => '/event/$eventId/invite';
  static String eventPhotos(String eventId) => '/event/$eventId/photos';
  static String eventCollage(String eventId) => '/event/$eventId/collage';
  static String eventInviteToken(String token) => '/event/$token';
  static String groupDetail(String groupId) => '/group/$groupId';
  static String groupMembers(String groupId) => '/group/$groupId/members';
  static String donateToGroup(String groupId) => '/group/$groupId/donate';
  static String createGroupEvent(String groupId) =>
      '/group/$groupId/create-event';
  static String inviteToGroup(String groupId) => '/group/$groupId/invite';
  static String minigames(String groupId) => '/minigames/$groupId';
  static String chat(String chatId) => '/chat/$chatId';
  static const chatList = '/chats';
  static String userProfile(String userId) => '/user/$userId';
  static String qr(String eventId) => '/qr/$eventId';
  static String scanner(String eventId) => '/scanner/$eventId';
}
