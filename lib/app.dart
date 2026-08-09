import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/theme/app_theme.dart';
import 'package:samay/core/router/app_router.dart';
import 'package:samay/l10n/app_localizations.dart';

class SamayApp extends ConsumerWidget {
  const SamayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Samay',
      theme: SamayTheme.dark,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
