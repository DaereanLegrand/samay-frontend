library;
import 'package:samay/crypto/codec.dart';
import 'package:samay/crypto/constants.dart';
import 'package:samay/crypto/interfaces.dart';
import 'package:samay/crypto/x3dh.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase-backed prekey service (E2EE-ARCHITECTURE.md §9.3, migration
/// 20260809000003): publishes identity + signed prekey + one-time prekeys to
/// the per-user `e2ee_identity_keys` row and fetches peer bundles through the
/// `fetch_prekey_bundle` SECURITY DEFINER RPC (which consumes one one-time
/// prekey atomically server-side).
///
/// Only **public** key material ever reaches the server — private keys stay
/// in the [E2eeKeyStore] on the device (§9.2). One-time prekeys are topped
/// up to [e2eeOneTimePrekeyBatchSize] (100) on every publish; the signed
/// prekey auto-rotates after 7 days (§5.2) via the store.
class SupabaseE2eePrekeyService implements E2eePrekeyService {
  SupabaseE2eePrekeyService({
    required SupabaseClient client,
    required E2eeKeyStore keyStore,
    DateTime Function()? clock,
  }) : _client = client,
       _keyStore = keyStore,
       _clock = clock ?? DateTime.now;

  final SupabaseClient _client;
  final E2eeKeyStore _keyStore;
  final DateTime Function() _clock;

  GoTrueClient get auth => _client.auth;

  static const String tableName = 'e2ee_identity_keys';

  @override
  Future<PrekeyBundle?> fetchBundle(String peerUserId) async {
    final res = await _client.rpc(
      'fetch_prekey_bundle',
      params: {'p_user_id': peerUserId},
    );
    if (res is! Map) return null; // NULL when the peer has no published keys
    final row = Map<String, dynamic>.from(res);
    if (row['identity_key'] is! String) return null;
    return _bundleFromRow(row);
  }

  @override
  Future<void> publishAll() => publishIdentityBundle();

  /// Publishes (or refreshes) the full bundle: identity keys, the current
  /// signed prekey (auto-rotating when older than 7 days, §5.2) and a
  /// one-time-prekey top-up back to the 100-batch size (§5.1).
  Future<void> publishIdentityBundle() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final existing = await _fetchOwnRow();
    final identity = await _keyStore.loadOrCreateIdentity();
    final spk = await _keyStore.currentSignedPrekey();

    final opks = _opkListFromRow(existing);
    final topUp = e2eeOneTimePrekeyBatchSize - opks.length;
    if (topUp > 0) {
      final fresh = await _keyStore.generateOneTimePrekeys(topUp);
      opks.addAll(
        fresh.map(
          (r) => {'id': r.id, 'key': base64UrlNoPadEncode(r.keyPair.publicKey)},
        ),
      );
    }

    await _client.from(tableName).upsert(
      {
        'user_id': user.id,
        'identity_key': base64UrlNoPadEncode(identity.ikDhPublic),
        'identity_sig_key': base64UrlNoPadEncode(identity.ikSigPublic),
        'signed_prekey_id': spk.id,
        'signed_prekey': base64UrlNoPadEncode(spk.keyPair.publicKey),
        'signed_prekey_sig': base64UrlNoPadEncode(spk.signature),
        'signed_prekey_expires_at': _spkExpiry(existing, spk),
        'one_time_prekeys': opks,
      },
      onConflict: 'user_id',
    );
  }

  /// Forces a signed-prekey rotation (§5.2) and republishes the bundle.
  Future<void> rotateSignedPrekey() async {
    await _keyStore.rotateSignedPrekey();
    await publishIdentityBundle();
  }

  /// Lazy first-send bootstrap (§12.2 step 2): ensures the local bundle is
  /// published before initiating a session with a peer. Idempotent — when
  /// the own row already exists nothing is rewritten.
  Future<void> handleMissingSession() async {
    final existing = await _fetchOwnRow();
    if (existing == null) {
      await publishIdentityBundle();
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _fetchOwnRow() async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await _client.from(tableName).select().eq('user_id', user.id);
    final rows = res.whereType<Map>().toList();
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  List<Map<String, dynamic>> _opkListFromRow(Map<String, dynamic>? row) {
    final raw = row?['one_time_prekeys'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Keeps the existing SPK expiry when the prekey did not change; a fresh
  /// (or first) prekey gets now + 7 days (§5.2).
  String _spkExpiry(Map<String, dynamic>? existing, SignedPrekeyRecord spk) {
    final same =
        existing?['signed_prekey'] ==
            base64UrlNoPadEncode(spk.keyPair.publicKey);
    if (same && existing?['signed_prekey_expires_at'] is String) {
      return existing!['signed_prekey_expires_at'] as String;
    }
    return _clock().add(e2eeSignedPrekeyRotationAge).toUtc().toIso8601String();
  }

  PrekeyBundle _bundleFromRow(Map<String, dynamic> row) {
    final opk = row['one_time_prekey'];
    final opkMap = opk is Map ? Map<String, dynamic>.from(opk) : null;
    return PrekeyBundle(
      identityKey: base64UrlNoPadDecode(row['identity_key'] as String)!,
      identitySigKey: base64UrlNoPadDecode(row['identity_sig_key'] as String)!,
      signedPrekeyId: row['signed_prekey_id'] as int,
      signedPrekey: base64UrlNoPadDecode(row['signed_prekey'] as String)!,
      signature: base64UrlNoPadDecode(row['signed_prekey_sig'] as String)!,
      oneTimePrekeyId: opkMap?['id'] as int?,
      oneTimePrekey:
          opkMap == null ? null : base64UrlNoPadDecode(opkMap['key'] as String),
    );
  }
}
