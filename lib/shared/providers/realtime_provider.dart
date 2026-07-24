import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef RealtimeCallback = void Function(Map<String, dynamic> data);

StreamProvider<Map<String, dynamic>> realtimeProvider(
  String channelName,
  String table,
  PostgresChangeEvent event,
) {
  return StreamProvider<Map<String, dynamic>>((ref) {
    final controller = StreamController<Map<String, dynamic>>();

    final channel = Supabase.instance.client.channel(channelName);
    channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      callback: (payload) => controller.add(payload.newRecord),
    );
    channel.subscribe();

    ref.onDispose(() {
      channel.unsubscribe();
      controller.close();
    });

    return controller.stream;
  });
}
