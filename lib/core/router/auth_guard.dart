import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/providers/auth_provider.dart';

class AuthGuard {
  final Ref ref;

  AuthGuard(this.ref);

  FutureOr<String?> call(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final location = state.matchedLocation;

    final isPublicRoute = location == '/' ||
        location == '/login' ||
        location.startsWith('/auth/');

    if (!auth.authenticated) {
      return isPublicRoute ? null : '/login';
    }

    if (location == '/login' || location == '/') {
      return '/main/feed';
    }

    return null;
  }
}
