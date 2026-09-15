import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:samay/core/errors/app_error.dart';

/// Whether [error] represents a transient, non-user-facing failure that is
/// safe (and useful) to retry.
///
/// Retries: [SocketException], [HttpException], [TimeoutException],
/// [AuthRetryableFetchException] (gotrue's canonical "retry me" signal for
/// network failures and >=500 responses), [AppError.NetworkError],
/// [PostgrestException] with a connection-class SQLSTATE code (`28*` —
/// consistent with `error_mapper.dart`), and transient [StorageException]s
/// (status >= 500, or a `timeout` in the error code/message).
///
/// StorageException rules: 400/401/403/404 and the permanent
/// `ObjectNotFound` / `AccessDenied` / `InvalidKey` codes are never retried;
/// a >=500 status or a `timeout` code/message is retried; anything else is
/// treated as permanent.
///
/// Never retries: user-facing or permanent failures such as
/// [ValidationError], [NotFoundError], [PermissionError], [UnauthorizedError]
/// and [RateLimitError] (retrying amplifies abuse).
bool defaultShouldRetry(Object error) {
  if (error is AppError) {
    return error is NetworkError;
  }
  if (error is SocketException || error is HttpException) return true;
  if (error is TimeoutException) return true;
  if (error is AuthRetryableFetchException) return true;
  if (error is StorageException) {
    final status = int.tryParse(error.statusCode ?? '');
    final code = error.error?.toLowerCase() ?? '';
    // Permanent client/permission/missing-object failures.
    if (status == 400 || status == 401 || status == 403 || status == 404) {
      return false;
    }
    const permanent = {'objectnotfound', 'accessdenied', 'invalidkey'};
    if (permanent.contains(code)) return false;
    // Transient server / timeout failures.
    if (status != null && status >= 500) return true;
    final message = error.message.toLowerCase();
    if (code.contains('timeout') || message.contains('timeout')) return true;
    return false;
  }
  if (error is PostgrestException) {
    // SQLSTATE class 28 (connection) — the same set error_mapper.dart maps
    // to NetworkError. Permanent PostgREST errors (23505, 42501, PGRST301…)
    // fall through and are NOT retried.
    final code = error.code ?? '';
    return code.startsWith('28');
  }
  return false;
}

/// Delay before retry attempt [attempt] (1-based): capped exponential backoff
/// with full jitter — `sleep = random(0, min(cap, initialDelay * factor^attempt))`
/// (AWS "Exponential Backoff And Jitter").
///
/// [attempt] is the number of retries already consumed (0 = before the first
/// retry). Passing a seeded [Random] makes the delay deterministic for tests.
Duration backoffDelay(
  int attempt,
  Duration initialDelay,
  double backoffFactor,
  Random rng,
) {
  final capMs =
      (initialDelay.inMilliseconds * pow(backoffFactor, attempt)).ceil();
  return Duration(milliseconds: rng.nextInt(capMs + 1));
}

/// Runs [fn], retrying on transient failures only.
///
/// On failure: if [shouldRetry] says no (or the default predicate refuses),
/// the original error is rethrown immediately. Otherwise the attempt is
/// retried up to [maxRetries] extra times, waiting a jittered exponential
/// backoff ([initialDelay] * [backoffFactor]^attempt) between attempts.
/// After [maxRetries] retries the last error is rethrown unchanged.
///
/// [fn] is invoked lazily for each attempt, so a fresh operation runs on
/// every retry.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
  double backoffFactor = 2,
  Random? jitter,
  bool Function(Object error)? shouldRetry,
}) async {
  final canRetry = shouldRetry ?? defaultShouldRetry;
  final rng = jitter ?? Random();
  var attempt = 0;
  while (true) {
    try {
      return await fn();
    } catch (error) {
      if (attempt >= maxRetries || !canRetry(error)) rethrow;
      await Future<void>.delayed(
        backoffDelay(attempt, initialDelay, backoffFactor, rng),
      );
      attempt++;
    }
  }
}

/// Runs [fn] and stops waiting after [timeout], throwing a [TimeoutException]
/// with a clean, user-diagnosable message.
///
/// The underlying future is not cancelled (standard `Future.timeout`
/// semantics — see the Dart docs); a late completion is simply ignored.
Future<T> withTimeout<T>(
  Future<T> Function() fn, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  try {
    return await fn().timeout(timeout);
  } on TimeoutException {
    throw TimeoutException(
      'Operation timed out after ${timeout.inSeconds}s',
      timeout,
    );
  }
}

/// Composes [withRetry] and [withTimeout]: [fn] is invoked with a per-attempt
/// timeout, and transient failures (including timeouts) are retried with
/// jittered exponential backoff. A hung request can therefore consume at most
/// one attempt's [timeout], never the whole retry budget.
///
/// This is the recommended wrapper for network operations that must never
/// hang the UI and should survive transient outages.
Future<T> resilient<T>(
  Future<T> Function() fn, {
  Duration timeout = const Duration(seconds: 10),
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
  double backoffFactor = 2,
  Random? jitter,
  bool Function(Object error)? shouldRetry,
}) {
  return withRetry(
    () => withTimeout(fn, timeout: timeout),
    maxRetries: maxRetries,
    initialDelay: initialDelay,
    backoffFactor: backoffFactor,
    jitter: jitter,
    shouldRetry: shouldRetry,
  );
}
