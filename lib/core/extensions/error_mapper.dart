import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/core/errors/app_error.dart';

extension ObjectX on Object {
  AppError toAppError() {
    if (this is AppError) return this as AppError;

    if (this is AuthException) {
      final authErr = this as AuthException;
      final code = authErr.code;
      // Code-first mapping per
      // https://supabase.com/docs/guides/auth/debugging/error-codes —
      // "always use error.code to identify errors, not string matching on
      // messages". The server `code` is authoritative when present.
      switch (code) {
        case 'over_request_rate_limit':
        case 'over_email_send_rate_limit':
        case 'over_sms_send_rate_limit':
          return RateLimitError();
        case 'invalid_credentials':
          return ValidationError('credenciales', 'Correo o contraseña inválidos');
        case 'email_not_confirmed':
          return ValidationError(
            'correo',
            'Correo no confirmado. Revisa tu bandeja de entrada.',
          );
        case 'email_address_invalid':
          return ValidationError('correo', 'Correo electrónico inválido.');
        case 'email_exists':
        case 'user_already_exists':
          return ValidationError(
            'correo',
            'Ya existe una cuenta con este correo.',
          );
        case 'weak_password':
          return ValidationError(
            'contraseña',
            'La contraseña no cumple los requisitos mínimos.',
          );
        case 'same_password':
          return ValidationError(
            'contraseña',
            'Debes elegir una contraseña diferente.',
          );
        case 'validation_failed':
          return ValidationError('datos', 'Datos inválidos. Verifica los campos.');
        case 'otp_expired':
          return ValidationError(
            'código',
            'El código ha expirado. Solicita uno nuevo.',
          );
        case 'otp_disabled':
          return ValidationError(
            'código',
            'El inicio de sesión con código está deshabilitado.',
          );
        case 'user_banned':
          return ValidationError('cuenta', 'Tu cuenta está suspendida.');
        case 'reauthentication_needed':
          return ValidationError(
            'sesión',
            'Vuelve a autenticarte para continuar.',
          );
        case 'request_timeout':
          return NetworkError();
        // Session/JWT lifecycle — the user must sign in again.
        case 'bad_jwt':
        case 'no_authorization':
        case 'not_admin':
        case 'session_expired':
        case 'session_not_found':
        case 'refresh_token_not_found':
        case 'refresh_token_already_used':
        case 'user_not_found':
          return const UnauthorizedError();
        case 'unexpected_failure':
          return ServerError(authErr.message);
        default:
          // No server code (client-side AuthException) or an unmapped code:
          // last-resort message heuristics, then the faithful server message.
          final msg = authErr.message.toLowerCase();
          if (msg.contains('jwt') ||
              msg.contains('token') ||
              msg.contains('session')) {
            return const UnauthorizedError();
          }
          return ServerError(authErr.message);
      }
    }

    if (this is PostgrestException) {
      final e = this as PostgrestException;
      final code = e.code ?? '';
      if (code == 'PGRST301') return const UnauthorizedError();
      if (code == '23503') {
        return ValidationError('data', 'Referencia inválida');
      }
      if (code == '23505') return ValidationError('data', 'Ya existe');
      if (code == '42501') return PermissionError();
      if (code == 'P0001') return ServerError(e.message);
      if (code.startsWith('28')) return NetworkError();
      if (code.startsWith('42')) return ServerError(e.message);
      return ServerError(e.message);
    }

    if (this is StorageException) {
      final e = this as StorageException;
      final status = e.statusCode;
      final error = e.error?.toLowerCase() ?? '';
      final msg = e.message.toLowerCase();

      // Auth failures: HTTP 401 or a JWT/token/session code or message.
      if (status == '401' ||
          error.contains('jwt') ||
          error.contains('token') ||
          error.contains('session') ||
          msg.contains('jwt') ||
          msg.contains('token') ||
          msg.contains('session')) {
        return const UnauthorizedError();
      }
      // Permission failures: HTTP 403, the Postgres RLS denial code (42501),
      // or the storage server's AccessDenied / InvalidKey codes.
      if (status == '403' ||
          status == '42501' ||
          error == 'accessdenied' ||
          error == 'invalidkey') {
        return PermissionError();
      }
      // Missing objects: HTTP 404 or the ObjectNotFound storage code.
      if (status == '404' || error == 'objectnotfound') {
        return const NotFoundError();
      }
      // Anything else keeps the storage message (already user-safe), never
      // the generic fallback.
      return ServerError(e.message);
    }

    if (this is FormatException) {
      return ValidationError('data', 'Formato inválido');
    }

    if (this is TimeoutException) {
      return NetworkError(this);
    }

    if (this is SocketException || this is HttpException) {
      return NetworkError(this);
    }

    if (this is String && (this as String).isNotEmpty) {
      return ServerError(this as String);
    }

    return ServerError('', this);
  }
}
