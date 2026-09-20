// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Samay';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get commonReject => 'Rechazar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonEmail => 'Correo electrónico';

  @override
  String get commonPassword => 'Contraseña';

  @override
  String get commonConfirmPassword => 'Confirmar contraseña';

  @override
  String get commonUsername => 'Nombre de usuario';

  @override
  String get commonUser => 'Usuario';

  @override
  String get commonGroup => 'Grupo';

  @override
  String get commonFriends => 'Amigos';

  @override
  String get commonCreateAccount => 'Crear cuenta';

  @override
  String get commonSignIn => 'Iniciar sesión';

  @override
  String get commonError => 'Error';

  @override
  String get commonInvite => 'Invitar';

  @override
  String get commonMoreOptions => 'Más opciones';

  @override
  String get welcomeVive => 'vive';

  @override
  String get welcomeTagline => 'Tu vida social, en un solo lugar';

  @override
  String get authVerifyAge => 'Verificar edad';

  @override
  String get authBirthDateQuestion => '¿Cuál es tu fecha de nacimiento?';

  @override
  String get authMinAgeMessage =>
      'Debes tener al menos 18 años para usar Samay';

  @override
  String get authSelectDate => 'Seleccionar fecha';

  @override
  String get authUnderageMessage => 'Debes tener 18 años para usar Samay';

  @override
  String authSelectedDate(int day, int month, int year) {
    return '$day/$month/$year';
  }

  @override
  String get authForgotPassword => 'Olvidé mi contraseña';

  @override
  String get authUnknownLoginError => 'Error desconocido al iniciar sesión';

  @override
  String get authVerifyCode => 'Verificar código';

  @override
  String get authEnterVerificationCode => 'Ingresa el código de verificación';

  @override
  String authOtpSentTo(String email) {
    return 'Enviamos un código de 6 dígitos a $email';
  }

  @override
  String get authVerify => 'Verificar';

  @override
  String get authResendCode => 'Reenviar código';

  @override
  String authResendCodeIn(int seconds) {
    return 'Reenviar código (${seconds}s)';
  }

  @override
  String get authOtpTooManyAttempts =>
      'Demasiados intentos fallidos. Solicita un nuevo código.';

  @override
  String get authEmailAlreadyRegistered => 'Correo ya registrado';

  @override
  String get authEmailAlreadyRegisteredBody =>
      'Este correo ya tiene una cuenta completa. Inicia sesión en su lugar.';

  @override
  String get authBackToLogin => 'Volver a iniciar sesión';

  @override
  String authOtpAttemptsRemaining(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: 'Te quedan $attempts intentos',
      one: 'Te queda 1 intento',
    );
    return '$_temp0';
  }

  @override
  String get authForgotPasswordTitle => 'Recuperar contraseña';

  @override
  String get authForgotPasswordHeading => '¿Olvidaste tu contraseña?';

  @override
  String get authForgotPasswordHint =>
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.';

  @override
  String get authForgotPasswordSend => 'Enviar enlace';

  @override
  String get authForgotPasswordSuccessTitle => 'Revisa tu correo';

  @override
  String authForgotPasswordSuccessBody(String email) {
    return 'Si existe una cuenta con $email, recibirás un enlace para restablecer tu contraseña.';
  }

  @override
  String get authForgotPasswordSnack =>
      'Te enviamos un enlace para restablecer tu contraseña';

  @override
  String get authTermsTitle => 'Términos y condiciones';

  @override
  String get authAcceptTermsToContinue => 'Acepta los términos para continuar';

  @override
  String get authPrivacyPolicy => 'Acepto la Política de Privacidad';

  @override
  String get authPrivacyPolicySubtitle =>
      'Conoce cómo manejamos tus datos personales';

  @override
  String get authServiceTerms => 'Acepto los Términos de Servicio';

  @override
  String get authServiceTermsSubtitle => 'Condiciones de uso de la aplicación';

  @override
  String get authCompleteProfile => 'Completa tu perfil';

  @override
  String get authUsernameHint => '@usuario';

  @override
  String get authUsernameImmutable =>
      'No podrás cambiar tu nombre de usuario después del registro.';

  @override
  String get authCreateYourAccount => 'Crea tu cuenta';

  @override
  String get authSignupSubtitle => 'Ingresa tu correo y crea una contraseña';

  @override
  String get authPasswordWithRequirements =>
      'Contraseña (mín. 8 caracteres, 1 número)';

  @override
  String get authPasswordTooWeak =>
      'La contraseña debe tener al menos 8 caracteres y contener un número.';

  @override
  String get authPasswordsDontMatch => 'Las contraseñas no coinciden.';

  @override
  String get bannedTitle => 'Cuenta suspendida';

  @override
  String get bannedDefaultBody => 'Tu cuenta ha sido suspendida.';

  @override
  String bannedReasonLabel(String reason) {
    return 'Motivo: $reason';
  }

  @override
  String get feedBrand => 'samay';

  @override
  String get feedFeatured => 'Destacados';

  @override
  String get feedFeaturedBadge => 'Destacado';

  @override
  String feedRadiusKm(int radius) {
    return '$radius km';
  }

  @override
  String get feedRadiusAnywhere => 'En cualquier lugar';

  @override
  String get feedNoLocationNotice =>
      'Sin ubicación disponible — mostrando todos los eventos';

  @override
  String get feedAllCaughtUp => 'Estás al día';

  @override
  String get feedComeBackLater => 'Regresa más tarde';

  @override
  String get feedMinigameInvite => 'Invitación';

  @override
  String get feedLoadError => 'No se pudo cargar el feed';

  @override
  String get shellFeed => 'Feed';

  @override
  String get shellGroups => 'Grupos';

  @override
  String get shellSocial => 'Social';

  @override
  String get shellGames => 'Juegos';

  @override
  String get shellEvents => 'Eventos';

  @override
  String get shellNotifications => 'Notis';

  @override
  String get shellProfile => 'Perfil';

  @override
  String get friendsTitle => 'amigos';

  @override
  String get friendsBlockedTitle => 'bloqueados';

  @override
  String get friendsNoneBlocked => 'No has bloqueado a nadie';

  @override
  String get friendsUnblock => 'Desbloquear';

  @override
  String get friendsSearchHint => 'Buscar entre amigos';

  @override
  String get friendsNoneYet => 'Sin amigos aún';

  @override
  String get friendsSearchPrompt => 'Busca usuarios para agregar amigos';

  @override
  String get friendsNoResults => 'No hay resultados';

  @override
  String get friendsRequestsTitle => 'solicitudes';

  @override
  String get friendsTabReceived => 'Recibidas';

  @override
  String get friendsTabSent => 'Enviadas';

  @override
  String get friendsTabInvites => 'Invitaciones';

  @override
  String get friendsNoReceived => 'Sin solicitudes recibidas';

  @override
  String get friendsNoSent => 'Sin solicitudes enviadas';

  @override
  String get friendsSentYouRequest => 'Te envió una solicitud';

  @override
  String get friendsRequestSent => 'Solicitud enviada';

  @override
  String get friendsNoInvites => 'Sin invitaciones';

  @override
  String get friendsSearchUsers => 'buscar';

  @override
  String get friendsSearchPlaceholder => 'Buscar por nombre de usuario';

  @override
  String get friendsNoUsersFound => 'No se encontraron usuarios';

  @override
  String get friendsStatusAccepted => 'Amigos';

  @override
  String get profileMessage => 'Mensaje';

  @override
  String get friendsStatusPending => 'Solicitado';

  @override
  String get friendsStatusBlocked => 'Bloqueado';

  @override
  String get friendsAddFriendButton => 'Agregar';

  @override
  String get friendsMinCharsHint => 'Escribe al menos 5 caracteres para buscar';

  @override
  String get friendsMutualAcceptedTitle => '¡Solicitud aceptada!';

  @override
  String get friendsMutualAcceptedBody =>
      'Ambos se enviaron solicitud: ya son amigos.';

  @override
  String get groupsTitle => 'Grupos';

  @override
  String get groupsTooltipFindFriends => 'Buscar amigos';

  @override
  String get groupsCreateGroup => 'crear';

  @override
  String get groupsCreateGroupAction => 'Crear grupo';

  @override
  String get groupsRequests => 'Solicitudes';

  @override
  String get socialTitle => 'social';

  @override
  String get socialTabGroups => 'Grupos';

  @override
  String get socialTabFriends => 'Amigos';

  @override
  String get socialSearchTooltip => 'Buscar usuarios';

  @override
  String get socialRankingEntry => 'Ranking';

  @override
  String get socialRankingTitle => 'ranking';

  @override
  String get rankingsUsers => 'Usuarios';

  @override
  String get rankingsGroups => 'Grupos';

  @override
  String get socialRankingEmpty => 'Aún no hay datos de ranking';

  @override
  String get socialCensoredName => 'Usuario';

  @override
  String get socialPublicProfileLabel => 'Perfil público';

  @override
  String get socialPublicProfileBody =>
      'Permite que tu nombre y foto aparezcan en el ranking global de usuarios';

  @override
  String get groupsNoneYet => 'No perteneces a ningún grupo';

  @override
  String get groupsNoneYetSubtitle => 'Crea un grupo o únete a uno existente';

  @override
  String get groupsLimitReached => 'Límite alcanzado';

  @override
  String get groupsLimitReachedBody =>
      'Has alcanzado el límite de 5 grupos como host. Actualiza tu suscripción para crear más.';

  @override
  String get groupsCreatedSnack => 'Grupo creado';

  @override
  String get groupsAddCover => 'Agregar foto de portada';

  @override
  String get groupsNameLabel => 'Nombre del grupo';

  @override
  String get groupsDescriptionOptional => 'Descripción (opcional)';

  @override
  String get groupsInvalidAmount => 'Ingresa un monto válido';

  @override
  String get groupsDonationSuccess => 'Donación exitosa';

  @override
  String get groupsDonateTitle => 'donar';

  @override
  String groupsDonateTo(String groupName) {
    return 'Donar a $groupName';
  }

  @override
  String get groupsDonateBlurb =>
      'Estos shards impulsarán el ranking del grupo durante 14 días';

  @override
  String get groupsShardsAmount => 'Cantidad de shards';

  @override
  String get groupsDonate => 'Donar';

  @override
  String get groupsTabInfo => 'Información';

  @override
  String get groupsTabChat => 'Chat';

  @override
  String get groupsTabMembers => 'Miembros';

  @override
  String get groupsTabEvents => 'Eventos';

  @override
  String get groupsInvitePending => 'Invitación pendiente';

  @override
  String get groupsInvitePendingTitle => 'Invitación de grupo';

  @override
  String get groupsInvitePendingBody =>
      'Has sido invitado a este grupo. Acepta para unirte.';

  @override
  String get groupsFrozenBadge => 'Grupo congelado';

  @override
  String get groupsLeave => 'Abandonar grupo';

  @override
  String get groupsFrozenBanner =>
      'Grupo congelado — actualiza tu suscripción o transfiere el rol de host';

  @override
  String groupsShardsCount(int shards) {
    return '$shards shards de grupo';
  }

  @override
  String groupsMemberCount(int members, int limit) {
    return '$members / $limit miembros';
  }

  @override
  String groupsMembersCountShort(int count) {
    return '$count miembros';
  }

  @override
  String groupsMyContribution(int shards) {
    return 'Mi contribución: $shards shards activos';
  }

  @override
  String get groupsCreateEvent => 'Crear evento';

  @override
  String get groupsChatOneToOneTitle => 'Los chats son 1:1 por ahora';

  @override
  String get groupsChatOneToOneBody =>
      'Los chats de grupo se habilitan desde el listado de mensajes.';

  @override
  String get groupsNoMembers => 'No hay miembros';

  @override
  String get groupsTopContributors => 'Top contribuidores';

  @override
  String groupsShardsCountShort(int shards) {
    return '$shards shards';
  }

  @override
  String groupsMembersCount(int count) {
    return 'Miembros ($count)';
  }

  @override
  String get groupsEventsEmptyTitle => 'Sin eventos en este grupo';

  @override
  String get groupsEventsEmptyBody =>
      'Crea el primer evento del grupo con el botón Crear evento.';

  @override
  String get groupsConfirmLeave => '¿Estás seguro?';

  @override
  String get groupsAbandon => 'Abandonar';

  @override
  String get groupsPromoteStaff => 'Hacer staff';

  @override
  String get groupsDemoteMember => 'Hacer miembro';

  @override
  String get groupsKickMember => 'Expulsar del grupo';

  @override
  String groupsKickConfirmTitle(String name) {
    return '¿Expulsar a $name?';
  }

  @override
  String get groupsKickConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get groupsKick => 'Expulsar';

  @override
  String get groupsNotFound => 'No se encontró el grupo';

  @override
  String get groupsMembersTitle => 'miembros';

  @override
  String get groupsInviteTitle => 'invitar';

  @override
  String groupsInviteCount(int count) {
    return 'Invitar ($count)';
  }

  @override
  String groupsInvitedCount(int count) {
    return '$count invitado(s)';
  }

  @override
  String get groupsSearchUsersHint => 'Busca aquí...';

  @override
  String get groupsMinCharsHint => 'Escribe al menos 2 caracteres para buscar';

  @override
  String get groupsNoResults => 'Sin resultados';

  @override
  String get groupsNoRankingData => 'Sin datos de ranking';

  @override
  String groupsLeaderboardSubtitle(int count, int score) {
    return '$count miembros · $score shards';
  }

  @override
  String get profileTitle => 'perfil';

  @override
  String get profileEditTitle => 'editar';

  @override
  String get profileSettingsTitle => 'ajustes';

  @override
  String get profileSubscription => 'Suscripción';

  @override
  String get profileNotifications => 'Notificaciones';

  @override
  String get profilePrivacy => 'privacidad';

  @override
  String get profileBlockedUsers => 'Usuarios bloqueados';

  @override
  String get profileDeleteMyAccount => 'Eliminar mi cuenta';

  @override
  String get profileSignOut => 'Cerrar sesión';

  @override
  String get profileSignOutQuestion => '¿Cerrar sesión?';

  @override
  String get profileSignOutBody => 'Tu sesión se cerrará en este dispositivo.';

  @override
  String get profileVersion => 'Samay v1.0.0';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsSectionAppearance => 'Apariencia';

  @override
  String get settingsSectionChat => 'Chat';

  @override
  String get settingsSectionGames => 'Juegos';

  @override
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsPrivacyPolicyBody =>
      'Tus datos personales se usan solo para operar Samay: autenticarte, mantener tus grupos y eventos y proteger a la comunidad. Nunca se venden ni se comparten con terceros con fines publicitarios.';

  @override
  String get settingsServiceTermsBody =>
      'Al usar Samay aceptas comportarte con respeto: nada de acoso, spam ni contenido inapropiado. El mal uso puede llevar a la suspensión de tu cuenta.';

  @override
  String get notificationSettingsTitle => 'preferencias de notis';

  @override
  String get notificationSettingsLocalNote =>
      'Estas preferencias se guardan en este dispositivo.';

  @override
  String get profileBio => 'Biografía';

  @override
  String get profileSaveChanges => 'Guardar cambios';

  @override
  String get profileChangePassword => 'Cambiar contraseña';

  @override
  String get profileUpdatedSnack => 'Perfil actualizado';

  @override
  String get profileMyGroups => 'Grupos';

  @override
  String get profileNoGroupsYet => 'No perteneces a ningún grupo aún';

  @override
  String get profileNoGroupsHint => 'Crea o únete a un grupo para verlo aquí.';

  @override
  String profileShardsCount(int shards) {
    return '$shards shards';
  }

  @override
  String profilePreshardsCount(int preshards) {
    return '$preshards preshards';
  }

  @override
  String get profileNoBio => 'Sin biografía';

  @override
  String get profileSharedGroups => 'Grupos compartidos';

  @override
  String get profileNoSharedGroups => 'Sin grupos en común';

  @override
  String get profileFriendRequestSent => 'Solicitud de amistad enviada';

  @override
  String get profileRequestAccepted => 'Solicitud aceptada';

  @override
  String get profileAcceptError => 'Error al aceptar solicitud';

  @override
  String get profileReport => 'Reportar';

  @override
  String get profileBlock => 'Bloquear';

  @override
  String get profileCancelRequest => 'Cancelar solicitud';

  @override
  String get profileAccepting => 'Aceptando...';

  @override
  String get profileAcceptRequest => 'Aceptar solicitud';

  @override
  String get profileSending => 'Enviando...';

  @override
  String get profileAddFriend => 'Agregar amigo';

  @override
  String get profileReportTitle => 'Reportar usuario';

  @override
  String get profileReportReasonHarassment => 'Acoso o abuso';

  @override
  String get profileReportReasonSpam => 'Spam';

  @override
  String get profileReportReasonInappropriate => 'Contenido inapropiado';

  @override
  String get profileReportReasonOther => 'Otro motivo';

  @override
  String get profileReportSent =>
      'Gracias por reportar. Lo revisaremos pronto.';

  @override
  String get profileUserBlocked => 'Usuario bloqueado';

  @override
  String get profileBlockError => 'Error al bloquear';

  @override
  String get profileUserUnblocked => 'Usuario desbloqueado';

  @override
  String get profileUnblockError => 'Error al desbloquear';

  @override
  String get profileDeleteTitle => 'eliminar';

  @override
  String get profileDeleteQuestion => '¿Eliminar cuenta?';

  @override
  String get profileDeleteBody =>
      'Esta acción no se puede deshacer. Tus datos serán anonimizados y tu cuenta será eliminada permanentemente después de 30 días.';

  @override
  String get profileDeleteExplanation =>
      'Al eliminar tu cuenta, tus datos serán anonimizados. Tus mensajes y contribuciones al ranking de grupos se mantendrán pero no serán vinculados a ti. Podrás recuperar tu cuenta dentro de 30 días.';

  @override
  String get profileConfirmEmail =>
      'Confirma tu correo electrónico para continuar:';

  @override
  String get profileEmailMismatch => 'El correo no coincide con tu cuenta';

  @override
  String get profileCosmetics => 'Cosméticos';

  @override
  String get profileNoCosmeticsYet =>
      'Tu armario de cosméticos aparecerá aquí.';

  @override
  String get profileAvatarUpdatedSnack => 'Foto de perfil actualizada';

  @override
  String get profileAvatarChange => 'Cambiar foto de perfil';

  @override
  String get interestMusica => 'Música';

  @override
  String get interestFiestas => 'Fiestas';

  @override
  String get interestDeportes => 'Deportes';

  @override
  String get interestGaming => 'Gaming';

  @override
  String get interestCine => 'Cine';

  @override
  String get interestArte => 'Arte';

  @override
  String get interestViajes => 'Viajes';

  @override
  String get interestComida => 'Comida';

  @override
  String get comingSoonSoon => 'Próximamente';

  @override
  String get comingSoonBack => 'Volver';

  @override
  String get paywallHeader => 'Suscripción';

  @override
  String get paywallAllTiersVisible =>
      'Todos los planes son visibles sin precios ocultos. Elige el que mejor se adapte a ti.';

  @override
  String get paywallTierFree => 'Free';

  @override
  String get paywallTierPro => 'PRO';

  @override
  String get paywallTierVip => 'VIP';

  @override
  String get paywallPerMonth => '/mes';

  @override
  String paywallAnnualEquivalent(String monthly) {
    return '$monthly ahorrando 17%';
  }

  @override
  String get paywallCurrentBadge => 'Actual';

  @override
  String get paywallRestore => 'Restaurar compras';

  @override
  String get paywallUpgradePro => 'Actualizar a PRO';

  @override
  String get paywallUpgradeVip => 'Actualizar a VIP';

  @override
  String get paywallRowEvents => 'Eventos por día';

  @override
  String get paywallRowGroups => 'Grupos máximos';

  @override
  String get paywallRowMembers => 'Miembros por grupo';

  @override
  String get paywallRowPreshards => 'Preshards mensuales';

  @override
  String get paywallRowFeed => 'Publicar en feed';

  @override
  String get paywallRowVideo => 'Video souvenir';

  @override
  String get paywallRowCosmetics => 'Cosméticos de grupo';

  @override
  String get paywallRowRank => 'Rango de grupo';

  @override
  String get paywallUnlimited => 'Ilimitado';

  @override
  String get paywallLimited => 'Limitado';

  @override
  String get paywallCosmeticsFull => 'Completo';

  @override
  String get paywallCosmeticsFullExclusive => 'Completo + exclusivos';

  @override
  String get paywallRankMicro => 'micro';

  @override
  String get paywallRankUpToMedium => 'hasta medium';

  @override
  String get paywallRankAll => 'todos';

  @override
  String get routerRouteNotFound => 'Ruta no encontrada';

  @override
  String get routerRouteNotFoundBody =>
      'La ruta solicitada no existe o no está disponible. Vuelve e intenta de nuevo.';

  @override
  String get routerMissingSignupData =>
      'Faltan los datos del registro. Vuelve e inicia el registro de nuevo.';

  @override
  String get routerMissingAgeGateData =>
      'Faltan los datos de la verificación de edad. Vuelve e intenta de nuevo.';

  @override
  String get routerMissingProfileData =>
      'Faltan los datos del registro. Vuelve e intenta de nuevo.';

  @override
  String get routerEventNotFound => 'No se encontró el evento solicitado.';

  @override
  String get routerGroupNotFound => 'No se encontró el grupo solicitado.';

  @override
  String get routerChatNotFound => 'No se encontró el chat solicitado.';

  @override
  String get routerUserNotFound => 'No se encontró el usuario solicitado.';

  @override
  String get routerInvalidInvite => 'La invitación solicitada no es válida.';

  @override
  String get routerErrorTitle => 'ups';

  @override
  String get routerErrorBody =>
      'No se pudo mostrar esta pantalla. Vuelve e intenta de nuevo.';

  @override
  String get errorsNetwork => 'Error de conexión. Verifica tu internet.';

  @override
  String get errorsUnauthorized => 'Sesión expirada. Inicia sesión de nuevo.';

  @override
  String get errorsServer => 'Error del servidor. Intenta de nuevo.';

  @override
  String get errorsInvalidData => 'Datos inválidos. Verifica los campos.';

  @override
  String get errorsPermission => 'No tienes permiso para realizar esta acción.';

  @override
  String get errorsRateLimit => 'Demasiadas solicitudes. Espera un momento.';

  @override
  String errorsNotFound(String resource) {
    return '$resource no encontrado.';
  }

  @override
  String get errorsNotFoundGeneric => 'No encontrado.';

  @override
  String get errorsInvalidCredentials => 'Correo o contraseña inválidos';

  @override
  String get errorsOtpExpired => 'El código ha expirado. Solicita uno nuevo.';

  @override
  String get errorsOtpInvalid =>
      'El código es incorrecto o ha expirado. Solicita uno nuevo.';

  @override
  String get errorsInvalidReference => 'Referencia inválida';

  @override
  String get errorsAlreadyExists => 'Ya existe';

  @override
  String get errorsInvalidFormat => 'Formato inválido';

  @override
  String get errorsInsufficientShards => 'No tienes suficientes shards';

  @override
  String get errorsFriendshipExists =>
      'Ya existe una solicitud o amistad con este usuario';

  @override
  String get errorsGeneric => 'Ha ocurrido un error';

  @override
  String get errorCodeLabel => 'Código de error';

  @override
  String get rankFullVibe => 'Full Vibe';

  @override
  String get rankVibeLegends => 'Leyendas de la Vibra';

  @override
  String get rankVibeCreators => 'Creadores de la Vibra';

  @override
  String get rankVibeFollowers => 'Seguidores de la Vibra';

  @override
  String get rankVibeSeekers => 'Buscadores de la Vibra';

  @override
  String get rankInSearch => 'En la Búsqueda';

  @override
  String get photosTitle => 'Fotos';

  @override
  String get photosEmpty => 'No hay fotos todavía';

  @override
  String get photosEmptyBody => '¡Sé el primero en subir una!';

  @override
  String get photosUpload => 'Subir foto';

  @override
  String get photosPermissionRationale =>
      'Para subir fotos del evento, Samay necesita acceso a tus fotos.';

  @override
  String get photosUploadedSnack => 'Foto subida';

  @override
  String get photosUploadWindowClosed =>
      'La ventana de subida de fotos ya cerró';

  @override
  String photosLikesCount(int count) {
    return '$count likes';
  }

  @override
  String get photosLikeTooltip => 'Me gusta';

  @override
  String get photosReportTitle => 'Reportar foto';

  @override
  String get photosReportBody =>
      'Describe por qué quieres reportar esta foto. El equipo de moderación la revisará.';

  @override
  String get photosReportHint => 'Escribe el motivo (opcional)';

  @override
  String get photosReportSubmit => 'Enviar reporte';

  @override
  String get photosReportSent => 'Reporte enviado';

  @override
  String get permissionsPhotoRationale =>
      'Para elegir una foto de portada, Samay necesita acceso a tus fotos.';

  @override
  String get permissionsCameraRationale =>
      'Para escanear códigos QR y tomar fotos, Samay necesita acceso a tu cámara.';

  @override
  String get permissionsSettingsTitle => 'Permiso requerido';

  @override
  String get permissionsSettingsBody =>
      'Este permiso fue bloqueado por el sistema. Para usar esta función, actívalo desde los ajustes de tu dispositivo.';

  @override
  String get permissionsOpenSettings => 'Abrir ajustes';

  @override
  String get notificationsTitle => 'notis';

  @override
  String get notificationSettingsEventReminders => 'Recordatorios de eventos';

  @override
  String get notificationSettingsFriendRequests => 'Solicitudes de amistad';

  @override
  String get notificationSettingsChatMessages => 'Mensajes de chat';

  @override
  String get notificationSettingsShardsRank => 'Shards y ranking';

  @override
  String get notificationsEmpty => 'Sin notificaciones';

  @override
  String get notificationsEmptyBody =>
      'Cuando recibas novedades, aparecerán aquí.';

  @override
  String get notificationsMarkAllRead => 'Marcar todo como leído';

  @override
  String get notificationsLoadError =>
      'No se pudieron cargar las notificaciones';

  @override
  String get notificationsTimeNow => 'Ahora';

  @override
  String notificationsTimeMinutes(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String notificationsTimeHours(int hours) {
    return 'hace $hours h';
  }

  @override
  String notificationsTimeDays(int days) {
    return 'hace $days d';
  }

  @override
  String get chatTitle => 'chat';

  @override
  String get chatInputHint => 'Escribe un mensaje...';

  @override
  String get chatSend => 'Enviar';

  @override
  String get chatUndecryptable => 'Mensaje no descifrable';

  @override
  String get chatDeleteForEveryone => 'Eliminar para todos';

  @override
  String get chatDeleteForMe => 'Eliminar para mí';

  @override
  String get chatDeleteTooOld =>
      'Solo puedes eliminar mensajes enviados hace menos de 5 minutos';

  @override
  String get chatDeleteFailed => 'No se pudo eliminar el mensaje';

  @override
  String get chatPeerReinstalled =>
      'El otro usuario reinstaló la app o cambió de dispositivo';

  @override
  String get chatEmpty => 'No hay mensajes todavía';

  @override
  String get chatLoadError => 'No se pudieron cargar los mensajes';

  @override
  String get chatSendError => 'No se pudo enviar el mensaje';

  @override
  String get chatLoadOlder => 'Cargar anteriores';

  @override
  String get chatInboxTitle => 'chats';

  @override
  String get chatInboxEmpty => 'No hay conversaciones';

  @override
  String get chatInboxEmptyBody =>
      'Toca \'Enviar mensaje\' en el perfil de alguien para iniciar un chat.';

  @override
  String get chatInboxLoadError => 'No se pudieron cargar los chats';

  @override
  String get chatInboxPreviewOwn => 'Tú: ';

  @override
  String get commonNow => 'ahora';

  @override
  String get commonToday => 'Hoy';

  @override
  String get commonYesterday => 'Ayer';

  @override
  String get chatReadReceipts => 'Confirmaciones de lectura';

  @override
  String get chatReadReceiptsBody =>
      'Si está desactivado, tus mensajes nunca se marcan como leídos.';

  @override
  String get chatReadReceiptsSaveError =>
      'No se pudo actualizar las confirmaciones de lectura';

  @override
  String get chatSent => 'Enviado';

  @override
  String get chatReceived => 'Recibido';

  @override
  String get chatRead => 'Leído';

  @override
  String get eventsTypeLabel => 'Tipo de evento';

  @override
  String get eventsTypeCasual => 'Casual';

  @override
  String get eventsTypeCasualDescription =>
      'Películas, cenas, informales — sin preshards';

  @override
  String get eventsTypeJuerga => 'Juerga';

  @override
  String get eventsTypeJuergaDescription =>
      'Local privado — los invitados verán la dirección';

  @override
  String get eventsTypeTono => 'Tono';

  @override
  String get eventsTypeTonoDescription => 'Bar, club o local público';

  @override
  String get eventsNameLabel => 'Nombre del evento';

  @override
  String get eventsDescriptionOptional => 'Descripción (opcional)';

  @override
  String get eventsStartsLabel => 'Inicio';

  @override
  String get eventsEndsLabel => 'Fin';

  @override
  String get eventsLocationLabel => 'Dirección / lugar';

  @override
  String get eventsVisibilityLabel => 'Visibilidad';

  @override
  String get eventsVisibilityPublic => 'Público';

  @override
  String get eventsVisibilityGroup => 'Grupo';

  @override
  String get eventsGroupSelectorLabel => 'Grupo del evento';

  @override
  String get eventsGroupSelectorHint => 'Selecciona un grupo';

  @override
  String get eventsGroupsLoadError => 'No se pudieron cargar tus grupos';

  @override
  String get eventsJoinModeLabel => 'Modo de acceso';

  @override
  String get eventsJoinModeOpen => 'Abierto';

  @override
  String get eventsJoinModeOpenDescription =>
      'Cualquiera con el enlace de invitación puede unirse';

  @override
  String get eventsJoinModeApproval => 'Aprobación';

  @override
  String get eventsJoinModeApprovalDescription =>
      'El host aprueba cada solicitud';

  @override
  String get eventsJuergaWarningTitle => 'Aviso de ubicación';

  @override
  String get eventsJuergaWarningBody =>
      'Los invitados verán esta dirección. Solo invita a personas en quienes confíes.';

  @override
  String get eventsJuergaWarningConfirm => 'Confirmar';

  @override
  String get eventsPreshardsLabel => 'Preshards';

  @override
  String get eventsPreshardsPoolLabel => 'Pool de preshards';

  @override
  String get eventsPreshardsCapLabel => 'Tope por asistente (opcional)';

  @override
  String get eventsRemainderLabel => 'Resto del pool';

  @override
  String get eventsRemainderReturn => 'Devolver proporcionalmente';

  @override
  String get eventsRemainderRedistribute => 'Redistribuir entre asistentes';

  @override
  String get eventsDynamicQrHint =>
      'Con pool mayor a 0, el QR dinámico se activa automáticamente';

  @override
  String get eventsErrorNameRequired => 'El nombre del evento es obligatorio';

  @override
  String get eventsErrorTimeRange =>
      'La fecha de fin debe ser posterior a la de inicio';

  @override
  String get eventsErrorCasualPool =>
      'Los eventos casuales no pueden tener pool';

  @override
  String get eventsErrorJuergaConfirm =>
      'Confirma el aviso de ubicación para continuar';

  @override
  String get eventsErrorGroup => 'Selecciona un grupo';

  @override
  String get eventsErrorJoinMode => 'Selecciona el modo de acceso';

  @override
  String get eventDetailTitle => 'evento';

  @override
  String get eventGroupScoped => 'Evento de grupo';

  @override
  String get eventViewGroup => 'Ver grupo';

  @override
  String get eventNoLocation => 'Sin ubicación';

  @override
  String eventPoolAmount(int pool) {
    return '$pool preshards';
  }

  @override
  String get eventPoolDistributed => 'Distribuido';

  @override
  String get eventPoolNotDistributed => 'Pendiente de distribuir';

  @override
  String eventCapPerUser(int cap) {
    return 'Tope por asistente: $cap preshards';
  }

  @override
  String get eventNoPool => 'Sin pool de preshards';

  @override
  String eventRemainderAction(String action) {
    return 'Sobrante: $action';
  }

  @override
  String get eventHosts => 'Anfitrión y staff';

  @override
  String get eventRoleHost => 'Anfitrión';

  @override
  String get eventRoleStaff => 'Staff';

  @override
  String get eventHostsError => 'No se pudo cargar el anfitrión y staff';

  @override
  String get eventNoHosts => 'Aún no hay anfitriones ni staff';

  @override
  String get eventStaffAddButton => 'Añadir staff';

  @override
  String get eventStaffPickerTitle => 'elegir staff';

  @override
  String eventStaffCount(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get eventStaffAdded => 'Staff añadido';

  @override
  String get eventStaffRemoved => 'Staff eliminado';

  @override
  String get eventStaffRemove => 'Quitar staff';

  @override
  String eventStaffRemoveDialogTitle(String username) {
    return '¿Quitar a @$username?';
  }

  @override
  String get eventStaffRemoveDialogBody =>
      'Dejará de ser staff y no podrá escanear códigos de asistencia.';

  @override
  String get eventStaffRemoveConfirm => 'Quitar';

  @override
  String eventInviteStatus(String status) {
    return 'Tu invitación: $status';
  }

  @override
  String get eventInvitePending => 'pendiente';

  @override
  String get eventInviteAccepted => 'aceptada';

  @override
  String get eventInviteDeclined => 'declinada';

  @override
  String get eventInviteAttended => 'asistida';

  @override
  String get eventGuestsTitle => 'Invitados';

  @override
  String get eventGuestsEmpty => 'Aún no hay invitados';

  @override
  String get eventGuestsLoadError => 'No se pudieron cargar los invitados';

  @override
  String get eventAttendeesTitle => 'Asistentes';

  @override
  String get eventAttendeesEmpty => 'Aún no hay asistentes confirmados';

  @override
  String get eventAttendeesLoadError => 'No se pudieron cargar los asistentes';

  @override
  String get eventInviteGuestsButton => 'Invitar personas';

  @override
  String get eventsInviteTitle => 'invitar';

  @override
  String eventsInviteCount(int count) {
    return 'Invitar ($count)';
  }

  @override
  String get eventsInviteSent => 'Invitación enviada';

  @override
  String get eventsInviteSentTag => 'invitada';

  @override
  String get eventInvitePendingBody =>
      'Te invitaron a este evento. Confirma tu asistencia.';

  @override
  String get eventInviteAccept => 'Aceptar';

  @override
  String get eventInviteDecline => 'Rechazar';

  @override
  String get eventInviteAcceptedSnack => 'Asistencia confirmada';

  @override
  String get eventInviteDeclinedSnack => 'Invitación rechazada';

  @override
  String get eventEditButton => 'Editar';

  @override
  String get eventCancelButton => 'Cancelar evento';

  @override
  String get eventCancelDialogTitle => '¿Cancelar evento?';

  @override
  String get eventCancelDialogBody =>
      'Se devolverán los preshards a los hosts. Los invitados serán notificados.';

  @override
  String get eventCancelConfirm => 'Sí, cancelar';

  @override
  String get eventCancelledSnack => 'Evento cancelado';

  @override
  String get eventEditTitle => 'editar';

  @override
  String get eventPoolLockedNotice =>
      'El pool, tope y sobrante pueden editarse hasta que comience el evento.';

  @override
  String get eventEditUpdatedSnack => 'Evento actualizado';

  @override
  String get eventInvalidPoolAmount => 'Ingresa un monto de pool válido';

  @override
  String get eventStatusDraft => 'Borrador';

  @override
  String get eventStatusUpcoming => 'Próximamente';

  @override
  String get eventStatusLive => 'En vivo';

  @override
  String get eventStatusEnded => 'Finalizado';

  @override
  String get eventStatusCancelled => 'Cancelado';

  @override
  String get qrAttendanceTitle => 'Código';

  @override
  String get qrEventLoadError => 'No se pudo cargar el evento.';

  @override
  String qrActivationCountdown(String time) {
    return 'Se activa en $time';
  }

  @override
  String get qrScannerTitle => 'Escáner';

  @override
  String get qrScanPrompt => 'Escanea el código QR del asistente';

  @override
  String qrScanEventName(String name) {
    return 'Evento: $name';
  }

  @override
  String get qrScanEventFallback => 'Evento';

  @override
  String get qrTorchOn => 'Encender linterna';

  @override
  String get qrTorchOff => 'Apagar linterna';

  @override
  String get qrScanProcessing => 'Verificando…';

  @override
  String get qrScanConfirmed => '¡Asistencia confirmada!';

  @override
  String qrScanAttendee(String name) {
    return 'Asistente: $name';
  }

  @override
  String get qrScanReady => 'Listo';

  @override
  String get qrScanAlreadyScanned => 'Este código QR ya fue escaneado.';

  @override
  String get qrScanNotInvited => 'El usuario no está invitado a este evento.';

  @override
  String get qrScanNotInWindow =>
      'El evento no está activo para confirmación de asistencia.';

  @override
  String get qrScanNotHost =>
      'No tienes permisos para escanear en este evento.';

  @override
  String get qrScanInvalidCode => 'Código QR inválido.';

  @override
  String get qrScanNetworkError => 'Error de conexión. Reintentar...';

  @override
  String get qrCameraUnavailable => 'No se pudo acceder a la cámara.';

  @override
  String get qrCameraUnavailableBody =>
      'Cierra y vuelve a abrir el escáner, o revisa los permisos de la cámara.';

  @override
  String get qrCameraDenied => 'Se necesita acceso a la cámara para escanear.';

  @override
  String get qrCameraSettingsTitle => 'Acceso a la cámara';

  @override
  String get qrCameraSettingsBody =>
      'Samay necesita acceso a la cámara para escanear los códigos QR de asistencia.';

  @override
  String get qrCameraSettingsAction => 'Abrir ajustes';

  @override
  String get codeNotReadyYet => 'Tu código de asistencia aún no está listo.';

  @override
  String get codeLoadError => 'No se pudo cargar tu código.';

  @override
  String get codeEventEnded =>
      'El evento finalizó. Ya no se necesita un código de asistencia.';

  @override
  String get codeNotInvited => 'No tienes un código para este evento.';

  @override
  String get codeServerPending => 'El servidor aún no emitió tu código.';

  @override
  String get codeServerPendingBody =>
      'Si el problema continúa, presiona Reintentar.';

  @override
  String get codeAssistedDone => 'LISTO';

  @override
  String get cosmeticsShopTitle => 'cosméticos';

  @override
  String get cosmeticsTabFrames => 'Marcos';

  @override
  String get cosmeticsTabBackgrounds => 'Fondos';

  @override
  String get cosmeticsTabBadges => 'Insignias';

  @override
  String get cosmeticsTierVip => 'VIP';

  @override
  String get cosmeticsTierPro => 'PRO';

  @override
  String get cosmeticsTierFree => 'Gratis';

  @override
  String get cosmeticsPurchaseTitle => 'Confirmar compra';

  @override
  String cosmeticsPurchaseConfirm(String name, int cost) {
    return '¿Comprar $name por $cost shards?';
  }

  @override
  String get cosmeticsBuy => 'Comprar';

  @override
  String cosmeticsBuyWithCost(int cost) {
    return 'Comprar — $cost';
  }

  @override
  String get cosmeticsPurchaseSuccess => '¡Cosmético adquirido!';

  @override
  String get cosmeticsTierRequired =>
      'Requiere una suscripción de nivel superior.';

  @override
  String get cosmeticsOwned => 'Adquirido';

  @override
  String get cosmeticsEquipped => 'Equipado';

  @override
  String get cosmeticsEquip => 'Equipar';

  @override
  String cosmeticsRequiresTier(String tier) {
    return 'Requiere $tier';
  }

  @override
  String get cosmeticsEmptyCatalog => 'No hay cosméticos disponibles aún';

  @override
  String get minigamesTitle => 'juegos';

  @override
  String get minigamesTagline => 'Te atreves';

  @override
  String get minigamesChooseGroup => 'Elige un grupo';

  @override
  String get minigamesChooseGroupEllipsis => '…';

  @override
  String get minigamesNoGroups => 'Aún no tienes grupos';

  @override
  String get minigamesNoGroupsBody =>
      'Únete o crea un grupo para jugar con tus amigos.';

  @override
  String get minigamesPickGame => 'Elige un juego';

  @override
  String get minigamesGameTruthDare => 'Verdad o Reto';

  @override
  String get minigamesGameTruthDareTagline => '¿Te atreves...?';

  @override
  String get minigamesGameTruthDareExplanation =>
      'Cada jugador elige Verdad o Reto y el grupo decide si cumpliste. Sin escapatoria.';

  @override
  String get minigamesGameDrunkBottle => 'Botella';

  @override
  String get minigamesGameDrunkBottleTagline =>
      'Gira la botella y veamos a quién apunta';

  @override
  String get minigamesGameDrunkBottleExplanation =>
      'Gira la botella: a quien apunte le toca cumplir. Ideal para reuniones con amigos.';

  @override
  String get minigamesBottleSpin => 'Girar';

  @override
  String get minigamesBottleStop => 'Parar';

  @override
  String get minigamesGameCharades => 'Charadas';

  @override
  String get minigamesGameCharadesTagline =>
      'Celular en la frente y que adivinen';

  @override
  String get minigamesGameCharadesExplanation =>
      'Te pones el celular en la frente sin mirar la pantalla. El grupo actúa la palabra que aparece y tú adivinas. Cada acierto suma un punto y, cuando se acaba el tiempo, le toca al siguiente.';

  @override
  String get charadesRulesTitle => 'Cómo se juega';

  @override
  String get charadesRule1 =>
      'Pon el celular en tu frente, con la pantalla hacia el grupo. No mires.';

  @override
  String get charadesRule2 =>
      'El grupo actúa la palabra sin decirla ni deletrearla.';

  @override
  String get charadesRule3 =>
      'Si adivinas, toca Acerté. Si se complica, toca Paso.';

  @override
  String get charadesRule4 =>
      'Al terminar el tiempo se cuentan tus aciertos y pasa el turno.';

  @override
  String get charadesPickCategory => 'Elige una categoría';

  @override
  String get charadesDuration => 'Duración';

  @override
  String charadesSeconds(int count) {
    return '$count s';
  }

  @override
  String get charadesStartTurn => 'Empezar mi turno';

  @override
  String get charadesHit => 'Acerté';

  @override
  String get charadesPass => 'Paso';

  @override
  String get charadesFinish => 'Terminar turno';

  @override
  String charadesPlayingBy(String name) {
    return 'Está jugando $name';
  }

  @override
  String get charadesActNow => '¡Actúen la palabra!';

  @override
  String get charadesTimeUp => '¡Se acabó el tiempo!';

  @override
  String charadesTurnScore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aciertos',
      one: '1 acierto',
      zero: 'Sin aciertos',
    );
    return '$_temp0';
  }

  @override
  String get charadesScoreboard => 'Marcador';

  @override
  String get charadesNextPlayer => 'Que juegue otro';

  @override
  String get charadesWaitingTurn => 'Nadie está jugando todavía';

  @override
  String get charadesCategoryAll => 'Todas';

  @override
  String get charadesCategoryPeliculas => 'Películas';

  @override
  String get charadesCategoryAnimales => 'Animales';

  @override
  String get charadesCategoryAcciones => 'Acciones';

  @override
  String get charadesCategoryObjetos => 'Objetos';

  @override
  String get charadesCategoryFamosos => 'Famosos';

  @override
  String get charadesCategoryFiesta => 'Fiesta';

  @override
  String get minigamesPublishTitle => 'Partida abierta';

  @override
  String get minigamesPublishSubtitle =>
      'Cualquiera en la app puede verla y unirse sin invitación';

  @override
  String get minigamesPublicLobbyTitle => 'Partidas abiertas';

  @override
  String get minigamesPublicJoin => 'Unirme';

  @override
  String get minigamesPublicJoined => 'Te uniste a la partida';

  @override
  String get minigamesPublicAlreadyIn => 'Ya estás dentro';

  @override
  String get minigamesPublicEmpty =>
      'Todavía nadie publicó una partida. Crea una y ábrela para que se sumen.';

  @override
  String minigamesPublicHostedBy(String name) {
    return 'de $name';
  }

  @override
  String minigamesPublicPlayers(int count, int limit) {
    return '$count/$limit jugadores';
  }

  @override
  String get minigamesPublicFull => 'Llena';

  @override
  String get minigamesBottleSpinning => 'Girando…';

  @override
  String get minigamesBottleTapToSpin => 'Toca Girar y que decida la botella';

  @override
  String minigamesBottleLandedOn(String name) {
    return 'Le tocó a $name';
  }

  @override
  String get minigamesBottleYourTurn => '¡Te tocó a ti!';

  @override
  String get minigamesBottleDareTitle => 'Tu reto';

  @override
  String minigamesBottleSpunBy(String name) {
    return 'Giró $name';
  }

  @override
  String get minigamesBottleCategorySuave => 'suave';

  @override
  String get minigamesBottleCategoryMedio => 'medio';

  @override
  String get minigamesBottleCategoryPicante => 'picante';

  @override
  String get minigamesBottleCategoryCastigo => 'castigo';

  @override
  String minigamesBottleMinPlayers(int min, int count) {
    return 'La botella necesita al menos $min jugadores (tienes $count)';
  }

  @override
  String get minigamesGameTwoLiesOneTruth => '2 Mentiras, 1 Verdad';

  @override
  String get minigamesGameTwoLiesOneTruthTagline =>
      'Adivina cuál es la única verdad';

  @override
  String get minigamesGameTwoLiesOneTruthExplanation =>
      'El protagonista escribe 3 afirmaciones sobre sí mismo: 2 mentiras y 1 verdad. Los demás deben adivinar cuál es la real.';

  @override
  String get minigamesAudienceFriends => 'Para jugar con amigos';

  @override
  String get minigamesAudienceSolo => 'Para jugar solo';

  @override
  String get minigamesAudienceBoth => 'Con amigos o solo';

  @override
  String get minigamesNewPartida => 'Nueva partida';

  @override
  String get minigamesScopeLabel => 'Partida';

  @override
  String get minigamesPartidaNameLabel => 'Nombre (opcional)';

  @override
  String minigamesPartidaNameHint(String autoName) {
    return '$autoName';
  }

  @override
  String minigamesAutoName(int index) {
    return 'partida-$index';
  }

  @override
  String get minigamesOngoingTitle => 'Partidas en curso';

  @override
  String minigamesDetailEmpty(String game) {
    return 'Aún no hay partidas de $game';
  }

  @override
  String get minigamesDetailEmptyBody =>
      'Toca «Nueva partida» para crear la primera.';

  @override
  String get minigamesWagerDefaultHint => 'Por defecto: 10';

  @override
  String get minigamesRoundsLabel => 'Rondas';

  @override
  String get minigamesRoundsHint => 'Por defecto: 5';

  @override
  String get minigamesWagerLabel => 'Entrada';

  @override
  String get minigamesWagerHint => '0 = sin apuesta';

  @override
  String get minigamesWagerBalanceCaption => 'Disponibles';

  @override
  String get minigamesCreate => 'Crear partida';

  @override
  String get minigamesCreated => 'Partida creada';

  @override
  String get minigamesErrorInsufficientShards =>
      'No tienes suficientes shards para esta apuesta.';

  @override
  String get minigamesErrorNotMember => 'No eres miembro de este grupo.';

  @override
  String get minigamesErrorInvalidGameType => 'No se pudo crear la partida.';

  @override
  String get minigamesErrorCreate => 'No se pudo crear la partida.';

  @override
  String get minigamesErrorInviteeNotAllowed =>
      'Algunos jugadores no pudieron ser invitados.';

  @override
  String get minigamesErrorInviteeFriendsOnly =>
      'Uno o más jugadores solo aceptan invitaciones de amigos.';

  @override
  String get minigamesErrorTooManyInvitees =>
      'Puedes invitar hasta 20 jugadores.';

  @override
  String get minigamesErrorLoad => 'No se pudieron cargar las partidas';

  @override
  String get minigamesEmpty => 'Aún no hay partidas en este grupo';

  @override
  String get minigamesEmptyBody =>
      'Crea la primera partida con uno de los juegos de arriba.';

  @override
  String get minigamesStatusActive => 'Activa';

  @override
  String get minigamesStatusFinished => 'Terminada';

  @override
  String get minigamesViewLeaderboard => 'Ver clasificación';

  @override
  String get minigamesPoolBreakdownTitle => 'Premios';

  @override
  String minigamesPoolRank(int rank) {
    return '$rankº';
  }

  @override
  String get minigamesPoolNoPrize => 'Sin premio';

  @override
  String get minigamesDetailComingSoon => 'La partida se jugará aquí pronto.';

  @override
  String get minigamesPlayTitle => 'Verdad o Reto';

  @override
  String get minigamesBarWaiting => 'esperando…';

  @override
  String get minigamesBarError => 'error';

  @override
  String get minigamesBarLeaderboard => 'clasificación';

  @override
  String get minigamesBarResponding => 'respondiendo';

  @override
  String get minigamesTurnBarPrefix => 'turno de ';

  @override
  String get minigamesTurnBarSuffix => '';

  @override
  String get minigamesResponseBarPrefix => 'respuesta de ';

  @override
  String get minigamesResponseBarSuffix => '';

  @override
  String get minigamesChoosePromptGeneric =>
      '¡Es tu turno! Elige Verdad o Reto';

  @override
  String minigamesChoosePromptFor(String name) {
    return 'Le toca a $name: elige Verdad o Reto';
  }

  @override
  String get minigamesTruth => 'Verdad';

  @override
  String get minigamesDare => 'Reto';

  @override
  String minigamesPromptHeader(String name) {
    return '¡Toca $name!';
  }

  @override
  String get minigamesPromptGeneric => '¡Toca jugar!';

  @override
  String get minigamesPromptDone => 'Hecho';

  @override
  String get minigamesPromptLoadError => 'ERROR AL CARGAR LA PREGUNTA';

  @override
  String get minigamesPromptSkip => 'Saltar';

  @override
  String get minigamesTurnGeneric => 'Turno de un jugador';

  @override
  String get minigamesYourTurn => 'tu turno…';

  @override
  String get minigamesAnonAliasPrefix => 'anónimo';

  @override
  String get minigamesAnswerTitle => 'Tu respuesta';

  @override
  String get minigamesAnswerPlaceholder => 'Escribe tu respuesta…';

  @override
  String get minigamesAnswerImageLabel => 'Añadir imagen';

  @override
  String get minigamesAnswerRemoveImage => 'Quitar imagen';

  @override
  String get minigamesAnswerSubmit => 'Responder';

  @override
  String get minigamesAnswerRevealed => 'Respondida';

  @override
  String get minigamesAnswerWaiting => 'Esperando la respuesta…';

  @override
  String minigamesAnswerWaitingReactions(int reacted, int required) {
    return 'esperando $reacted/$required reacciones…';
  }

  @override
  String get minigamesKeyRequesting =>
      'Esperando a que otro participante se conecte para descifrar…';

  @override
  String get minigamesKeyMissing => 'Nadie conectado para reenviar la clave.';

  @override
  String get minigamesPasar => 'Pasar';

  @override
  String get minigamesPasarSkipped => 'pasó';

  @override
  String get minigamesModeLabel => 'Modo de juego';

  @override
  String get minigamesModeByTurns => 'Por turnos';

  @override
  String get minigamesModeAsync => 'Asíncrono';

  @override
  String get minigamesAsyncRoundsLabel => 'Rondas por jugador';

  @override
  String get minigamesAsyncEndsLabel => 'Tiempo de la partida (días)';

  @override
  String get minigamesAnonymousLabel => 'Partida anónima';

  @override
  String get minigamesAliasLabel => 'Apodo temporal';

  @override
  String get minigamesAliasUpdate => 'Actualizar nombre';

  @override
  String get minigamesAliasUpdated => 'Nombre actualizado';

  @override
  String minigamesAsyncProgress(int done, int target) {
    return 'Tus rondas: $done/$target';
  }

  @override
  String get minigamesAsyncAvailable => 'Rondas para reaccionar';

  @override
  String minigamesAsyncTimerEnds(String date) {
    return 'La partida termina el $date';
  }

  @override
  String get minigamesAnswerPasarLine => 'puedes pasar si no quieres responder';

  @override
  String minigamesTurnFor(String name) {
    return 'Turno de $name';
  }

  @override
  String minigamesNextTurn(String name) {
    return 'Siguiente: $name';
  }

  @override
  String get minigamesWaitingChoiceGeneric => 'Esperando al jugador actual…';

  @override
  String get minigamesCountdownStarting => 'La partida empieza en…';

  @override
  String get minigamesCountdownWaitingHost => 'Esperando al anfitrión…';

  @override
  String get minigamesCountdownHostError =>
      'El anfitrión no confirmó la partida. Inténtalo de nuevo.';

  @override
  String get minigamesCountdownCancel => 'Cancelar';

  @override
  String get minigamesComplete => 'Terminar juego';

  @override
  String get minigamesCompleteConfirm =>
      '¿Seguro? Las apuestas se redistribuirán.';

  @override
  String get minigamesCompleteConfirmTitle => '¿Terminar la partida?';

  @override
  String get minigamesFinished => '¡Juego terminado!';

  @override
  String minigamesRoundCounter(int current, int total) {
    return 'Ronda $current / $total';
  }

  @override
  String get minigamesAnonymousPlayer => 'Jugador';

  @override
  String minigamesPrizeAmount(int amount) {
    return '$amount shards';
  }

  @override
  String minigamesPointsAmount(int count) {
    return '$count puntos';
  }

  @override
  String get minigamesAnswersLoadError =>
      'Ups, no pudimos cargar las respuestas de la partida. Inténtalo más tarde.';

  @override
  String get minigamesNoAnswers => 'Sin respuestas registradas';

  @override
  String get minigamesErrorLoadGame => 'No se pudo cargar el juego';

  @override
  String get shardsLedgerTitle => 'shards';

  @override
  String get shardsLedgerTabShards => 'Shards';

  @override
  String get shardsLedgerTabPreshards => 'Preshards';

  @override
  String get shardsLedgerNet => 'Neto';

  @override
  String get shardsLedgerEmpty => 'Sin movimientos todavía';

  @override
  String get shardsLedgerEmptyBody =>
      'Cuando ganes o gastes shards, aparecerán aquí.';

  @override
  String get shardsLedgerLoadError => 'No se pudieron cargar los movimientos';

  @override
  String get shardsLedgerEarned => 'Ganados';

  @override
  String get shardsLedgerBought => 'Comprados/Bonos';

  @override
  String get shardsLedgerEarnedNote => 'Los shards ganados nunca expiran.';

  @override
  String get shardsLedgerPreshardsNote =>
      'Los preshards solo se usan para eventos.';

  @override
  String shardsLedgerReference(String reference) {
    return 'Ref: $reference';
  }

  @override
  String get shardsReasonEventAttendance => 'Asistencia a evento';

  @override
  String get shardsReasonCosmeticPurchase => 'Compra de cosmético';

  @override
  String get shardsReasonGroupDonation => 'Donación a grupo';

  @override
  String get shardsReasonMinigameWager => 'Apuesta en minigame';

  @override
  String get shardsReasonMinigameWin => '¡Ganaste el minigame!';

  @override
  String get shardsReasonMinigameRefund => 'Reembolso de minigame';

  @override
  String get shardsReasonSubscriptionGrant => 'Bono de suscripción';

  @override
  String get shardsReasonAdminGrant => 'Otorgado por Samay';

  @override
  String get shardsReasonFeedPost => 'Publicación en feed';

  @override
  String get preshardsReasonPurchased => 'Compra de preshards';

  @override
  String get preshardsReasonSubscriptionGrant => 'Bono mensual';

  @override
  String get preshardsReasonEventPoolSet => 'Asignado a evento';

  @override
  String get preshardsReasonEventPoolConsumed => 'Distribuido en evento';

  @override
  String get preshardsReasonEventPoolReturned => 'Devuelto de evento';

  @override
  String get preshardsReasonAdminGrant => 'Otorgado por Samay';

  @override
  String get eventsTabTitle => 'eventos';

  @override
  String get eventsCreateCta => 'Crear evento';

  @override
  String get eventsCreateCtaBody =>
      'Crea tu evento e invita personas — tu plan limita los asistentes.';

  @override
  String get eventsCapacityTitle => '¿Cuántas personas pueden asistir?';

  @override
  String get eventsCapacityHint => 'Personas en total, incluyéndote.';

  @override
  String get eventsCapacityContact => '¿Quieres más? Contáctanos';

  @override
  String get eventsContactSoon => 'Muy pronto — te contactaremos.';

  @override
  String get eventsEmpty => 'Aún no tienes eventos';

  @override
  String get eventsEmptyBody =>
      'Cuando te inviten o crees uno, aparecerá aquí.';

  @override
  String get featureUnavailableTitle => 'No disponible';

  @override
  String get featureUnavailableBody => 'Esta función aún no está disponible.';

  @override
  String get collageTitle => 'collage';

  @override
  String get collageEmpty => 'Aún no hay fotos para el collage';

  @override
  String get collageEmptyBody =>
      'El collage se arma solo con las fotos del evento.';

  @override
  String collagePhotoCount(int count) {
    return '$count fotos';
  }

  @override
  String get connectivityOfflineBanner =>
      'Sin conexión — los datos podrían no estar actualizados';

  @override
  String get crashRecoveryBannerTitle =>
      'La app se recuperó de un cierre inesperado';

  @override
  String get chatMessageInfo => 'Información del mensaje';

  @override
  String get chatMessageInfoSent => 'Enviado';

  @override
  String chatMessageInfoReadBy(int count, int total) {
    return 'Leído por $count de $total';
  }

  @override
  String get chatMessageInfoReadAt => 'Leído';

  @override
  String get chatMessageInfoNotRead => 'No leído';

  @override
  String get minigamesInviteTitle => 'invitar';

  @override
  String minigamesInviteCount(int count) {
    return 'Enviar ($count)';
  }

  @override
  String get minigamesDetailTitle => 'partida';

  @override
  String get minigamesParticipantsTitle => 'Jugadores';

  @override
  String get minigamesReady => 'Listo';

  @override
  String get minigamesNotReady => 'No listo';

  @override
  String get minigamesReadyQuestion => '¿Listo?';

  @override
  String get minigamesCreator => 'Anfitrión';

  @override
  String get minigamesStart => 'Empezar';

  @override
  String get minigamesRejoin => 'Volver a la partida';

  @override
  String get minigamesRemovePlayer => 'Quitar jugador';

  @override
  String minigamesRemovePlayerConfirm(String name) {
    return '¿Quitar a $name de esta partida?';
  }

  @override
  String get minigamesRemovePlayerConfirmBody =>
      'Se le devolverá su apuesta y se le quitará del juego.';

  @override
  String get minigamesStartOnlyCreator =>
      'Solo el anfitrión puede empezar la partida.';

  @override
  String get minigamesWaitingForPlayers => 'Esperando jugadores...';

  @override
  String get minigamesScopeDirect => 'Directa';

  @override
  String get minigamesScopeGroup => 'Grupo';

  @override
  String get minigamesPlayDirect => 'Jugar directo';

  @override
  String get minigamesChangeGroup => 'Cambiar grupo';

  @override
  String get minigamesDirectEmpty => 'Aún no hay partidas directas';

  @override
  String get minigamesDirectEmptyBody =>
      'Crea una partida para jugar ya con un amigo, sin necesidad de un grupo.';

  @override
  String get minigamesErrorPlayerLimitReached =>
      'Esta partida alcanzó su límite de jugadores.';

  @override
  String get minigamesErrorInvalidRounds => 'El número de rondas no es válido.';

  @override
  String get minigamesErrorInvalidPrizePositions =>
      'El número de puestos premiados no es válido.';

  @override
  String get minigamesErrorInvalidPlayMode => 'El modo de juego no es válido.';

  @override
  String get minigamesErrorInvalidAsyncRounds =>
      'Las rondas por jugador no son válidas.';

  @override
  String get minigamesErrorInvalidAsyncEndsAt =>
      'La fecha de fin de la partida asíncrona no es válida.';

  @override
  String get minigamesErrorNotAllowed => 'No puedes unirte a esta partida.';

  @override
  String get minigamesInvitePendingBody => 'Te invitaron a esta partida.';

  @override
  String minigamesInviteFromDirect(String name) {
    return 'Invitado por $name';
  }

  @override
  String minigamesInviteFromGroup(String name) {
    return 'Grupo $name';
  }

  @override
  String minigamesGroupMessage(String game) {
    return 'Nueva partida de $game';
  }

  @override
  String get minigamesJoin => 'Unirse';

  @override
  String get minigamesView => 'Ver';

  @override
  String get minigamesInvitedBy => 'Invitado por';

  @override
  String get minigamesInviteAccept => 'Aceptar';

  @override
  String get minigamesInviteDecline => 'Rechazar';

  @override
  String get minigamesInviteAccepted => 'Te uniste a la partida';

  @override
  String get minigamesInviteDeclined => 'Invitación rechazada';

  @override
  String get minigamesInviteSent => 'Invitación enviada';

  @override
  String get minigamesInviteSentTag => 'enviada';

  @override
  String get minigamesInviteClosed =>
      'Esta partida ya terminó. Ya no puedes aceptar la invitación.';

  @override
  String get minigamesKickedTitle => '¡Oops!';

  @override
  String get minigamesInviteFriendsOnly => 'Solo amigos pueden invitarme';

  @override
  String get minigamesInviteFriendsOnlyBody =>
      'Cuando está activado, solo tus amigos pueden invitarte a un minijuego.';

  @override
  String get minigamesInviteFriendsOnlySaveError =>
      'No se pudo guardar la preferencia.';

  @override
  String get minigamesGoToGame => 'Ir a la partida';

  @override
  String get minigamesTwoLiesInstructions =>
      'Escribe 3 afirmaciones sobre ti: 2 mentiras y 1 verdad. Marca cuál es la verdad.';

  @override
  String minigamesTwoLiesStatementNumber(int number) {
    return 'Afirmación $number';
  }

  @override
  String get minigamesTwoLiesStatementPlaceholder =>
      'Escribe aquí la afirmación...';

  @override
  String get minigamesTwoLiesMarkTruth => 'Esta es la verdad';

  @override
  String get minigamesTwoLiesSubmitStatements => 'Enviar afirmaciones';

  @override
  String get minigamesTwoLiesGuessPrompt =>
      '¿Cuál de estas 3 afirmaciones es LA VERDAD?';

  @override
  String get minigamesTwoLiesVoteConfirm => 'Votar por esta opción';

  @override
  String get minigamesTwoLiesVoteConfirmed => 'Tu voto está registrado';

  @override
  String get minigamesTwoLiesTruthBadge => 'LA VERDAD';

  @override
  String get minigamesTwoLiesLieBadge => 'MENTIRA';

  @override
  String minigamesTwoLiesWaitingSubject(String name) {
    return '$name está escribiendo sus 3 afirmaciones...';
  }

  @override
  String minigamesTwoLiesWaitingVotes(int voted, int total) {
    return 'Esperando los votos de los demás... ($voted/$total)';
  }

  @override
  String get minigamesTwoLiesFillAllError =>
      'Debes completar las 3 afirmaciones';

  @override
  String get minigamesTwoLiesSelectTruthError =>
      'Debes marcar exactamente una afirmación como verdad';

  @override
  String get codeAlreadyAttendedReturn => 'Regresar';

  @override
  String get minigamesLeaderboardTitle => 'Clasificación';
}
