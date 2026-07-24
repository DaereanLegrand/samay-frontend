import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/theme/app_theme.dart';
import 'package:samay/core/router/app_router.dart';

class SamayApp extends ConsumerWidget {
  const SamayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Samay',
      theme: SamayTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
