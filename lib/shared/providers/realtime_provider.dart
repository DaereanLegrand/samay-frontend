import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef RealtimeCallback = void Function(Map<String, dynamic> data);

StreamProvider<Map<String, dynamic>> realtimeProvider(String channel, RealtimeCallback onData) {
  return StreamProvider<Map<String, dynamic>>((ref) {
    throw UnimplementedError('realtimeProvider needs SupabaseService');
  });
}
