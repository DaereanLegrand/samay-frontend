import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/qr/logic/swirl_code.dart';

/// The current user's swirl session for an event (Stage 4,
/// `get_my_swirl_code`, 060_events/07_swirl.sql), or a non-fatal state:
///
/// * [SwirlFetch.notInWindow] — before the activation window
///   (`qr.activation_minutes_before`, seed 30) or outside the event's live
///   span: the screen shows the pre-activation countdown and invalidates this
///   provider when the window opens.
/// * [SwirlFetch.notInvited] — the caller is neither host/staff nor an
///   invited attendee.
///
/// A server/infra failure surfaces as an AsyncError (retryable); the attendee
/// screen renders the retry state. The returned [SwirlSession] is the single
/// fetch the screen needs: it derives every later window locally from the
/// secret (authenticator style), so no per-window network round-trip happens
/// inside an event.
class MySwirlSessionNotifier extends FamilyAsyncNotifier<SwirlFetch, String> {
  @override
  Future<SwirlFetch> build(String eventId) async {
    final rpc = await ref.read(eventServiceProvider).getMySwirlCode(eventId);
    return SwirlFetch.fromRpc(rpc);
  }
}

/// The current user's swirl session for [eventId].
final mySwirlSessionProvider = AsyncNotifierProvider.family<
    MySwirlSessionNotifier, SwirlFetch, String>(MySwirlSessionNotifier.new);
