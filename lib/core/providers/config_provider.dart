import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/supabase_service.dart';

final appConfigProvider = FutureProvider<Map<String, String>>((ref) async {
  return SupabaseService.instance.fetchAppConfig();
});
