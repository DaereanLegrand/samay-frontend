import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/auth_service.dart';
import 'package:samay/core/services/ban_service.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:samay/core/services/event_service.dart';
import 'package:samay/core/services/group_service.dart';
import 'package:samay/core/services/media_service.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/moderation_service.dart';
import 'package:samay/core/services/notification_service.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/services/shards_service.dart';
import 'package:samay/core/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Riverpod wiring for the decomposed feature services (I-11, ARC-05/CQ-01).
///
/// One singleton instance per container. Override [supabaseClientProvider] in
/// tests to inject a mock client and exercise any service in isolation:
///
/// ```dart
/// final container = ProviderContainer(overrides: [
///   supabaseClientProvider.overrideWithValue(mockClient),
/// ]);
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final configServiceProvider = Provider<ConfigService>((ref) {
  return ConfigService(client: ref.watch(supabaseClientProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    client: ref.watch(supabaseClientProvider),
    config: ref.watch(configServiceProvider),
  );
});

final banServiceProvider = Provider<BanService>((ref) {
  return BanService(client: ref.watch(supabaseClientProvider));
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(client: ref.watch(supabaseClientProvider));
});

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(client: ref.watch(supabaseClientProvider));
});

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(client: ref.watch(supabaseClientProvider));
});

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService(client: ref.watch(supabaseClientProvider));
});

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
  );
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
  );
});

final shardsServiceProvider = Provider<ShardsService>((ref) {
  return ShardsService(
    client: ref.watch(supabaseClientProvider),
    config: ref.watch(configServiceProvider),
  );
});

final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService(client: ref.watch(supabaseClientProvider));
});

final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(client: ref.watch(supabaseClientProvider));
});

final minigameServiceProvider = Provider<MinigameService>((ref) {
  return MinigameService(
    client: ref.watch(supabaseClientProvider),
    realtime: ref.watch(realtimeServiceProvider),
  );
});
