class SupabaseService {
  Future<void> signIn(String email, String password) async {
    throw UnimplementedError('signIn');
  }

  Future<void> signUp(String email, String password) async {
    throw UnimplementedError('signUp');
  }

  Future<void> signOut() async {
    throw UnimplementedError('signOut');
  }

  Future<void> verifyOTP(String token) async {
    throw UnimplementedError('verifyOTP');
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    throw UnimplementedError('getCurrentUser');
  }

  Future<void> updateUser(Map<String, dynamic> patch) async {
    throw UnimplementedError('updateUser');
  }

  Future<void> softDeleteUser() async {
    throw UnimplementedError('softDeleteUser');
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    throw UnimplementedError('createEvent');
  }

  Future<List<Map<String, dynamic>>> listEvents([String? status, String? type]) async {
    throw UnimplementedError('listEvents');
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    throw UnimplementedError('getEvent');
  }

  Future<void> updateEvent(String id, Map<String, dynamic> patch) async {
    throw UnimplementedError('updateEvent');
  }

  Future<void> sendFriendRequest(String userId) async {
    throw UnimplementedError('sendFriendRequest');
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    throw UnimplementedError('acceptFriendRequest');
  }

  Future<void> declineFriendRequest(String friendshipId) async {
    throw UnimplementedError('declineFriendRequest');
  }

  Future<void> blockUser(String userId) async {
    throw UnimplementedError('blockUser');
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    throw UnimplementedError('createGroup');
  }

  Future<void> joinGroup(String groupId) async {
    throw UnimplementedError('joinGroup');
  }

  Future<void> leaveGroup(String groupId) async {
    throw UnimplementedError('leaveGroup');
  }

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async {
    throw UnimplementedError('loadMessages');
  }

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async {
    throw UnimplementedError('sendMessage');
  }

  Future<void> uploadPhoto(String eventId, String filePath) async {
    throw UnimplementedError('uploadPhoto');
  }

  Future<String> getSignedPhotoUrl(String storagePath) async {
    throw UnimplementedError('getSignedPhotoUrl');
  }

  Future<void> likePhoto(String photoId) async {
    throw UnimplementedError('likePhoto');
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    throw UnimplementedError('getNotifications');
  }

  Future<void> markNotificationRead(String id) async {
    throw UnimplementedError('markNotificationRead');
  }

  Future<void> donateToGroup(String groupId, int amount) async {
    throw UnimplementedError('donateToGroup');
  }

  Future<void> purchaseCosmetic(String cosmeticId) async {
    throw UnimplementedError('purchaseCosmetic');
  }

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    throw UnimplementedError('reportContent');
  }

  Future<Map<String, String>> fetchAppConfig() async {
    throw UnimplementedError('fetchAppConfig');
  }

  Future<void> subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) async {
    throw UnimplementedError('subscribeToMessages');
  }

  Future<void> subscribeToNotifications(void Function(Map<String, dynamic>) onInsert) async {
    throw UnimplementedError('subscribeToNotifications');
  }

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async {
    throw UnimplementedError('subscribeToEventStatus');
  }

  Future<void> subscribeToQRToken(String eventId, void Function(String) onUpdate) async {
    throw UnimplementedError('subscribeToQRToken');
  }

  Future<Map<String, dynamic>> callEdgeFunction(String name, Map<String, dynamic> body) async {
    throw UnimplementedError('callEdgeFunction');
  }
}
