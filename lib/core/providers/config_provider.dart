import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';

final appConfigProvider = FutureProvider<Map<String, String>>((ref) async {
  return ref.watch(configServiceProvider).fetchAppConfig();
});
