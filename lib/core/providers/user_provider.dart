import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/services/supabase_service.dart';

final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (!auth.authenticated) return null;
  return SupabaseService.instance.getCurrentUser();
});
