import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content moderation: reports, appeals and reporter outcomes.
///
/// All writes go through the server RPCs added by 234_safety_moderation:
/// `report_content` validates the caller's relationship to the target and
/// captures the evidence snapshot at report time; `report_message` remains the
/// E2EE-specific path that discloses one decrypted row.
class ModerationService {
  ModerationService({required this.client});

  final SupabaseClient client;

  GoTrueClient get auth => client.auth;

  /// Server report categories (234_safety_moderation). `csam`,
  /// `credible_threat` and `ncii` are the immediate-response lanes.
  static const categories = <String>[
    'harassment',
    'hate',
    'spam',
    'impersonation',
    'ncii',
    'credible_threat',
    'csam',
    'other',
  ];

  static String categoryForReason(String reason) {
    switch (reason.trim().toLowerCase()) {
      case 'csam':
      case 'child_sexual_abuse':
        return 'csam';
      case 'credible_threat':
      case 'threat':
        return 'credible_threat';
      case 'ncii':
      case 'non_consensual_intimate':
        return 'ncii';
      case 'harassment':
      case 'abuse':
        return 'harassment';
      case 'hate':
      case 'hate_speech':
        return 'hate';
      case 'spam':
        return 'spam';
      case 'impersonation':
        return 'impersonation';
      default:
        return 'other';
    }
  }

  /// Reports any non-message UGC target. [targetType] is one of `user`,
  /// `avatar`, `photo`, `event`, `event_description`, `group_cover`,
  /// `minigame_answer`, `minigame_image`.
  Future<void> reportContent(
    String targetType,
    String targetId,
    String reason, {
    String? category,
  }) {
    return report(
      targetType: targetType,
      targetId: targetId,
      category: category ?? categoryForReason(reason),
      reason: reason,
    );
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String category,
    String? reason,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(
      'report_content',
      params: {
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_category': category,
        'p_reason': reason,
      },
    );
    final status = res is Map ? res['status'] : null;
    if (status == 'ok') return;
    switch (status) {
      case 'not_allowed':
        throw PermissionError();
      case 'target_not_found':
      case 'message_not_found':
        throw const NotFoundError('Contenido');
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'invalid_target_type':
      case 'invalid_category':
        throw ValidationError('report', 'Reporte inválido');
      default:
        throw const ServerError();
    }
  }

  /// Reports ONE chat message through `report_message` (226_chat_moderation).
  ///
  /// The chat is end-to-end encrypted, so the server cannot read the reported
  /// row on its own: the caller passes the row's DECRYPTED [plaintext] so the
  /// moderator queue can actually see it (any media URL is read server-side
  /// from the message row). Only the row the user chose to report is disclosed
  /// — the reporting exception to E2EE.
  Future<void> reportMessage(
    String messageId,
    String reason, {
    String? plaintext,
    String? category,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(
      'report_message',
      params: {
        'p_message_id': messageId,
        'p_reason': category ?? reason,
        'p_plaintext': plaintext,
      },
    );
    final status = res is Map ? res['status'] : null;
    if (status == 'ok') return;
    switch (status) {
      case 'message_not_found':
        throw const NotFoundError('Mensaje');
      case 'not_allowed':
        throw PermissionError();
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError();
    }
  }

  /// Submits an appeal. A banned user may pass a null [reportId] for a ban
  /// appeal; otherwise the report must involve the caller as reporter or
  /// target (validated server-side).
  Future<void> submitAppeal({String? reportId, required String message}) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(
      'submit_appeal',
      params: {'p_report_id': reportId, 'p_message': message},
    );
    final status = res is Map ? res['status'] : null;
    if (status == 'ok') return;
    switch (status) {
      case 'invalid_message':
        throw ValidationError(
          'message',
          'Escribe al menos 10 caracteres.',
        );
      case 'report_required':
        throw ValidationError(
          'report',
          'Selecciona un reporte para apelar.',
        );
      case 'already_open':
        throw ConflictError('Ya tienes una apelación abierta.');
      case 'not_allowed':
        throw PermissionError();
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError();
    }
  }

  Future<List<Map<String, dynamic>>> myAppeals() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('my_appeals');
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> myReportOutcomes() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('my_report_outcomes');
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
