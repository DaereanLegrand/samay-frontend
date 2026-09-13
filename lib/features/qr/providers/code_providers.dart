import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/qr/logic/code.dart';

/// The current user's code session for an event (Stage 5, `get_my_code`,
/// 07_code.sql), or a non-fatal state:
///
/// * [CodeFetch.notInWindow] — before the activation window
///   (`qr.activation_minutes_before`, seed 30) or outside the event's live
///   span: the screen shows the pre-activation countdown and invalidates this
///   provider when the window opens.
/// * [CodeFetch.notInvited] — the caller is neither host/staff nor an
///   invited attendee.
///
/// A server/infra failure surfaces as an AsyncError (retryable); the attendee
/// screen renders the retry state. The returned [CodeSession] is the single
/// fetch the screen needs: it derives every later window locally from the
/// secret (authenticator style), so no per-window network round-trip happens
/// inside an event.
///
/// The fetch also measures the device wall clock around the RPC and stores
/// `serverNowMs - deviceMidpoint` on the [CodeFetch], so the screen can rotate
/// on the SERVER's lattice even when the device clock is skewed (the elapsed
/// half-round-trip is the only error). `autoDispose` so a fresh entry always
/// re-anchors on the server's current time.
class MyCodeSessionNotifier
    extends AutoDisposeFamilyAsyncNotifier<CodeFetch, String> {
  @override
  Future<CodeFetch> build(String eventId) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    final rpc = await ref.read(eventServiceProvider).getMyCode(eventId);
    final t1 = DateTime.now().millisecondsSinceEpoch;
    if (rpc == null || rpc['status'] != 'ok') {
      return CodeFetch.fromRpc(rpc, 0);
    }
    final session = CodeSession.fromJson(rpc);
    final offsetMs = session.serverNowMs - ((t0 + t1) ~/ 2);
    return CodeFetch.ok(session, offsetMs);
  }
}

/// The current user's code session for [eventId].
final myCodeProvider = AsyncNotifierProvider.autoDispose
    .family<MyCodeSessionNotifier, CodeFetch, String>(
  MyCodeSessionNotifier.new,
);
