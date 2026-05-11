import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vive_app/core/theme/app_theme.dart';
import 'package:vive_app/core/router/app_router.dart';

class ViveApp extends ConsumerWidget {
  const ViveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Vive!',
      theme: ViveTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
