import 'package:samay/l10n/app_localizations.dart';

sealed class AppError implements Exception {
  const AppError();

  String get message;

  /// Stable machine-readable code surfaced to the user alongside [message].
  String get code;

  /// The localized user-facing text for [l10n]. Subclasses map their message
  /// to `errors*` ARB keys; [message] remains the non-localized fallback.
  String localize(AppLocalizations l10n) => message;
}

class NetworkError extends AppError {
  final Object? original;
  NetworkError([this.original]);

  @override
  String get code => 'NETWORK_ERROR';

  @override
  String get message => 'Error de conexión. Verifica tu internet.';

  @override
  String localize(AppLocalizations l10n) => l10n.errorsNetwork;
}

class UnauthorizedError extends AppError {
  const UnauthorizedError();

  @override
  String get code => 'AUTH_UNAUTHORIZED';

  @override
  String get message => 'Sesión expirada. Inicia sesión de nuevo.';

  @override
  String localize(AppLocalizations l10n) => l10n.errorsUnauthorized;
}

class ServerError extends AppError {
  final String detail;
  final Object? original;
  const ServerError([this.detail = '', this.original]);

  @override
  String get code => 'SERVER_ERROR';

  @override
  String get message {
    if (detail.isNotEmpty) return detail;
    return 'Error del servidor. Intenta de nuevo.';
  }

  @override
  String localize(AppLocalizations l10n) =>
      detail.isNotEmpty ? detail : l10n.errorsServer;
}

class ValidationError extends AppError {
  final String field;
  final String issue;

  /// Optional ARB-backed override for the user-facing issue text.
  final String Function(AppLocalizations l10n)? localizer;

  ValidationError(this.field, this.issue, {this.localizer});

  @override
  String get code => 'VALIDATION_ERROR';

  @override
  String get message {
    if (field.isNotEmpty && issue.isNotEmpty) return issue;
    return 'Datos inválidos. Verifica los campos.';
  }

  @override
  String localize(AppLocalizations l10n) {
    final override = localizer;
    if (override != null) return override(l10n);
    if (issue.isNotEmpty) return issue;
    return l10n.errorsInvalidData;
  }
}

class PermissionError extends AppError {
  @override
  String get code => 'PERMISSION_DENIED';

  @override
  String get message => 'No tienes permiso para realizar esta acción.';

  @override
  String localize(AppLocalizations l10n) => l10n.errorsPermission;
}

class RateLimitError extends AppError {
  @override
  String get code => 'RATE_LIMITED';

  @override
  String get message => 'Demasiadas solicitudes. Espera un momento.';

  @override
  String localize(AppLocalizations l10n) => l10n.errorsRateLimit;
}

class NotFoundError extends AppError {
  final String resource;
  const NotFoundError([this.resource = '']);

  @override
  String get code => 'NOT_FOUND';

  @override
  String get message {
    if (resource.isNotEmpty) return '$resource no encontrado.';
    return 'No encontrado.';
  }

  @override
  String localize(AppLocalizations l10n) => resource.isNotEmpty
      ? l10n.errorsNotFound(resource)
      : l10n.errorsNotFoundGeneric;
}

/// Thrown when a business operation conflicts with existing state.
class ConflictError extends AppError {
  ConflictError(this.detail, {String? code})
      : _code = code ?? 'CONFLICT';

  final String detail;
  final String _code;

  @override
  String get code => _code;

  @override
  String get message => detail;

  @override
  String toString() => 'ConflictError($detail)';
}

/// Raised by purchase flows when RevenueCat is not configured (stub mode —
/// no RevenueCat public SDK key dart-define). Subclassed
/// here because [AppError] is sealed: all error types live in this library.
class NotConfiguredError extends AppError {
  NotConfiguredError();

  @override
  String get code => 'NOT_CONFIGURED';

  @override
  String get message => 'Los pagos aún no están disponibles.';
}

/// A user's public profile could not be resolved (missing row, soft-deleted,
/// or blocked). No-fallback: identity lists must surface this —
/// never render a placeholder name like "Usuario".
class ProfileResolutionError extends AppError {
  final String userId;

  ProfileResolutionError(this.userId);

  @override
  String get code => 'PROFILE_RESOLUTION';

  @override
  String get message => 'No se pudo cargar el perfil de un usuario.';

  @override
  String toString() => 'ProfileResolutionError($userId)';
}
