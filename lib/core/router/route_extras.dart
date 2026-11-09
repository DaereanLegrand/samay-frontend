import 'dart:convert';

import 'package:go_router/go_router.dart';

/// Typed, validated navigation extras for parameterized routes.
///
/// The auth-flow routes read their payload through one of these classes so the
/// router never performs unsafe casts on `state.extra`.
/// Factories return `null` on missing/invalid data instead of throwing; callers
/// render a safe fallback (see `RouteErrorScreen`).
///
/// Value equality: the classes implement `==`/`hashCode` on their fields so a
/// go_router configuration re-parsed from the engine state (which carries the
/// extras through [RouteExtraCodec]) compares equal to the current one — the
/// delegate's `setNewRoutePath` early-returns and the pushed screens keep
/// their state.
sealed class RouteExtra {
  const RouteExtra();
}

String? _stringField(Object? extra, String key) {
  if (extra is Map) {
    final value = extra[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

/// Payload for [RoutePaths.verify] — the email and password collected by the
/// signup form, carried into the OTP verification step.
class VerifyExtra extends RouteExtra {
  final String email;
  final String password;

  const VerifyExtra({required this.email, required this.password});

  /// Returns the extra when [state.extra] is a [VerifyExtra] or a raw map
  /// with non-empty `email`/`password`; otherwise `null`.
  static VerifyExtra? fromState(GoRouterState state) => fromObject(state.extra);

  static VerifyExtra? fromObject(Object? extra) {
    if (extra is VerifyExtra) return extra;
    final email = _stringField(extra, 'email');
    final password = _stringField(extra, 'password');
    if (email == null || password == null) return null;
    return VerifyExtra(email: email, password: password);
  }

  @override
  bool operator ==(Object other) =>
      other is VerifyExtra &&
      other.email == email &&
      other.password == password;

  @override
  int get hashCode => Object.hash(email, password);
}

/// Payload for [RoutePaths.privacyTerms] — email and date of birth carried
/// from the age-gate step.
class PrivacyTermsExtra extends RouteExtra {
  final String email;
  final String dateOfBirth;

  const PrivacyTermsExtra({required this.email, required this.dateOfBirth});

  /// Returns the extra when [state.extra] is a [PrivacyTermsExtra] or a raw
  /// map with non-empty `email`/`dateOfBirth`; otherwise `null`.
  static PrivacyTermsExtra? fromState(GoRouterState state) =>
      fromObject(state.extra);

  static PrivacyTermsExtra? fromObject(Object? extra) {
    if (extra is PrivacyTermsExtra) return extra;
    final email = _stringField(extra, 'email');
    final dateOfBirth = _stringField(extra, 'dateOfBirth');
    if (email == null || dateOfBirth == null) return null;
    return PrivacyTermsExtra(email: email, dateOfBirth: dateOfBirth);
  }

  @override
  bool operator ==(Object other) =>
      other is PrivacyTermsExtra &&
      other.email == email &&
      other.dateOfBirth == dateOfBirth;

  @override
  int get hashCode => Object.hash(email, dateOfBirth);
}

/// Payload for [RoutePaths.profileSetup] — email and date of birth carried
/// from the privacy/terms step.
class ProfileSetupExtra extends RouteExtra {
  final String email;
  final String dateOfBirth;

  const ProfileSetupExtra({required this.email, required this.dateOfBirth});

  /// Returns the extra when [state.extra] is a [ProfileSetupExtra] or a raw
  /// map with non-empty `email`/`dateOfBirth`; otherwise `null`.
  static ProfileSetupExtra? fromState(GoRouterState state) =>
      fromObject(state.extra);

  static ProfileSetupExtra? fromObject(Object? extra) {
    if (extra is ProfileSetupExtra) return extra;
    final email = _stringField(extra, 'email');
    final dateOfBirth = _stringField(extra, 'dateOfBirth');
    if (email == null || dateOfBirth == null) return null;
    return ProfileSetupExtra(email: email, dateOfBirth: dateOfBirth);
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileSetupExtra &&
      other.email == email &&
      other.dateOfBirth == dateOfBirth;

  @override
  int get hashCode => Object.hash(email, dateOfBirth);
}

/// Payload for [RoutePaths.ageGate] — the signup email. The age-gate screen
/// falls back to the signed-in user's email when this is absent, so a missing
/// extra is tolerated (never crashes).
class AgeGateExtra extends RouteExtra {
  final String email;

  const AgeGateExtra({required this.email});

  /// Returns the extra when [state.extra] is an [AgeGateExtra], a raw
  /// String email, or a map with a non-empty `email` field; otherwise `null`.
  static AgeGateExtra? fromState(GoRouterState state) => fromObject(state.extra);

  static AgeGateExtra? fromObject(Object? extra) {
    if (extra is AgeGateExtra) return extra;
    if (extra is String && extra.isNotEmpty) return AgeGateExtra(email: extra);
    final email = _stringField(extra, 'email');
    if (email == null) return null;
    return AgeGateExtra(email: email);
  }

  @override
  bool operator ==(Object other) =>
      other is AgeGateExtra && other.email == email;

  @override
  int get hashCode => email.hashCode;
}

/// GoRouter's `extraCodec` — round-trips the typed [RouteExtra]s through the
/// engine's route-information state.
///
/// go_router serializes pushed-page extras into the engine state on every
/// route report and RE-PARSES that state on every `refresh()` — the auth
/// guard's `refreshListenable` fires on every auth-state emission. WITHOUT a
/// codec, a non-JSON extra (any typed [RouteExtra]) is encoded as `null`, so
/// the re-parse rebuilds pushed routes with a null extra → `RouteErrorScreen`
/// ("Faltan los datos del registro") — the OTP screen flipped to the error
/// screen the moment `verifyOtp` emitted its `AsyncLoading` state.
///
/// With the codec AND the extras' value equality, the re-parsed configuration
/// equals the current one and go_router's `setNewRoutePath` early-returns: no
/// rebuild, the pushed screens keep their state (counter, consents, form).
/// JSON-able extras (null, plain maps, primitive values) pass
/// through untouched.
class RouteExtraCodec extends Codec<Object?, Object?> {
  const RouteExtraCodec();

  @override
  Converter<Object?, Object?> get encoder => const _RouteExtraEncoder();

  @override
  Converter<Object?, Object?> get decoder => const _RouteExtraDecoder();
}

class _RouteExtraEncoder extends Converter<Object?, Object?> {
  const _RouteExtraEncoder();

  @override
  Object? convert(Object? extra) {
    return switch (extra) {
      VerifyExtra(:final email, :final password) =>
        {'type': 'verify', 'email': email, 'password': password},
      AgeGateExtra(:final email) => {'type': 'ageGate', 'email': email},
      PrivacyTermsExtra(:final email, :final dateOfBirth) =>
        {'type': 'privacyTerms', 'email': email, 'dateOfBirth': dateOfBirth},
      ProfileSetupExtra(:final email, :final dateOfBirth) =>
        {'type': 'profileSetup', 'email': email, 'dateOfBirth': dateOfBirth},
      _ => extra,
    };
  }
}

class _RouteExtraDecoder extends Converter<Object?, Object?> {
  const _RouteExtraDecoder();

  @override
  Object? convert(Object? encoded) {
    if (encoded is! Map) return encoded;
    // The typed classes parse their own raw-map form; the `type` marker
    // picks the class. Unmarked maps pass through untouched.
    return switch (encoded['type']) {
      'verify' => VerifyExtra.fromObject(encoded),
      'ageGate' => AgeGateExtra.fromObject(encoded),
      'privacyTerms' => PrivacyTermsExtra.fromObject(encoded),
      'profileSetup' => ProfileSetupExtra.fromObject(encoded),
      _ => encoded,
    };
  }
}

/// Null-safe path-parameter access.
///
/// Returns `null` instead of throwing when the parameter is missing, so
/// malformed deep links render a fallback screen instead of crashing.
abstract final class RouteParams {
  static String? fromState(GoRouterState state, String name) =>
      fromMap(state.pathParameters, name);

  static String? fromMap(Map<String, String> parameters, String name) =>
      parameters[name];
}
