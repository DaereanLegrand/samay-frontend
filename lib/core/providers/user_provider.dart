import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';

final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (auth.valueOrNull?.authenticated != true) return null;
  return ref.watch(authServiceProvider).getCurrentUserProfile();
});
