import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
  ];

  /// App brand name shown in the feed app bar
  ///
  /// In es, this message translates to:
  /// **'Samay'**
  String get appTitle;

  /// Generic confirmation button label
  ///
  /// In es, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Generic cancel button label
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// Generic accept button label
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get commonAccept;

  /// Generic reject button label
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get commonReject;

  /// Generic retry button label
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// Generic close button label
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// Generic create button label
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get commonCreate;

  /// Generic save button label
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get commonSave;

  /// Generic delete button label
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get commonDelete;

  /// Generic continue button label
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// Generic back button label
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// Email input field label
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get commonEmail;

  /// Password input field label
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get commonPassword;

  /// Confirm-password input field label
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get commonConfirmPassword;

  /// Username input field label
  ///
  /// In es, this message translates to:
  /// **'Nombre de usuario'**
  String get commonUsername;

  /// Generic fallback user display name
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get commonUser;

  /// Generic fallback group display name
  ///
  /// In es, this message translates to:
  /// **'Grupo'**
  String get commonGroup;

  /// Generic friends label
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get commonFriends;

  /// Create-account button label
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get commonCreateAccount;

  /// Sign-in button label
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get commonSignIn;

  /// Generic error dialog title
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get commonError;

  /// Generic invite button label
  ///
  /// In es, this message translates to:
  /// **'Invitar'**
  String get commonInvite;

  /// Welcome screen brand wordmark
  ///
  /// In es, this message translates to:
  /// **'VIVE'**
  String get welcomeVive;

  /// Welcome screen tagline
  ///
  /// In es, this message translates to:
  /// **'Tu vida social, en un solo lugar'**
  String get welcomeTagline;

  /// Age-gate screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Verificar edad'**
  String get authVerifyAge;

  /// Age-gate screen birth-date question
  ///
  /// In es, this message translates to:
  /// **'¿Cuál es tu fecha de nacimiento?'**
  String get authBirthDateQuestion;

  /// Age-gate minimum-age explanation
  ///
  /// In es, this message translates to:
  /// **'Debes tener al menos 18 años para usar Samay'**
  String get authMinAgeMessage;

  /// Age-gate date picker button label before a date is picked
  ///
  /// In es, this message translates to:
  /// **'Seleccionar fecha'**
  String get authSelectDate;

  /// Error shown when the picked birth date is under 18
  ///
  /// In es, this message translates to:
  /// **'Debes tener 18 años para usar Samay'**
  String get authUnderageMessage;

  /// Selected birth date rendered on the age-gate button
  ///
  /// In es, this message translates to:
  /// **'{day}/{month}/{year}'**
  String authSelectedDate(int day, int month, int year);

  /// Password-recovery link label
  ///
  /// In es, this message translates to:
  /// **'Olvidé mi contraseña'**
  String get authForgotPassword;

  /// Fallback message when login fails with no mapped error
  ///
  /// In es, this message translates to:
  /// **'Error desconocido al iniciar sesión'**
  String get authUnknownLoginError;

  /// OTP verification screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Verificar código'**
  String get authVerifyCode;

  /// OTP verification screen heading
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de verificación'**
  String get authEnterVerificationCode;

  /// Confirmation that the OTP was sent to the given email
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a {email}'**
  String authOtpSentTo(String email);

  /// Verify button label
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get authVerify;

  /// Resend-OTP button label once the cooldown has elapsed
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get authResendCode;

  /// Resend-OTP button label counting down the cooldown
  ///
  /// In es, this message translates to:
  /// **'Reenviar código ({seconds}s)'**
  String authResendCodeIn(int seconds);

  /// Blocking message after 5 consecutive wrong OTP attempts
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos fallidos. Solicita un nuevo código.'**
  String get authOtpTooManyAttempts;

  /// Dialog title when the email already has an account
  ///
  /// In es, this message translates to:
  /// **'Correo ya registrado'**
  String get authEmailAlreadyRegistered;

  /// Dialog body when the email already has an account
  ///
  /// In es, this message translates to:
  /// **'Este correo ya tiene una cuenta completa. Inicia sesión en su lugar.'**
  String get authEmailAlreadyRegisteredBody;

  /// Privacy/terms screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Términos y condiciones'**
  String get authTermsTitle;

  /// Privacy/terms screen heading
  ///
  /// In es, this message translates to:
  /// **'Acepta los términos para continuar'**
  String get authAcceptTermsToContinue;

  /// Privacy policy checkbox label
  ///
  /// In es, this message translates to:
  /// **'Acepto la Política de Privacidad'**
  String get authPrivacyPolicy;

  /// Privacy policy checkbox subtitle
  ///
  /// In es, this message translates to:
  /// **'Conoce cómo manejamos tus datos personales'**
  String get authPrivacyPolicySubtitle;

  /// Terms of service checkbox label
  ///
  /// In es, this message translates to:
  /// **'Acepto los Términos de Servicio'**
  String get authServiceTerms;

  /// Terms of service checkbox subtitle
  ///
  /// In es, this message translates to:
  /// **'Condiciones de uso de la aplicación'**
  String get authServiceTermsSubtitle;

  /// Profile-setup screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil'**
  String get authCompleteProfile;

  /// Username input placeholder
  ///
  /// In es, this message translates to:
  /// **'@usuario'**
  String get authUsernameHint;

  /// Warning that the username cannot be changed after signup
  ///
  /// In es, this message translates to:
  /// **'No podrás cambiar tu nombre de usuario después del registro.'**
  String get authUsernameImmutable;

  /// Signup screen heading
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get authCreateYourAccount;

  /// Signup screen subtitle
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo y crea una contraseña'**
  String get authSignupSubtitle;

  /// Password field label including the password requirements
  ///
  /// In es, this message translates to:
  /// **'Contraseña (mín. 6 caracteres, 1 número)'**
  String get authPasswordWithRequirements;

  /// Validation error for a weak password
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 6 caracteres y contener un número.'**
  String get authPasswordTooWeak;

  /// Validation error when the password confirmation differs
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get authPasswordsDontMatch;

  /// Ban screen title shown to suspended users
  ///
  /// In es, this message translates to:
  /// **'Cuenta suspendida'**
  String get bannedTitle;

  /// Ban screen body shown when no ban reason was stored
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta ha sido suspendida.'**
  String get bannedDefaultBody;

  /// Ban screen body including the stored ban reason
  ///
  /// In es, this message translates to:
  /// **'Motivo: {reason}'**
  String bannedReasonLabel(String reason);

  /// Feed screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Samay'**
  String get feedBrand;

  /// Feed screen welcome heading
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a Samay'**
  String get feedWelcome;

  /// Feed placeholder text
  ///
  /// In es, this message translates to:
  /// **'Tu feed aparecerá aquí.\nPronto podrás ver eventos cercanos y actividades de tus grupos.'**
  String get feedEmpty;

  /// Bottom navigation tab label
  ///
  /// In es, this message translates to:
  /// **'Feed'**
  String get shellFeed;

  /// Bottom navigation tab label
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get shellGroups;

  /// Bottom navigation tab label
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get shellEvents;

  /// Bottom navigation tab label
  ///
  /// In es, this message translates to:
  /// **'Notis'**
  String get shellNotifications;

  /// Bottom navigation tab label
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get shellProfile;

  /// Friends list screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get friendsTitle;

  /// Blocked users screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Usuarios bloqueados'**
  String get friendsBlockedTitle;

  /// Empty state when the user has not blocked anyone
  ///
  /// In es, this message translates to:
  /// **'No has bloqueado a nadie'**
  String get friendsNoneBlocked;

  /// Unblock button label
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get friendsUnblock;

  /// Search field hint on the friends list
  ///
  /// In es, this message translates to:
  /// **'Buscar entre amigos'**
  String get friendsSearchHint;

  /// Empty state heading when the user has no friends
  ///
  /// In es, this message translates to:
  /// **'Sin amigos aún'**
  String get friendsNoneYet;

  /// Empty state helper text prompting a user search
  ///
  /// In es, this message translates to:
  /// **'Busca usuarios para agregar amigos'**
  String get friendsSearchPrompt;

  /// Empty state when the friends filter matches nothing
  ///
  /// In es, this message translates to:
  /// **'No hay resultados'**
  String get friendsNoResults;

  /// Requests screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Solicitudes'**
  String get friendsRequestsTitle;

  /// Requests screen tab label
  ///
  /// In es, this message translates to:
  /// **'Recibidas'**
  String get friendsTabReceived;

  /// Requests screen tab label
  ///
  /// In es, this message translates to:
  /// **'Enviadas'**
  String get friendsTabSent;

  /// Requests screen tab label
  ///
  /// In es, this message translates to:
  /// **'Invitaciones'**
  String get friendsTabInvites;

  /// Empty state for the received-requests tab
  ///
  /// In es, this message translates to:
  /// **'Sin solicitudes recibidas'**
  String get friendsNoReceived;

  /// Empty state for the sent-requests tab
  ///
  /// In es, this message translates to:
  /// **'Sin solicitudes enviadas'**
  String get friendsNoSent;

  /// Subtitle for a received friend request
  ///
  /// In es, this message translates to:
  /// **'Te envió una solicitud'**
  String get friendsSentYouRequest;

  /// Subtitle for a sent friend request and snackbar after sending one
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get friendsRequestSent;

  /// Empty state for the group-invites tab
  ///
  /// In es, this message translates to:
  /// **'Sin invitaciones'**
  String get friendsNoInvites;

  /// User search screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Buscar usuarios'**
  String get friendsSearchUsers;

  /// Search field hint on the user search screen
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre de usuario'**
  String get friendsSearchPlaceholder;

  /// Empty state when the user search matches nothing
  ///
  /// In es, this message translates to:
  /// **'No se encontraron usuarios'**
  String get friendsNoUsersFound;

  /// Friendship status label for accepted friends
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get friendsStatusAccepted;

  /// Friendship status label for pending requests
  ///
  /// In es, this message translates to:
  /// **'Solicitado'**
  String get friendsStatusPending;

  /// Friendship status label for blocked users
  ///
  /// In es, this message translates to:
  /// **'Bloqueado'**
  String get friendsStatusBlocked;

  /// Send-friend-request button label
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get friendsAddFriendButton;

  /// My-groups screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get groupsTitle;

  /// Tooltip for the find-friends icon button
  ///
  /// In es, this message translates to:
  /// **'Buscar amigos'**
  String get groupsTooltipFindFriends;

  /// Create-group button label
  ///
  /// In es, this message translates to:
  /// **'Crear grupo'**
  String get groupsCreateGroup;

  /// Leaderboard button label
  ///
  /// In es, this message translates to:
  /// **'Ranking'**
  String get groupsRanking;

  /// Friend-requests shortcut button label
  ///
  /// In es, this message translates to:
  /// **'Solicitudes'**
  String get groupsRequests;

  /// Empty state heading when the user belongs to no group
  ///
  /// In es, this message translates to:
  /// **'No perteneces a ningún grupo'**
  String get groupsNoneYet;

  /// Empty state helper text on the my-groups screen
  ///
  /// In es, this message translates to:
  /// **'Crea un grupo o únete a uno existente'**
  String get groupsNoneYetSubtitle;

  /// Dialog title when the promotor group limit is reached
  ///
  /// In es, this message translates to:
  /// **'Límite alcanzado'**
  String get groupsLimitReached;

  /// Dialog body explaining the 5-group promotor limit
  ///
  /// In es, this message translates to:
  /// **'Has alcanzado el límite de 5 grupos como promotor. Actualiza tu suscripción para crear más.'**
  String get groupsLimitReachedBody;

  /// Snackbar after creating a group
  ///
  /// In es, this message translates to:
  /// **'Grupo creado'**
  String get groupsCreatedSnack;

  /// Cover photo placeholder label
  ///
  /// In es, this message translates to:
  /// **'Agregar foto de portada'**
  String get groupsAddCover;

  /// Group-name input label
  ///
  /// In es, this message translates to:
  /// **'Nombre del grupo'**
  String get groupsNameLabel;

  /// Optional group-description input label
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get groupsDescriptionOptional;

  /// Snackbar for an invalid donation amount
  ///
  /// In es, this message translates to:
  /// **'Ingresa un monto válido'**
  String get groupsInvalidAmount;

  /// Snackbar after a successful donation
  ///
  /// In es, this message translates to:
  /// **'Donación exitosa'**
  String get groupsDonationSuccess;

  /// Donate-shards screen app bar title and button label
  ///
  /// In es, this message translates to:
  /// **'Donar shards'**
  String get groupsDonateTitle;

  /// Donate screen heading naming the target group
  ///
  /// In es, this message translates to:
  /// **'Donar a {groupName}'**
  String groupsDonateTo(String groupName);

  /// Explanation of the donation boost window
  ///
  /// In es, this message translates to:
  /// **'Estos shards impulsarán el ranking del grupo durante 14 días'**
  String get groupsDonateBlurb;

  /// Donation amount input label
  ///
  /// In es, this message translates to:
  /// **'Cantidad de shards'**
  String get groupsShardsAmount;

  /// Donate button label
  ///
  /// In es, this message translates to:
  /// **'Donar'**
  String get groupsDonate;

  /// Group detail tab label
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get groupsTabChat;

  /// Group detail tab label
  ///
  /// In es, this message translates to:
  /// **'Miembros'**
  String get groupsTabMembers;

  /// Group detail tab label
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get groupsTabEvents;

  /// Menu item marking a frozen group
  ///
  /// In es, this message translates to:
  /// **'Grupo congelado'**
  String get groupsFrozenBadge;

  /// Leave-group menu item and dialog title
  ///
  /// In es, this message translates to:
  /// **'Abandonar grupo'**
  String get groupsLeave;

  /// Banner shown on a frozen group
  ///
  /// In es, this message translates to:
  /// **'Grupo congelado — actualiza tu suscripción o transfiere el rol de promotor'**
  String get groupsFrozenBanner;

  /// Group shard balance
  ///
  /// In es, this message translates to:
  /// **'{shards} shards de grupo'**
  String groupsShardsCount(int shards);

  /// Group member occupancy
  ///
  /// In es, this message translates to:
  /// **'{members} / {limit} miembros'**
  String groupsMemberCount(int members, int limit);

  /// Current user's active contribution to the group
  ///
  /// In es, this message translates to:
  /// **'Mi contribución: {shards} shards activos'**
  String groupsMyContribution(int shards);

  /// Create-event button label
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get groupsCreateEvent;

  /// Placeholder for the group chat tab
  ///
  /// In es, this message translates to:
  /// **'Chat próximamente'**
  String get groupsChatComingSoon;

  /// Empty state when a group has no members
  ///
  /// In es, this message translates to:
  /// **'No hay miembros'**
  String get groupsNoMembers;

  /// Section heading for the top contributors
  ///
  /// In es, this message translates to:
  /// **'Top contribuidores'**
  String get groupsTopContributors;

  /// Short shard count (contributor rows, group list)
  ///
  /// In es, this message translates to:
  /// **'{shards} shards'**
  String groupsShardsCountShort(int shards);

  /// Members section heading with the member count
  ///
  /// In es, this message translates to:
  /// **'Miembros ({count})'**
  String groupsMembersCount(int count);

  /// Placeholder for the group events tab
  ///
  /// In es, this message translates to:
  /// **'Eventos próximamente'**
  String get groupsEventsComingSoon;

  /// Leave-group confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro?'**
  String get groupsConfirmLeave;

  /// Confirm button on the leave-group dialog
  ///
  /// In es, this message translates to:
  /// **'Abandonar'**
  String get groupsAbandon;

  /// Error view message when the group detail fails to load
  ///
  /// In es, this message translates to:
  /// **'No se encontró el grupo'**
  String get groupsNotFound;

  /// Group members screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Miembros'**
  String get groupsMembersTitle;

  /// Invite screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Invitar'**
  String get groupsInviteTitle;

  /// Invite action button label with the number of selected users
  ///
  /// In es, this message translates to:
  /// **'Invitar ({count})'**
  String groupsInviteCount(int count);

  /// Snackbar confirming how many users were invited
  ///
  /// In es, this message translates to:
  /// **'{count} invitado(s)'**
  String groupsInvitedCount(int count);

  /// Search field hint on the invite screen
  ///
  /// In es, this message translates to:
  /// **'Buscar usuarios por username...'**
  String get groupsSearchUsersHint;

  /// Helper text before the search query is long enough
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 caracteres para buscar'**
  String get groupsMinCharsHint;

  /// Empty state when the invite search matches nothing
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get groupsNoResults;

  /// Leaderboard screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Ranking de grupos'**
  String get groupsLeaderboardTitle;

  /// Empty state when there is no ranking data
  ///
  /// In es, this message translates to:
  /// **'Sin datos de ranking'**
  String get groupsNoRankingData;

  /// Leaderboard row subtitle with member count and score
  ///
  /// In es, this message translates to:
  /// **'{count} miembros · {score} shards'**
  String groupsLeaderboardSubtitle(int count, int score);

  /// Profile screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profileTitle;

  /// Edit-profile screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditTitle;

  /// Settings screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get profileSettingsTitle;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get profileSubscription;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get profileNotifications;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Privacidad'**
  String get profilePrivacy;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Usuarios bloqueados'**
  String get profileBlockedUsers;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get profileDeleteMyAccount;

  /// Settings list item
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get profileSignOut;

  /// Version footer on the settings screen
  ///
  /// In es, this message translates to:
  /// **'Samay v1.0.0'**
  String get profileVersion;

  /// Bio input label
  ///
  /// In es, this message translates to:
  /// **'Biografía'**
  String get profileBio;

  /// Save-changes button label
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get profileSaveChanges;

  /// Change-password button label
  ///
  /// In es, this message translates to:
  /// **'Cambiar contraseña'**
  String get profileChangePassword;

  /// Snackbar after saving the profile
  ///
  /// In es, this message translates to:
  /// **'Perfil actualizado'**
  String get profileUpdatedSnack;

  /// Profile section heading
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get profileMyGroups;

  /// Empty state on the profile screen groups section
  ///
  /// In es, this message translates to:
  /// **'No perteneces a ningún grupo aún'**
  String get profileNoGroupsYet;

  /// Personal shard balance
  ///
  /// In es, this message translates to:
  /// **'{shards} shards'**
  String profileShardsCount(int shards);

  /// Preshard balance
  ///
  /// In es, this message translates to:
  /// **'{preshards} preshards'**
  String profilePreshardsCount(int preshards);

  /// Placeholder when a public profile has no bio
  ///
  /// In es, this message translates to:
  /// **'Sin biografía'**
  String get profileNoBio;

  /// Public profile section heading
  ///
  /// In es, this message translates to:
  /// **'Grupos compartidos'**
  String get profileSharedGroups;

  /// Empty state when there are no shared groups
  ///
  /// In es, this message translates to:
  /// **'Sin grupos en común'**
  String get profileNoSharedGroups;

  /// Snackbar after sending a friend request
  ///
  /// In es, this message translates to:
  /// **'Solicitud de amistad enviada'**
  String get profileFriendRequestSent;

  /// Snackbar after accepting a friend request
  ///
  /// In es, this message translates to:
  /// **'Solicitud aceptada'**
  String get profileRequestAccepted;

  /// Snackbar when accepting a friend request fails
  ///
  /// In es, this message translates to:
  /// **'Error al aceptar solicitud'**
  String get profileAcceptError;

  /// Report menu item
  ///
  /// In es, this message translates to:
  /// **'Reportar'**
  String get profileReport;

  /// Block menu item on the public profile screen
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get profileBlock;

  /// Button to cancel an outgoing friend request
  ///
  /// In es, this message translates to:
  /// **'Cancelar solicitud'**
  String get profileCancelRequest;

  /// Accept button label while the request is being accepted
  ///
  /// In es, this message translates to:
  /// **'Aceptando...'**
  String get profileAccepting;

  /// Button to accept an incoming friend request
  ///
  /// In es, this message translates to:
  /// **'Aceptar solicitud'**
  String get profileAcceptRequest;

  /// Send button label while the request is being sent
  ///
  /// In es, this message translates to:
  /// **'Enviando...'**
  String get profileSending;

  /// Button to send a friend request
  ///
  /// In es, this message translates to:
  /// **'Agregar amigo'**
  String get profileAddFriend;

  /// Snackbar stating that reporting is not implemented yet
  ///
  /// In es, this message translates to:
  /// **'Reportar será implementado próximamente'**
  String get profileReportComingSoon;

  /// Snackbar after blocking a user
  ///
  /// In es, this message translates to:
  /// **'Usuario bloqueado'**
  String get profileUserBlocked;

  /// Snackbar when blocking a user fails
  ///
  /// In es, this message translates to:
  /// **'Error al bloquear'**
  String get profileBlockError;

  /// Snackbar after unblocking a user
  ///
  /// In es, this message translates to:
  /// **'Usuario desbloqueado'**
  String get profileUserUnblocked;

  /// Snackbar when unblocking a user fails
  ///
  /// In es, this message translates to:
  /// **'Error al desbloquear'**
  String get profileUnblockError;

  /// Delete-account screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Eliminar cuenta'**
  String get profileDeleteTitle;

  /// Delete-account confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar cuenta?'**
  String get profileDeleteQuestion;

  /// Delete-account confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer. Tus datos serán anonimizados y tu cuenta será eliminada permanentemente después de 30 días.'**
  String get profileDeleteBody;

  /// Explanation of what happens when the account is deleted
  ///
  /// In es, this message translates to:
  /// **'Al eliminar tu cuenta, tus datos serán anonimizados. Tus mensajes y contribuciones al ranking de grupos se mantendrán pero no serán vinculados a ti. Podrás recuperar tu cuenta dentro de 30 días.'**
  String get profileDeleteExplanation;

  /// Prompt asking the user to confirm their email
  ///
  /// In es, this message translates to:
  /// **'Confirma tu correo electrónico para continuar:'**
  String get profileConfirmEmail;

  /// Snackbar when the confirmed email does not match
  ///
  /// In es, this message translates to:
  /// **'El correo no coincide con tu cuenta'**
  String get profileEmailMismatch;

  /// Profile screen section heading for cosmetics
  ///
  /// In es, this message translates to:
  /// **'Cosméticos'**
  String get profileCosmetics;

  /// Empty state on the profile cosmetics section
  ///
  /// In es, this message translates to:
  /// **'Tu armario de cosméticos aparecerá aquí.'**
  String get profileNoCosmeticsYet;

  /// Snackbar after updating the profile photo
  ///
  /// In es, this message translates to:
  /// **'Foto de perfil actualizada'**
  String get profileAvatarUpdatedSnack;

  /// Tooltip for the change-profile-photo button
  ///
  /// In es, this message translates to:
  /// **'Cambiar foto de perfil'**
  String get profileAvatarChange;

  /// Interest tag: music
  ///
  /// In es, this message translates to:
  /// **'Música'**
  String get interestMusica;

  /// Interest tag: parties
  ///
  /// In es, this message translates to:
  /// **'Fiestas'**
  String get interestFiestas;

  /// Interest tag: sports
  ///
  /// In es, this message translates to:
  /// **'Deportes'**
  String get interestDeportes;

  /// Interest tag: gaming
  ///
  /// In es, this message translates to:
  /// **'Gaming'**
  String get interestGaming;

  /// Interest tag: movies
  ///
  /// In es, this message translates to:
  /// **'Cine'**
  String get interestCine;

  /// Interest tag: art
  ///
  /// In es, this message translates to:
  /// **'Arte'**
  String get interestArte;

  /// Interest tag: travel
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get interestViajes;

  /// Interest tag: food
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get interestComida;

  /// Coming-soon placeholder headline
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get comingSoonSoon;

  /// Back button on the coming-soon screen
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get comingSoonBack;

  /// Coming-soon screen title for the events tab
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get comingSoonEventsTitle;

  /// Coming-soon screen body for the events tab
  ///
  /// In es, this message translates to:
  /// **'Los eventos de tus grupos aparecerán aquí pronto.'**
  String get comingSoonEventsBody;

  /// Coming-soon screen title for the notifications tab
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get comingSoonNotificationsTitle;

  /// Coming-soon screen body for the notifications tab
  ///
  /// In es, this message translates to:
  /// **'Tus notificaciones aparecerán aquí pronto.'**
  String get comingSoonNotificationsBody;

  /// Coming-soon screen title for the event detail
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get comingSoonEventTitle;

  /// Coming-soon screen body for the event detail
  ///
  /// In es, this message translates to:
  /// **'El detalle del evento estará disponible pronto.'**
  String get comingSoonEventBody;

  /// Coming-soon screen title for the event editor
  ///
  /// In es, this message translates to:
  /// **'Editar evento'**
  String get comingSoonEditEventTitle;

  /// Coming-soon screen body for the event editor
  ///
  /// In es, this message translates to:
  /// **'La edición de eventos estará disponible pronto.'**
  String get comingSoonEditEventBody;

  /// Coming-soon screen title for event invitations
  ///
  /// In es, this message translates to:
  /// **'Invitar'**
  String get comingSoonEventInviteTitle;

  /// Coming-soon screen body for event invitations
  ///
  /// In es, this message translates to:
  /// **'La invitación a eventos estará disponible pronto.'**
  String get comingSoonEventInviteBody;

  /// Coming-soon screen title for event photos
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get comingSoonPhotosTitle;

  /// Coming-soon screen body for event photos
  ///
  /// In es, this message translates to:
  /// **'Las fotos del evento estarán disponibles pronto.'**
  String get comingSoonPhotosBody;

  /// Coming-soon screen title for the photo collage
  ///
  /// In es, this message translates to:
  /// **'Collage'**
  String get comingSoonCollageTitle;

  /// Coming-soon screen body for the photo collage
  ///
  /// In es, this message translates to:
  /// **'El collage de fotos estará disponible pronto.'**
  String get comingSoonCollageBody;

  /// Coming-soon screen title for the invite-token landing
  ///
  /// In es, this message translates to:
  /// **'Invitación'**
  String get comingSoonInvitationTitle;

  /// Coming-soon screen body for the invite-token landing
  ///
  /// In es, this message translates to:
  /// **'Las invitaciones a eventos aparecerán aquí pronto.'**
  String get comingSoonInvitationBody;

  /// Coming-soon screen title for event creation
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get comingSoonCreateEventTitle;

  /// Coming-soon screen body for event creation
  ///
  /// In es, this message translates to:
  /// **'La creación de eventos estará disponible pronto.'**
  String get comingSoonCreateEventBody;

  /// Coming-soon screen title for the chat
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get comingSoonChatTitle;

  /// Coming-soon screen body for the chat
  ///
  /// In es, this message translates to:
  /// **'El chat estará disponible pronto.'**
  String get comingSoonChatBody;

  /// Coming-soon screen title for the QR code
  ///
  /// In es, this message translates to:
  /// **'QR'**
  String get comingSoonQrTitle;

  /// Coming-soon screen body for the QR code
  ///
  /// In es, this message translates to:
  /// **'El código QR del evento estará disponible pronto.'**
  String get comingSoonQrBody;

  /// Coming-soon screen title for the QR scanner
  ///
  /// In es, this message translates to:
  /// **'Escáner'**
  String get comingSoonScannerTitle;

  /// Coming-soon screen body for the QR scanner
  ///
  /// In es, this message translates to:
  /// **'El escáner de códigos QR estará disponible pronto.'**
  String get comingSoonScannerBody;

  /// Coming-soon screen title for subscriptions
  ///
  /// In es, this message translates to:
  /// **'Suscripciones'**
  String get comingSoonSubscriptionsTitle;

  /// Coming-soon screen body for subscriptions
  ///
  /// In es, this message translates to:
  /// **'Las suscripciones estarán disponibles pronto.'**
  String get comingSoonSubscriptionsBody;

  /// Coming-soon screen title for the party finder
  ///
  /// In es, this message translates to:
  /// **'Party Finder'**
  String get comingSoonPartyFinderTitle;

  /// Coming-soon screen body for the party finder
  ///
  /// In es, this message translates to:
  /// **'El Party Finder estará disponible pronto.'**
  String get comingSoonPartyFinderBody;

  /// Router error screen title for unknown routes
  ///
  /// In es, this message translates to:
  /// **'Ruta no encontrada'**
  String get routerRouteNotFound;

  /// Router error screen body for unknown routes
  ///
  /// In es, this message translates to:
  /// **'La ruta solicitada no existe o no está disponible. Vuelve e intenta de nuevo.'**
  String get routerRouteNotFoundBody;

  /// Router error when signup data is missing
  ///
  /// In es, this message translates to:
  /// **'Faltan los datos del registro. Vuelve e inicia el registro de nuevo.'**
  String get routerMissingSignupData;

  /// Router error when age-verification data is missing
  ///
  /// In es, this message translates to:
  /// **'Faltan los datos de la verificación de edad. Vuelve e intenta de nuevo.'**
  String get routerMissingAgeGateData;

  /// Router error when profile-setup data is missing
  ///
  /// In es, this message translates to:
  /// **'Faltan los datos del registro. Vuelve e intenta de nuevo.'**
  String get routerMissingProfileData;

  /// Router error when the requested event does not exist
  ///
  /// In es, this message translates to:
  /// **'No se encontró el evento solicitado.'**
  String get routerEventNotFound;

  /// Router error when the requested group does not exist
  ///
  /// In es, this message translates to:
  /// **'No se encontró el grupo solicitado.'**
  String get routerGroupNotFound;

  /// Router error when the requested chat does not exist
  ///
  /// In es, this message translates to:
  /// **'No se encontró el chat solicitado.'**
  String get routerChatNotFound;

  /// Router error when the requested user does not exist
  ///
  /// In es, this message translates to:
  /// **'No se encontró el usuario solicitado.'**
  String get routerUserNotFound;

  /// Router error when the requested invitation is invalid
  ///
  /// In es, this message translates to:
  /// **'La invitación solicitada no es válida.'**
  String get routerInvalidInvite;

  /// Generic route error screen title
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal'**
  String get routerErrorTitle;

  /// Generic route error screen body
  ///
  /// In es, this message translates to:
  /// **'No se pudo mostrar esta pantalla. Vuelve e intenta de nuevo.'**
  String get routerErrorBody;

  /// User-facing network error message
  ///
  /// In es, this message translates to:
  /// **'Error de conexión. Verifica tu internet.'**
  String get errorsNetwork;

  /// User-facing session-expired error message
  ///
  /// In es, this message translates to:
  /// **'Sesión expirada. Inicia sesión de nuevo.'**
  String get errorsUnauthorized;

  /// User-facing generic server error message
  ///
  /// In es, this message translates to:
  /// **'Error del servidor. Intenta de nuevo.'**
  String get errorsServer;

  /// User-facing invalid-data error message
  ///
  /// In es, this message translates to:
  /// **'Datos inválidos. Verifica los campos.'**
  String get errorsInvalidData;

  /// User-facing permission error message
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para realizar esta acción.'**
  String get errorsPermission;

  /// User-facing rate-limit error message
  ///
  /// In es, this message translates to:
  /// **'Demasiadas solicitudes. Espera un momento.'**
  String get errorsRateLimit;

  /// User-facing not-found message naming the missing resource
  ///
  /// In es, this message translates to:
  /// **'{resource} no encontrado.'**
  String errorsNotFound(String resource);

  /// User-facing generic not-found message
  ///
  /// In es, this message translates to:
  /// **'No encontrado.'**
  String get errorsNotFoundGeneric;

  /// User-facing invalid-credentials message
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña inválidos'**
  String get errorsInvalidCredentials;

  /// User-facing expired-OTP message
  ///
  /// In es, this message translates to:
  /// **'El código ha expirado. Solicita uno nuevo.'**
  String get errorsOtpExpired;

  /// User-facing invalid-reference message
  ///
  /// In es, this message translates to:
  /// **'Referencia inválida'**
  String get errorsInvalidReference;

  /// User-facing duplicate-record message
  ///
  /// In es, this message translates to:
  /// **'Ya existe'**
  String get errorsAlreadyExists;

  /// User-facing invalid-format message
  ///
  /// In es, this message translates to:
  /// **'Formato inválido'**
  String get errorsInvalidFormat;

  /// User-facing insufficient-shards message
  ///
  /// In es, this message translates to:
  /// **'No tienes suficientes shards'**
  String get errorsInsufficientShards;

  /// User-facing duplicate-friendship message
  ///
  /// In es, this message translates to:
  /// **'Ya existe una solicitud o amistad con este usuario'**
  String get errorsFriendshipExists;

  /// Generic error-presentation fallback message
  ///
  /// In es, this message translates to:
  /// **'Ha ocurrido un error'**
  String get errorsGeneric;

  /// Rank bracket label (90-100)
  ///
  /// In es, this message translates to:
  /// **'Full Vibe'**
  String get rankFullVibe;

  /// Rank bracket label (80-90)
  ///
  /// In es, this message translates to:
  /// **'Leyendas de la Vibra'**
  String get rankVibeLegends;

  /// Rank bracket label (60-80)
  ///
  /// In es, this message translates to:
  /// **'Creadores de la Vibra'**
  String get rankVibeCreators;

  /// Rank bracket label (40-60)
  ///
  /// In es, this message translates to:
  /// **'Seguidores de la Vibra'**
  String get rankVibeFollowers;

  /// Rank bracket label (20-40)
  ///
  /// In es, this message translates to:
  /// **'Buscadores de la Vibra'**
  String get rankVibeSeekers;

  /// Rank bracket label (0-20)
  ///
  /// In es, this message translates to:
  /// **'En la Búsqueda'**
  String get rankInSearch;

  /// Snackbar rationale when the photo-library permission is denied
  ///
  /// In es, this message translates to:
  /// **'Para elegir una foto de portada, Samay necesita acceso a tus fotos.'**
  String get permissionsPhotoRationale;

  /// Snackbar rationale when the camera permission is denied
  ///
  /// In es, this message translates to:
  /// **'Para escanear códigos QR y tomar fotos, Samay necesita acceso a tu cámara.'**
  String get permissionsCameraRationale;

  /// Dialog title when a permission is permanently denied
  ///
  /// In es, this message translates to:
  /// **'Permiso requerido'**
  String get permissionsSettingsTitle;

  /// Dialog body explaining that the permission must be enabled in system settings
  ///
  /// In es, this message translates to:
  /// **'Este permiso fue bloqueado por el sistema. Para usar esta función, actívalo desde los ajustes de tu dispositivo.'**
  String get permissionsSettingsBody;

  /// Dialog action that opens the system app settings
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get permissionsOpenSettings;

  /// Chat screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// Chat composer input hint
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje...'**
  String get chatInputHint;

  /// Chat send button label
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get chatSend;

  /// Placeholder for a message whose E2EE envelope could not be decrypted
  ///
  /// In es, this message translates to:
  /// **'Mensaje no descifrable'**
  String get chatUndecryptable;

  /// Empty state when a chat has no messages
  ///
  /// In es, this message translates to:
  /// **'No hay mensajes todavía'**
  String get chatEmpty;

  /// Error state when the message history fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los mensajes'**
  String get chatLoadError;

  /// Snackbar when sending a message fails
  ///
  /// In es, this message translates to:
  /// **'No se pudo enviar el mensaje'**
  String get chatSendError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
