import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/app.dart';
import 'package:samay/core/config/env_config.dart';

String _explainError(String msg, String stack) {
  if (msg.contains('Cancelled')) return '';
  if (msg.contains('Bad state: Future already completed')) return '';
  return 'Unhandled error — check logs';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    final stack = details.stack?.toString() ?? '';
    final reason = _explainError(msg, stack);
    if (reason.isEmpty) return;
    debugPrint('[Samay] Flutter error: $msg | $reason\n$stack');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final msg = error.toString();
    final stackStr = stack.toString();
    final reason = _explainError(msg, stackStr);
    if (reason.isEmpty) return true;
    debugPrint('[Samay] Unhandled error: $msg | $reason\n$stackStr');
    return true;
  };

  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: SamayApp()));
}
