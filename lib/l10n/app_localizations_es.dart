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
  String get welcomeVive => 'VIVE';

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
  String get feedBrand => 'Samay';

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
  String get feedNoEvents => 'No hay eventos próximos';

  @override
  String get feedNoEventsBody =>
      'Vuelve pronto para descubrir nuevos eventos cerca de ti.';

  @override
  String get feedLoadError => 'No se pudo cargar el feed';

  @override
  String get shellFeed => 'Feed';

  @override
  String get shellGroups => 'Grupos';

  @override
  String get shellSocial => 'Social';

  @override
  String get shellEvents => 'Eventos';

  @override
  String get shellNotifications => 'Notis';

  @override
  String get shellProfile => 'Perfil';

  @override
  String get friendsTitle => 'Amigos';

  @override
  String get friendsBlockedTitle => 'Usuarios bloqueados';

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
  String get friendsRequestsTitle => 'Solicitudes';

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
  String get friendsSearchUsers => 'Buscar usuarios';

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
  String get groupsCreateGroup => 'Crear grupo';

  @override
  String get groupsRanking => 'Ranking';

  @override
  String get groupsRequests => 'Solicitudes';

  @override
  String get socialTitle => 'Social';

  @override
  String get socialTabGroups => 'Grupos';

  @override
  String get socialTabFriends => 'Amigos';

  @override
  String get socialSearchTooltip => 'Buscar usuarios';

  @override
  String get socialRankingEntry => 'Ranking';

  @override
  String get socialRankingTitle => 'Ranking de usuarios';

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
      'Has alcanzado el límite de 5 grupos como promotor. Actualiza tu suscripción para crear más.';

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
  String get groupsDonateTitle => 'Donar shards';

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
      'Grupo congelado — actualiza tu suscripción o transfiere el rol de promotor';

  @override
  String groupsShardsCount(int shards) {
    return '$shards shards de grupo';
  }

  @override
  String groupsMemberCount(int members, int limit) {
    return '$members / $limit miembros';
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
  String get groupsPromoteCoPromotor => 'Hacer co-promotor';

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
  String get groupsMembersTitle => 'Miembros';

  @override
  String get groupsInviteTitle => 'Invitar';

  @override
  String groupsInviteCount(int count) {
    return 'Invitar ($count)';
  }

  @override
  String groupsInvitedCount(int count) {
    return '$count invitado(s)';
  }

  @override
  String get groupsSearchUsersHint => 'Buscar usuarios por username...';

  @override
  String get groupsMinCharsHint => 'Escribe al menos 2 caracteres para buscar';

  @override
  String get groupsNoResults => 'Sin resultados';

  @override
  String get groupsLeaderboardTitle => 'Ranking de grupos';

  @override
  String get groupsNoRankingData => 'Sin datos de ranking';

  @override
  String groupsLeaderboardSubtitle(int count, int score) {
    return '$count miembros · $score shards';
  }

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileSettingsTitle => 'Configuración';

  @override
  String get profileSubscription => 'Suscripción';

  @override
  String get profileNotifications => 'Notificaciones';

  @override
  String get profilePrivacy => 'Privacidad';

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
  String get settingsSectionAccount => 'Cuenta';

  @override
  String get settingsPrivacyPolicyBody =>
      'Tus datos personales se usan solo para operar Samay: autenticarte, mantener tus grupos y eventos y proteger a la comunidad. Nunca se venden ni se comparten con terceros con fines publicitarios.';

  @override
  String get settingsServiceTermsBody =>
      'Al usar Samay aceptas comportarte con respeto: nada de acoso, spam ni contenido inapropiado. El mal uso puede llevar a la suspensión de tu cuenta.';

  @override
  String get notificationSettingsTitle => 'Preferencias de notificaciones';

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
  String get profileDeleteTitle => 'Eliminar cuenta';

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
  String get routerErrorTitle => 'Algo salió mal';

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
  String get notificationsTitle => 'Notificaciones';

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
  String get chatTitle => 'Chat';

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
  String get chatInboxTitle => 'Chats';

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
      'El promotor aprueba cada solicitud';

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
  String get eventDetailTitle => 'Evento';

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
  String get eventPromotores => 'Promotores';

  @override
  String get eventRolePromotor => 'Promotor';

  @override
  String get eventRoleCoPromotor => 'Co-promotor';

  @override
  String get eventPromotoresError => 'No se pudieron cargar los promotores';

  @override
  String get eventNoPromotores => 'Sin promotores';

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
  String get eventEditButton => 'Editar';

  @override
  String get eventCancelButton => 'Cancelar evento';

  @override
  String get eventCancelDialogTitle => '¿Cancelar evento?';

  @override
  String get eventCancelDialogBody =>
      'Se devolverán los preshards a los promotores. Los invitados serán notificados.';

  @override
  String get eventCancelConfirm => 'Sí, cancelar';

  @override
  String get eventCancelledSnack => 'Evento cancelado';

  @override
  String get eventEditTitle => 'Editar evento';

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
  String get qrAttendanceTitle => 'Código de asistencia';

  @override
  String get qrEventLoadError => 'No se pudo cargar el evento.';

  @override
  String get qrTokenLoadError => 'No se pudo cargar el código QR.';

  @override
  String qrActivatesIn(int minutes) {
    return 'El código QR se activará $minutes minutos antes del evento';
  }

  @override
  String qrActivationCountdown(String time) {
    return 'Se activa en $time';
  }

  @override
  String qrNewCodeIn(int seconds) {
    return 'Nuevo código en: $seconds';
  }

  @override
  String get qrEventEnded =>
      'El evento ha finalizado. Ya no es necesario el código QR.';

  @override
  String get qrServerPending =>
      'No se pudo generar el código QR todavía. El servidor aún no está rotando tokens.';

  @override
  String get qrServerPendingBody =>
      'Si el problema continúa, presiona Reintentar.';

  @override
  String get qrUpdating => 'Actualizando código…';

  @override
  String get qrAttendeeExpired => 'El código QR expiró. Generando uno nuevo…';

  @override
  String get qrAttendeeExpiredBody =>
      'Si el problema continúa, presiona Reintentar.';

  @override
  String get qrScannerTitle => 'Escáner de asistencia';

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
  String get qrScanExpired =>
      'Código QR expirado. Pide al asistente que actualice su QR.';

  @override
  String get qrScanAlreadyScanned => 'Este código QR ya fue escaneado.';

  @override
  String get qrScanNotInvited => 'El usuario no está invitado a este evento.';

  @override
  String get qrScanNotInWindow =>
      'El evento no está activo para confirmación de asistencia.';

  @override
  String get qrScanNotPromotor =>
      'No tienes permisos para escanear en este evento.';

  @override
  String get qrScanInvalidToken => 'Código QR inválido.';

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
  String get partyFinderTitle => 'Party Finder';

  @override
  String get partyFinderOptInLabel => 'Aparecer en Party Finder';

  @override
  String get partyFinderOptInOff => 'Descubrimiento está apagado';

  @override
  String get partyFinderOptInOffBody =>
      'Activa el interruptor para aparecer en las coincidencias de otras personas. Nadie puede verte mientras esté apagado.';

  @override
  String get partyFinderEmpty => 'Aún no hay coincidencias';

  @override
  String get partyFinderEmptyBody =>
      'Agrega más intereses a tu perfil para encontrar personas afines.';

  @override
  String get partyFinderError => 'No se pudo cargar el Party Finder';

  @override
  String partyFinderSharedInterests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intereses en común',
      one: '1 interés en común',
    );
    return '$_temp0';
  }

  @override
  String get cosmeticsShopTitle => 'Tienda de cosméticos';

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
  String get minigamesTitle => 'Juegos';

  @override
  String get homeGamesTitle => 'Juegos';

  @override
  String get homePartyFinderBody =>
      'Encuentra personas que compartan tus intereses';

  @override
  String get minigamesChooseGroup => 'Elige un grupo';

  @override
  String get minigamesNoGroups => 'Aún no tienes grupos';

  @override
  String get minigamesNoGroupsBody =>
      'Únete o crea un grupo para jugar con tus amigos.';

  @override
  String get minigamesPickGame => 'Elige un juego';

  @override
  String get minigamesGamePokeChain => 'Cadena de Pokes';

  @override
  String get minigamesGamePokeChainTagline =>
      'Pasa el poke antes de que se acabe el tiempo';

  @override
  String get minigamesGameQuestions => 'Preguntas';

  @override
  String get minigamesGameQuestionsTagline =>
      'Responde desde el asiento caliente';

  @override
  String get minigamesGameTruthDare => 'Verdad o Reto';

  @override
  String get minigamesGameTruthDareTagline => 'Por turnos, sin escapatoria';

  @override
  String get minigamesGameDrunkBottle => 'Botella';

  @override
  String get minigamesGameDrunkBottleTagline =>
      'Gira la botella y veamos a quién apunta';

  @override
  String get minigamesGameChallenge => 'Retos';

  @override
  String get minigamesGameChallengeTagline =>
      'Completa el reto antes del límite';

  @override
  String get minigamesWagerLabel => 'Apuesta (shards)';

  @override
  String get minigamesWagerHint => '0 = sin apuesta';

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
  String minigamesParticipants(int count) {
    return 'Participantes: $count';
  }

  @override
  String minigamesWagerPerPerson(int amount) {
    return 'Apuesta: $amount shards';
  }

  @override
  String get minigamesDetailComingSoon => 'La partida se jugará aquí pronto.';

  @override
  String get shardsLedgerTitle => 'Historial de shards';

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
  String get eventsTabTitle => 'Mis eventos';

  @override
  String get eventsCreateCta => 'Crear evento';

  @override
  String get eventsCreateCtaBody =>
      'El evento se crea dentro de un grupo — elige uno en la pestaña Grupos.';

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
  String get collageTitle => 'Collage';

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
}
