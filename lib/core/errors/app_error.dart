sealed class AppError {
  String get message;
}

class NetworkError extends AppError {
  final Object? original;
  NetworkError([this.original]);

  @override
  String get message => 'Error de conexión. Verifica tu internet.';
}

class UnauthorizedError extends AppError {
  @override
  String get message => 'Sesión expirada. Inicia sesión de nuevo.';
}

class ServerError extends AppError {
  final String detail;
  ServerError([this.detail = '']);

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
  String get message {
    if (field.isNotEmpty && issue.isNotEmpty) return issue;
    return 'Datos inválidos. Verifica los campos.';
  }
}

class PermissionError extends AppError {
  @override
  String get message => 'No tienes permiso para realizar esta acción.';
}

class RateLimitError extends AppError {
  @override
  String get message => 'Demasiadas solicitudes. Espera un momento.';
}

class NotFoundError extends AppError {
  final String resource;
  NotFoundError([this.resource = '']);

  @override
  String get message {
    if (resource.isNotEmpty) return '$resource no encontrado.';
    return 'No encontrado.';
  }
}
