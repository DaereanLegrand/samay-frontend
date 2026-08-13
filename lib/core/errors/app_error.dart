sealed class AppError {
  String get message;

  /// Stable machine-readable code surfaced to the user alongside [message].
  String get code;
}

class NetworkError extends AppError {
  final Object? original;
  NetworkError([this.original]);

  @override
  String get code => 'NETWORK_ERROR';

  @override
  String get message => 'Error de conexión. Verifica tu internet.';
}

class UnauthorizedError extends AppError {
  @override
  String get code => 'AUTH_UNAUTHORIZED';

  @override
  String get message => 'Sesión expirada. Inicia sesión de nuevo.';
}

class ServerError extends AppError {
  final String detail;
  final Object? original;
  ServerError([this.detail = '', this.original]);

  @override
  String get code => 'SERVER_ERROR';

  @override
  String get message {
    if (detail.isNotEmpty) return detail;
    return 'Error del servidor. Intenta de nuevo.';
  }
}

class ValidationError extends AppError {
  final String field;
  final String issue;
  ValidationError(this.field, this.issue);

  @override
  String get code => 'VALIDATION_ERROR';

  @override
  String get message {
    if (field.isNotEmpty && issue.isNotEmpty) return issue;
    return 'Datos inválidos. Verifica los campos.';
  }
}

class PermissionError extends AppError {
  @override
  String get code => 'PERMISSION_DENIED';

  @override
  String get message => 'No tienes permiso para realizar esta acción.';
}

class RateLimitError extends AppError {
  @override
  String get code => 'RATE_LIMITED';

  @override
  String get message => 'Demasiadas solicitudes. Espera un momento.';
}

class NotFoundError extends AppError {
  final String resource;
  NotFoundError([this.resource = '']);

  @override
  String get code => 'NOT_FOUND';

  @override
  String get message {
    if (resource.isNotEmpty) return '$resource no encontrado.';
    return 'No encontrado.';
  }
}

/// Raised by purchase flows when RevenueCat is not configured (stub mode —
/// no `REVENUECAT_PUBLIC_SDK_KEY` dart-define, I-61 foundation). Subclassed
/// here because [AppError] is sealed: all error types live in this library.
class NotConfiguredError extends AppError {
  NotConfiguredError();

  @override
  String get code => 'NOT_CONFIGURED';

  @override
  String get message => 'Los pagos aún no están disponibles.';
}
