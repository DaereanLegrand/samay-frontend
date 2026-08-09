/// Repository layer (I-50): thin, typed facades over the I-11 services.
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase
/// client. Feature providers read these via `lib/core/repositories/
/// repository_providers.dart` — never the legacy `SupabaseService.instance`
/// singleton (which is now unreachable from `lib/features/`).
///
/// The chat repository is intentionally not exposed here: the chat feature
/// is the only message consumer and always goes E2EE, so its provider lives
/// feature-scoped (`chatE2eeRepositoryProvider` in
/// `lib/features/chat/chat_providers.dart`) — see `chat_repository.dart`.
library;

export 'chat_repository.dart';
export 'friends_repository.dart';
export 'groups_repository.dart';
export 'profile_repository.dart';
