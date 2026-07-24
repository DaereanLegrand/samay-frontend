import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/core/errors/app_error.dart';

extension ObjectX on Object {
  AppError toAppError() {
    if (this is AppError) return this as AppError;

    if (this is AuthException) {
      final authErr = this as AuthException;
      final code = authErr.code;
      final msg = authErr.message.toLowerCase();

      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          code == 'over_sms_send_rate_limit') {
        return RateLimitError();
      }
      if (code == 'invalid_credentials') {
        return ValidationError('credenciales', 'Correo o contraseña inválidos');
      }
      if (code == 'otp_expired') {
        return ValidationError('código', 'El código ha expirado. Solicita uno nuevo.');
      }
      if (msg.contains('jwt') || msg.contains('token') || msg.contains('session')) {
        return UnauthorizedError();
      }
      return UnauthorizedError();
    }

    if (this is PostgrestException) {
      final e = this as PostgrestException;
      final code = e.code ?? '';
      if (code == 'PGRST301') return UnauthorizedError();
      if (code == '23503') return ValidationError('data', 'Referencia inválida');
      if (code == '23505') return ValidationError('data', 'Ya existe');
      if (code == '42501') return PermissionError();
      if (code == 'P0001') return ServerError(e.message);
      if (code.startsWith('28')) return NetworkError();
      if (code.startsWith('42')) return ServerError(e.message);
      return ServerError(e.message);
    }

    if (this is FormatException) {
      return ValidationError('data', 'Formato inválido');
    }

    if (this is SocketException || this is HttpException) {
      return NetworkError(this);
    }

    return ServerError(toString());
  }
}
