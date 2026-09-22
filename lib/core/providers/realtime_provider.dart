import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/utils/async_ops.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection lifecycle state of one realtime channel subscription
///
/// Exposed synchronously via [realtimeStatusProvider] so UI can render
/// "reconectando…" without conflating connection state with message data
/// (data flows through [realtimeChannelProvider]'s AsyncValue).
enum RealtimeStatus {
  /// Initial subscribe in flight.
  connecting,

  /// Channel joined; Postgres changes are being delivered.
  connected,

  /// A subscription error occurred; the provider is backing off before
  /// re-subscribing (exponential backoff, [backoffDelay]).
  reconnecting,

  /// Subscription failed and the retry budget is exhausted — the stream has
  /// ended; consumers may `ref.invalidate` to start a fresh subscription.
  error,

  /// Channel closed (socket closed or explicit unsubscribe).
  closed,
}

/// Backoff policy for realtime reconnects. Override
/// [realtimeRetryConfigProvider] in tests to use short, deterministic
/// windows (seeded [jitter]).
class RealtimeRetryConfig {
  const RealtimeRetryConfig({
    this.initialDelay = const Duration(seconds: 1),
    this.backoffFactor = 2,
    this.maxRetries = 3,
    this.jitter,
  });

  /// Base delay of the first retry ([backoffDelay] attempt 0).
  final Duration initialDelay;

  /// Exponential growth factor between attempts.
  final double backoffFactor;

  /// How many channel errors are tolerated before the stream ends.
  final int maxRetries;

  /// Injectable random source (deterministic when seeded — test seam).
  final Random? jitter;
}

final realtimeRetryConfigProvider = Provider<RealtimeRetryConfig>(
  (ref) => const RealtimeRetryConfig(),
);

/// Identity of one Postgres-changes subscription: the channel name, the
/// source table and the change event (the three coordinates every Samay
/// realtime stream is built from — chat inserts, event-status updates, QR
/// token updates, notifications).
typedef RealtimeChannelRequest = ({
  String channelName,
  String table,
  PostgresChangeEvent event,
});

class RealtimeStatusNotifier extends FamilyNotifier<RealtimeStatus, String> {
  @override
  RealtimeStatus build(String channelName) => RealtimeStatus.connecting;

  void set(RealtimeStatus status) => state = status;
}

/// Connection state of the channel [channelName], keyed by channel name so a
/// screen can watch "my channel's" state while [realtimeChannelProvider]
/// delivers the rows.
///
/// Keep-alive by design: a screen that re-enters can read the last known
/// state without re-watching the stream, and the stream provider updates it
/// lazily via `ref.read` (never during its own build — watching `.notifier`
/// from inside a provider build trips Riverpod's cycle assertion).
final realtimeStatusProvider = NotifierProvider.family<RealtimeStatusNotifier,
    RealtimeStatus, String>(RealtimeStatusNotifier.new);

/// Live Postgres-change rows for one subscription.
///
/// Family over [RealtimeChannelRequest] (channel name + table + event); the
/// canonical way for features to consume Supabase Realtime (chat, event
/// status, QR tokens, notifications — STAT spec "Realtime Providers").
///
///
/// - Subscribes through [RealtimeService.subscribeToChannel] (channel
///   creation stays in the service).
/// - Every `newRecord` of the postgres callback is emitted on the stream
///   (`AsyncData`).
/// - A `channelError`/`timedOut` status surfaces as an error event
///   (`AsyncError`, so consumers see the failure) and schedules a
///   re-subscribe with exponential backoff ([RealtimeRetryConfig] →
///   [backoffDelay] from `async_ops.dart`). Each retry uses a FRESH channel:
///   the realtime_client SDK forbids calling `subscribe` twice on one
///   channel instance.
/// - After [RealtimeRetryConfig.maxRetries] consecutive failures the stream
///   ends in `AsyncError` ([RealtimeStatus.error]); `ref.invalidate`
///   re-subscribes from scratch.
/// - Dispose safety: on dispose (no longer watched) the pending backoff
///   timer is cancelled, the channel is unsubscribed, and the controller is
///   closed — a late postgres delivery after dispose is a guarded no-op.
///
/// The status transitions are mirrored to [realtimeStatusProvider]
/// (connecting → connected → reconnecting → connected / error / closed).
final realtimeChannelProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>, RealtimeChannelRequest>(
  (ref, request) {
    final realtime = ref.watch(realtimeServiceProvider);
    final config = ref.watch(realtimeRetryConfigProvider);
    final controller = StreamController<Map<String, dynamic>>();
    final rng = config.jitter ?? Random();

    RealtimeChannel? channel;
    Timer? reconnectTimer;
    var attempt = 0;

    // Resolved lazily — the first touch happens in a status callback or
    // timer, never during this provider's build (watching `.notifier` from
    // inside a provider build trips Riverpod's cycle assertion).
    RealtimeStatusNotifier? statusNotifier;

    void setStatus(RealtimeStatus next) {
      if (controller.isClosed) return;
      final RealtimeStatusNotifier notifier = statusNotifier ??
          ref.read(realtimeStatusProvider(request.channelName).notifier);
      statusNotifier = notifier;
      notifier.set(next);
    }

    void teardownChannel() {
      final current = channel;
      channel = null;
      if (current != null) {
        unawaited(current.unsubscribe().then<void>((_) {},
            onError: (Object _, StackTrace _) {}));
      }
    }

    // Declared as `late` closures so [connect] and [onChannelError] can
    // reference each other (local function declarations do not hoist in Dart).
    late void Function() connect;
    late void Function(Object?) onChannelError;

    onChannelError = (Object? error) {
      if (controller.isClosed) return;
      controller.addError(
        error ?? Exception('realtime channel ${request.channelName} failed'),
      );
      if (attempt >= config.maxRetries) {
        setStatus(RealtimeStatus.error);
        teardownChannel();
        unawaited(controller.close());
        return;
      }
      setStatus(RealtimeStatus.reconnecting);
      final delay =
          backoffDelay(attempt, config.initialDelay, config.backoffFactor, rng);
      attempt++;
      reconnectTimer?.cancel();
      reconnectTimer = Timer(delay, () {
        if (controller.isClosed) return;
        teardownChannel();
        connect();
      });
    };

    connect = () {
      channel = realtime.subscribeToChannel(
        request.channelName,
        request.event,
        request.table,
        (row) {
          if (controller.isClosed) return;
          controller.add(row);
        },
        onStatus: (code, error) {
          switch (code) {
            case RealtimeSubscribeStatus.subscribed:
              attempt = 0;
              setStatus(RealtimeStatus.connected);
            case RealtimeSubscribeStatus.channelError:
            case RealtimeSubscribeStatus.timedOut:
              onChannelError(error);
            case RealtimeSubscribeStatus.closed:
              setStatus(RealtimeStatus.closed);
          }
        },
      );
    };

    connect();

    ref.onDispose(() {
      reconnectTimer?.cancel();
      teardownChannel();
      unawaited(controller.close());
    });

    return controller.stream;
  },
);
