import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/friends_repository.dart';
import 'package:samay/core/repositories/groups_repository.dart';
import 'package:samay/core/repositories/profile_repository.dart';

/// Riverpod wiring for the repository layer.
///
/// One singleton instance per container, overridable in tests:
///
/// ```dart
/// final container = ProviderContainer(overrides: [
///   friendsRepositoryProvider.overrideWithValue(mockRepository),
/// ]);
/// ```
///
/// Overriding a service provider (e.g. `userServiceProvider`) also rewires
/// the repositories, since they are built from the service providers via
/// `ref.watch`. There is deliberately NO chat repository provider here — the
/// chat feature wires its own E2EE repository (`chatE2eeRepositoryProvider`,
/// `lib/features/chat/chat_providers.dart`); see `chat_repository.dart`.
final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(
    users: ref.watch(userServiceProvider),
    friendships: ref.watch(friendshipServiceProvider),
    discovery: ref.watch(discoveryServiceProvider),
  );
});

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(groups: ref.watch(groupServiceProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(users: ref.watch(userServiceProvider));
});
