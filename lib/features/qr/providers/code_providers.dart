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
class MyCodeSessionNotifier extends FamilyAsyncNotifier<CodeFetch, String> {
  @override
  Future<CodeFetch> build(String eventId) async {
    final rpc = await ref.read(eventServiceProvider).getMyCode(eventId);
    return CodeFetch.fromRpc(rpc);
  }
}

/// The current user's code session for [eventId].
final myCodeProvider = AsyncNotifierProvider.family<
    MyCodeSessionNotifier, CodeFetch, String>(MyCodeSessionNotifier.new);
