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

  /// Accessibility tooltip for icon-only overflow menus
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get commonMoreOptions;

  /// Welcome screen brand wordmark
  ///
  /// In es, this message translates to:
  /// **'samay'**
  String get welcomeSamay;

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

  /// Sign in with Apple button label
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get authContinueWithApple;

  /// Google sign-in button label
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get authContinueWithGoogle;

  /// Divider between password and social sign-in options
  ///
  /// In es, this message translates to:
  /// **'o'**
  String get authOrDivider;

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

  /// Auth form validation: required field
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio.'**
  String get authFieldRequired;

  /// Auth form summary shown when validation marks one or more fields
  ///
  /// In es, this message translates to:
  /// **'Revisa los campos marcados.'**
  String get authCheckFields;

  /// OTP verification: submitted code is shorter than 6 digits
  ///
  /// In es, this message translates to:
  /// **'Ingresa los 6 dígitos del código.'**
  String get authOtpLengthError;

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

  /// Pre-auth funnel escape hatch: back to the login screen (OTP + forgot password)
  ///
  /// In es, this message translates to:
  /// **'Volver a iniciar sesión'**
  String get authBackToLogin;

  /// OTP wrong-attempt budget counter (I-29's guard, surfaced)
  ///
  /// In es, this message translates to:
  /// **'{attempts, plural, =1{Te queda 1 intento} other{Te quedan {attempts} intentos}}'**
  String authOtpAttemptsRemaining(int attempts);

  /// Forgot-password screen app bar title
  ///
  /// In es, this message translates to:
  /// **'Recuperar contraseña'**
  String get authForgotPasswordTitle;

  /// Forgot-password screen heading
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPasswordHeading;

  /// Forgot-password screen explainer
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.'**
  String get authForgotPasswordHint;

  /// Forgot-password submit button label
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get authForgotPasswordSend;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Define una nueva contraseña'**
  String get resetPasswordTitle;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Ingresa y confirma tu nueva contraseña. Usa al menos 8 caracteres.'**
  String get resetPasswordBody;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Nueva contraseña'**
  String get resetPasswordNew;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get resetPasswordConfirm;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Guardar contraseña'**
  String get resetPasswordSubmit;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get resetPasswordMismatch;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Usa al menos 8 caracteres.'**
  String get resetPasswordTooShort;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la contraseña. Vuelve a abrir el enlace de recuperación.'**
  String get resetPasswordError;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Tu contraseña fue actualizada.'**
  String get resetPasswordSuccess;

  /// Password recovery reset screen (D4/E3)
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get resetPasswordContinue;

  /// Forgot-password success state heading
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo'**
  String get authForgotPasswordSuccessTitle;

  /// Forgot-password success state body
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con {email}, recibirás un enlace para restablecer tu contraseña.'**
  String authForgotPasswordSuccessBody(String email);

  /// Snackbar after the recovery email is sent
  ///
  /// In es, this message translates to:
  /// **'Te enviamos un enlace para restablecer tu contraseña'**
  String get authForgotPasswordSnack;

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
  /// **'Contraseña (mín. 8 caracteres, 1 número)'**
  String get authPasswordWithRequirements;

  /// Validation error for a weak password
  ///
  /// In es, this message translates to:
  /// **'La contraseña debe tener al menos 8 caracteres y contener un número.'**
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
  /// **'samay'**
  String get feedBrand;

  /// Feed section heading for featured (promoted) events
  ///
  /// In es, this message translates to:
  /// **'Destacados'**
  String get feedFeatured;

  /// Badge on a featured event card
  ///
  /// In es, this message translates to:
  /// **'Destacado'**
  String get feedFeaturedBadge;

  /// Radius value label in kilometers (Events-tab distance slider)
  ///
  /// In es, this message translates to:
  /// **'{radius} km'**
  String feedRadiusKm(int radius);

  /// Empty agnostic feed state heading
  ///
  /// In es, this message translates to:
  /// **'Estás al día'**
  String get feedAllCaughtUp;

  /// Empty agnostic feed state body
  ///
  /// In es, this message translates to:
  /// **'Regresa más tarde'**
  String get feedComeBackLater;

  /// Badge on a feed minigame card when the user has a pending invite
  ///
  /// In es, this message translates to:
  /// **'Invitación'**
  String get feedMinigameInvite;

  /// Error state when the feed fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el feed'**
  String get feedLoadError;

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

  /// Bottom navigation tab label (Social tab — groups + friends)
  ///
  /// In es, this message translates to:
  /// **'Social'**
  String get shellSocial;

  /// Bottom navigation tab label (Games tab — plugged minigames)
  ///
  /// In es, this message translates to:
  /// **'Juegos'**
  String get shellGames;

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
  /// **'amigos'**
  String get friendsTitle;

  /// Blocked users screen app bar title
  ///
  /// In es, this message translates to:
  /// **'bloqueados'**
  String get friendsBlockedTitle;

  /// Empty state when the user has not blocked anyone
  ///
  /// In es, this message translates to:
  /// **'No has bloqueado a nadie'**
  String get friendsNoneBlocked;

  /// Shadow block (E3/E4)
  ///
  /// In es, this message translates to:
  /// **'Usuario bloqueado. ¿Desbloquear?'**
  String get profileBlockedUnblockPrompt;

  /// Shadow block (E3/E4)
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el chat.'**
  String get profileChatUnavailable;

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
  /// **'solicitudes'**
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
  /// **'buscar'**
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

  /// Botón que abre el chat directo E2EE con un amigo desde su perfil público
  ///
  /// In es, this message translates to:
  /// **'Mensaje'**
  String get profileMessage;

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

  /// Search hint shown while the query is shorter than 2 characters (R14)
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 5 caracteres para buscar'**
  String get friendsMinCharsHint;

  /// Mutual-friend dialog title when a friend request is accepted instantly (R15)
  ///
  /// In es, this message translates to:
  /// **'¡Solicitud aceptada!'**
  String get friendsMutualAcceptedTitle;

  /// Mutual-friend dialog body when a friend request is accepted instantly (R15)
  ///
  /// In es, this message translates to:
  /// **'Ambos se enviaron solicitud: ya son amigos.'**
  String get friendsMutualAcceptedBody;

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

  /// Create-group screen Header title (verbatim/lowercase)
  ///
  /// In es, this message translates to:
  /// **'crear'**
  String get groupsCreateGroup;

  /// Create-group action button label (Title Case)
  ///
  /// In es, this message translates to:
  /// **'Crear grupo'**
  String get groupsCreateGroupAction;

  /// Friend-requests shortcut button label
  ///
  /// In es, this message translates to:
  /// **'Solicitudes'**
  String get groupsRequests;

  /// Social tab screen app bar title
  ///
  /// In es, this message translates to:
  /// **'social'**
  String get socialTitle;

  /// Social screen inner pill tab label (groups sub-tab)
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get socialTabGroups;

  /// Social screen inner pill tab label (friends sub-tab)
  ///
  /// In es, this message translates to:
  /// **'Amigos'**
  String get socialTabFriends;

  /// Tooltip for the magnifier (search) icon button in the Amigos sub-tab
  ///
  /// In es, this message translates to:
  /// **'Buscar usuarios'**
  String get socialSearchTooltip;

  /// Amigos sub-tab entry that opens the global user ranking
  ///
  /// In es, this message translates to:
  /// **'Ranking'**
  String get socialRankingEntry;

  /// Global user ranking screen app bar title
  ///
  /// In es, this message translates to:
  /// **'ranking'**
  String get socialRankingTitle;

  /// Rankings screen Users | Groups switch — users segment
  ///
  /// In es, this message translates to:
  /// **'Usuarios'**
  String get rankingsUsers;

  /// Rankings screen Users | Groups switch — groups segment
  ///
  /// In es, this message translates to:
  /// **'Grupos'**
  String get rankingsGroups;

  /// Empty state when the user ranking has no entries
  ///
  /// In es, this message translates to:
  /// **'Aún no hay datos de ranking'**
  String get socialRankingEmpty;

  /// Neutral placeholder name on the global ranking when the profile is private and anonymize_names is on
  ///
  /// In es, this message translates to:
  /// **'Usuario'**
  String get socialCensoredName;

  /// Settings toggle label — lets the name/photo appear on the global user ranking
  ///
  /// In es, this message translates to:
  /// **'Perfil público'**
  String get socialPublicProfileLabel;

  /// Settings toggle helper text for the public-profile switch
  ///
  /// In es, this message translates to:
  /// **'Permite que tu nombre y foto aparezcan en el ranking global de usuarios'**
  String get socialPublicProfileBody;

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

  /// Dialog title when the host group limit is reached
  ///
  /// In es, this message translates to:
  /// **'Límite alcanzado'**
  String get groupsLimitReached;

  /// Dialog body explaining the 5-group host limit
  ///
  /// In es, this message translates to:
  /// **'Has alcanzado el límite de 5 grupos como host. Actualiza tu suscripción para crear más.'**
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
  /// **'donar'**
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

  /// Etiqueta de la pestaña Información del detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get groupsTabInfo;

  /// Etiqueta de pestaña del detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get groupsTabChat;

  /// Etiqueta de pestaña del detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Miembros'**
  String get groupsTabMembers;

  /// Etiqueta de pestaña del detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get groupsTabEvents;

  /// Insignia en la fila de un grupo cuya membresía es una invitación sin aceptar
  ///
  /// In es, this message translates to:
  /// **'Invitación pendiente'**
  String get groupsInvitePending;

  /// Título del estado de usuario invitado en el detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Invitación de grupo'**
  String get groupsInvitePendingTitle;

  /// Cuerpo del estado de usuario invitado en el detalle de grupo
  ///
  /// In es, this message translates to:
  /// **'Has sido invitado a este grupo. Acepta para unirte.'**
  String get groupsInvitePendingBody;

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
  /// **'Grupo congelado — actualiza tu suscripción o transfiere el rol de host'**
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

  /// Group detail: member count without the cap
  ///
  /// In es, this message translates to:
  /// **'{count} miembros'**
  String groupsMembersCountShort(int count);

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

  /// Group chat tab empty-state title explaining chats are 1:1 for now
  ///
  /// In es, this message translates to:
  /// **'Los chats son 1:1 por ahora'**
  String get groupsChatOneToOneTitle;

  /// Group chat tab empty-state body pointing to the messages list
  ///
  /// In es, this message translates to:
  /// **'Los chats de grupo se habilitan desde el listado de mensajes.'**
  String get groupsChatOneToOneBody;

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

  /// Group events tab empty state when the group has no events
  ///
  /// In es, this message translates to:
  /// **'Sin eventos en este grupo'**
  String get groupsEventsEmptyTitle;

  /// Group events tab empty-state body pointing at the create-event button
  ///
  /// In es, this message translates to:
  /// **'Crea el primer evento del grupo con el botón Crear evento.'**
  String get groupsEventsEmptyBody;

  /// Leave-group confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro?'**
  String get groupsConfirmLeave;

  /// Confirm button of the leave-group dialog
  ///
  /// In es, this message translates to:
  /// **'Abandonar'**
  String get groupsAbandon;

  /// Member-actions sheet option that promotes a member to staff (R17)
  ///
  /// In es, this message translates to:
  /// **'Hacer staff'**
  String get groupsPromoteStaff;

  /// Member-actions sheet option that demotes a staff to member (R17)
  ///
  /// In es, this message translates to:
  /// **'Hacer miembro'**
  String get groupsDemoteMember;

  /// Member-actions sheet option that kicks a member (R17)
  ///
  /// In es, this message translates to:
  /// **'Expulsar del grupo'**
  String get groupsKickMember;

  /// Kick-confirmation dialog title (R17)
  ///
  /// In es, this message translates to:
  /// **'¿Expulsar a {name}?'**
  String groupsKickConfirmTitle(String name);

  /// Kick-confirmation dialog body (R17)
  ///
  /// In es, this message translates to:
  /// **'Esta acción no se puede deshacer.'**
  String get groupsKickConfirmBody;

  /// Confirm button of the kick-confirmation dialog (R17)
  ///
  /// In es, this message translates to:
  /// **'Expulsar'**
  String get groupsKick;

  /// Error view message when the group detail fails to load
  ///
  /// In es, this message translates to:
  /// **'No se encontró el grupo'**
  String get groupsNotFound;

  /// Group members screen app bar title
  ///
  /// In es, this message translates to:
  /// **'miembros'**
  String get groupsMembersTitle;

  /// Invite screen app bar title
  ///
  /// In es, this message translates to:
  /// **'invitar'**
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
  /// **'Busca aquí...'**
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
  /// **'perfil'**
  String get profileTitle;

  /// Edit-profile screen app bar title
  ///
  /// In es, this message translates to:
  /// **'editar'**
  String get profileEditTitle;

  /// Settings screen app bar title
  ///
  /// In es, this message translates to:
  /// **'ajustes'**
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
  /// **'privacidad'**
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

  /// Sign-out confirmation dialog title (R7)
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get profileSignOutQuestion;

  /// Sign-out confirmation dialog body (R7)
  ///
  /// In es, this message translates to:
  /// **'Tu sesión se cerrará en este dispositivo.'**
  String get profileSignOutBody;

  /// Version footer on the settings screen
  ///
  /// In es, this message translates to:
  /// **'Samay v1.0.0'**
  String get profileVersion;

  /// Settings section label for the theme-mode picker
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// Theme picker option: always dark (the brand default)
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get settingsThemeDark;

  /// Theme picker option: follow the system appearance
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get settingsThemeSystem;

  /// Settings section header for the visual preferences group (R6)
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get settingsSectionAppearance;

  /// Settings section header for the chat preferences group
  ///
  /// In es, this message translates to:
  /// **'Chat'**
  String get settingsSectionChat;

  /// Settings section header for the minigames preferences group
  ///
  /// In es, this message translates to:
  /// **'Juegos'**
  String get settingsSectionGames;

  /// Settings section header for the account rows group (R6)
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get settingsSectionAccount;

  /// Settings row that wipes all local caches and signs out
  ///
  /// In es, this message translates to:
  /// **'Borrar datos locales'**
  String get settingsClearLocalData;

  /// Confirmation dialog title for clearing local data
  ///
  /// In es, this message translates to:
  /// **'¿Borrar datos locales?'**
  String get settingsClearLocalDataQuestion;

  /// Confirmation dialog body for clearing local data
  ///
  /// In es, this message translates to:
  /// **'Se cerrará tu sesión en este dispositivo y se borrarán los mensajes, notificaciones, fotos y preferencias guardados localmente. Tu cuenta no se elimina.'**
  String get settingsClearLocalDataBody;

  /// Snackbar after local data has been cleared
  ///
  /// In es, this message translates to:
  /// **'Datos locales borrados'**
  String get settingsClearLocalDataDone;

  /// Generic local-notification title (no server content)
  ///
  /// In es, this message translates to:
  /// **'Samay'**
  String get pushGenericTitle;

  /// Generic local-notification body (no server content)
  ///
  /// In es, this message translates to:
  /// **'Nueva actividad en Samay'**
  String get pushGenericBody;

  /// Static privacy-policy body on the privacy info screen
  ///
  /// In es, this message translates to:
  /// **'Tus datos personales se usan solo para operar Samay: autenticarte, mantener tus grupos y eventos y proteger a la comunidad. Nunca se venden ni se comparten con terceros con fines publicitarios.'**
  String get settingsPrivacyPolicyBody;

  /// Static service-terms body on the privacy info screen
  ///
  /// In es, this message translates to:
  /// **'Al usar Samay aceptas comportarte con respeto: nada de acoso, spam ni contenido inapropiado. El mal uso puede llevar a la suspensión de tu cuenta.'**
  String get settingsServiceTermsBody;

  /// Notification-settings screen app bar title
  ///
  /// In es, this message translates to:
  /// **'preferencias de notis'**
  String get notificationSettingsTitle;

  /// Footer explaining notification preferences are stored locally
  ///
  /// In es, this message translates to:
  /// **'Estas preferencias se guardan en este dispositivo.'**
  String get notificationSettingsLocalNote;

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

  /// Empty-state hint on the profile screen groups section (R9)
  ///
  /// In es, this message translates to:
  /// **'Crea o únete a un grupo para verlo aquí.'**
  String get profileNoGroupsHint;

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

  /// Title of the report-user dialog
  ///
  /// In es, this message translates to:
  /// **'Reportar usuario'**
  String get profileReportTitle;

  /// Report reason option for harassment or abuse
  ///
  /// In es, this message translates to:
  /// **'Acoso o abuso'**
  String get profileReportReasonHarassment;

  /// Report reason option for spam
  ///
  /// In es, this message translates to:
  /// **'Spam'**
  String get profileReportReasonSpam;

  /// Report reason option for inappropriate content
  ///
  /// In es, this message translates to:
  /// **'Contenido inapropiado'**
  String get profileReportReasonInappropriate;

  /// Report reason option for any other reason
  ///
  /// In es, this message translates to:
  /// **'Otro motivo'**
  String get profileReportReasonOther;

  /// Snackbar confirming that the report was submitted
  ///
  /// In es, this message translates to:
  /// **'Gracias por reportar. Lo revisaremos pronto.'**
  String get profileReportSent;

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
  /// **'eliminar'**
  String get profileDeleteTitle;

  /// Delete-account confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar cuenta?'**
  String get profileDeleteQuestion;

  /// Delete-account confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'Esta acción es inmediata e irreversible. Se eliminan tu cuenta, perfil, credenciales, contenido y tokens. Solo se conservan los registros pseudonimizados de shards y asistencia (5 años) y la evidencia restringida de reportes (2 años; contenido ilegal según ley). No hay periodo de recuperación.'**
  String get profileDeleteBody;

  /// Explanation of what happens when the account is deleted
  ///
  /// In es, this message translates to:
  /// **'Al eliminar tu cuenta se borran de inmediato tu perfil, credenciales, contenido, amistades, membresías y tokens. Se conservan únicamente los registros pseudonimizados de shards/asistencia (5 años) y la evidencia restringida de reportes (2 años; contenido ilegal según ley). No existe una ventana de recuperación.'**
  String get profileDeleteExplanation;

  /// Immediate erasure button label
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta definitivamente'**
  String get profileDeleteNowLabel;

  /// Immediate erasure explanation
  ///
  /// In es, this message translates to:
  /// **'Se borran tu perfil, credenciales, contenido y tokens. Solo quedan registros pseudonimizados de shards/asistencia (5 años) y evidencia restringida de reportes (2 años; contenido ilegal según ley). No se puede deshacer.'**
  String get profileDeleteNowBody;

  /// Immediate erasure confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar tu cuenta definitivamente?'**
  String get profileDeleteNowQuestion;

  /// Settings row to export the user's data
  ///
  /// In es, this message translates to:
  /// **'Exportar mis datos'**
  String get profileExportData;

  /// Export screen app bar title
  ///
  /// In es, this message translates to:
  /// **'exportar'**
  String get profileExportTitle;

  /// Export screen explanation
  ///
  /// In es, this message translates to:
  /// **'Guarda una copia de tu perfil, amistades, grupos, eventos, shards, mensajes recibidos (texto cifrado), respuestas de minijuegos, tokens de dispositivo y reportes.'**
  String get profileExportBody;

  /// E2EE caveat on the export screen
  ///
  /// In es, this message translates to:
  /// **'El chat está cifrado de extremo a extremo: el servidor solo puede exportar texto cifrado. Las llaves E2EE y la evidencia de moderación no se exportan; el documento incluye la lista de exclusiones y la matriz de retención.'**
  String get profileExportChatNote;

  /// Export action button
  ///
  /// In es, this message translates to:
  /// **'Generar archivo'**
  String get profileExportCta;

  /// Copy export JSON to clipboard
  ///
  /// In es, this message translates to:
  /// **'Copiar al portapapeles'**
  String get profileExportCopy;

  /// Export success message
  ///
  /// In es, this message translates to:
  /// **'Exportación guardada en el dispositivo y copiada al portapapeles.'**
  String get profileExportSuccess;

  /// Export failure message
  ///
  /// In es, this message translates to:
  /// **'No se pudo exportar. Inténtalo de nuevo.'**
  String get profileExportError;

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

  /// Paywall screen heading
  ///
  /// In es, this message translates to:
  /// **'Suscripción'**
  String get paywallHeader;

  /// Paywall compliance note: all tiers visible (App Store)
  ///
  /// In es, this message translates to:
  /// **'Todos los planes son visibles sin precios ocultos. Elige el que mejor se adapte a ti.'**
  String get paywallAllTiersVisible;

  /// Free tier name
  ///
  /// In es, this message translates to:
  /// **'Free'**
  String get paywallTierFree;

  /// PRO tier name
  ///
  /// In es, this message translates to:
  /// **'PRO'**
  String get paywallTierPro;

  /// VIP tier name
  ///
  /// In es, this message translates to:
  /// **'VIP'**
  String get paywallTierVip;

  /// Monthly price suffix
  ///
  /// In es, this message translates to:
  /// **'/mes'**
  String get paywallPerMonth;

  /// Billing-period toggle: monthly option
  ///
  /// In es, this message translates to:
  /// **'Mensual'**
  String get paywallBillingMonthly;

  /// Billing-period toggle: annual option
  ///
  /// In es, this message translates to:
  /// **'Anual'**
  String get paywallBillingAnnual;

  /// Annual option shown as the monthly equivalent with the computed savings percent
  ///
  /// In es, this message translates to:
  /// **'{monthly} ahorrando {percent}%'**
  String paywallAnnualEquivalent(String monthly, String percent);

  /// Badge marking the user's current tier
  ///
  /// In es, this message translates to:
  /// **'Actual'**
  String get paywallCurrentBadge;

  /// Restore-purchases button label
  ///
  /// In es, this message translates to:
  /// **'Restaurar compras'**
  String get paywallRestore;

  /// Upgrade-to-PRO button label
  ///
  /// In es, this message translates to:
  /// **'Actualizar a PRO'**
  String get paywallUpgradePro;

  /// Upgrade-to-VIP button label
  ///
  /// In es, this message translates to:
  /// **'Actualizar a VIP'**
  String get paywallUpgradeVip;

  /// Tier comparison feature row: events per day
  ///
  /// In es, this message translates to:
  /// **'Eventos por día'**
  String get paywallRowEvents;

  /// Tier comparison feature row: maximum groups
  ///
  /// In es, this message translates to:
  /// **'Grupos máximos'**
  String get paywallRowGroups;

  /// Tier comparison feature row: members per group
  ///
  /// In es, this message translates to:
  /// **'Miembros por grupo'**
  String get paywallRowMembers;

  /// Tier comparison feature row: monthly preshards
  ///
  /// In es, this message translates to:
  /// **'Preshards mensuales'**
  String get paywallRowPreshards;

  /// Tier comparison feature row: group cosmetics
  ///
  /// In es, this message translates to:
  /// **'Cosméticos de grupo'**
  String get paywallRowCosmetics;

  /// Tier comparison feature row: group rank
  ///
  /// In es, this message translates to:
  /// **'Rango de grupo'**
  String get paywallRowRank;

  /// Tier comparison cell value: unlimited
  ///
  /// In es, this message translates to:
  /// **'Ilimitado'**
  String get paywallUnlimited;

  /// Tier comparison cell value: limited
  ///
  /// In es, this message translates to:
  /// **'Limitado'**
  String get paywallLimited;

  /// Tier comparison cell value: full cosmetics
  ///
  /// In es, this message translates to:
  /// **'Completo'**
  String get paywallCosmeticsFull;

  /// Tier comparison cell value: full + exclusive cosmetics
  ///
  /// In es, this message translates to:
  /// **'Completo + exclusivos'**
  String get paywallCosmeticsFullExclusive;

  /// Tier comparison cell value: micro rank bracket
  ///
  /// In es, this message translates to:
  /// **'micro'**
  String get paywallRankMicro;

  /// Tier comparison cell value: up to the medium rank bracket
  ///
  /// In es, this message translates to:
  /// **'hasta medium'**
  String get paywallRankUpToMedium;

  /// Tier comparison cell value: all rank brackets
  ///
  /// In es, this message translates to:
  /// **'todos'**
  String get paywallRankAll;

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
  /// **'ups'**
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

  /// User-facing unconfirmed-email message
  ///
  /// In es, this message translates to:
  /// **'Correo no confirmado. Revisa tu bandeja de entrada.'**
  String get errorsEmailNotConfirmed;

  /// User-facing invalid-email message
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico inválido.'**
  String get errorsInvalidEmail;

  /// User-facing same-password message
  ///
  /// In es, this message translates to:
  /// **'Debes elegir una contraseña diferente.'**
  String get errorsSamePassword;

  /// User-facing disabled-OTP message
  ///
  /// In es, this message translates to:
  /// **'El inicio de sesión con código está deshabilitado.'**
  String get errorsOtpDisabled;

  /// User-facing banned-account message
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta está suspendida.'**
  String get errorsUserBanned;

  /// User-facing reauthentication-required message
  ///
  /// In es, this message translates to:
  /// **'Vuelve a autenticarte para continuar.'**
  String get errorsReauthenticationNeeded;

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

  /// User-facing invalid/expired-OTP message (GoTrue answers every rejected code with otp_expired)
  ///
  /// In es, this message translates to:
  /// **'El código es incorrecto o ha expirado. Solicita uno nuevo.'**
  String get errorsOtpInvalid;

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

  /// Label prefixing the stable machine-readable error code on error popups and snackbars
  ///
  /// In es, this message translates to:
  /// **'Código de error'**
  String get errorCodeLabel;

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

  /// Event photo gallery app bar title
  ///
  /// In es, this message translates to:
  /// **'Fotos'**
  String get photosTitle;

  /// Empty state heading when the event has no photos
  ///
  /// In es, this message translates to:
  /// **'No hay fotos todavía'**
  String get photosEmpty;

  /// Empty state helper text prompting the first photo upload
  ///
  /// In es, this message translates to:
  /// **'¡Sé el primero en subir una!'**
  String get photosEmptyBody;

  /// Photo upload button label
  ///
  /// In es, this message translates to:
  /// **'Subir foto'**
  String get photosUpload;

  /// Snackbar rationale when the photo-library permission is denied
  ///
  /// In es, this message translates to:
  /// **'Para subir fotos del evento, Samay necesita acceso a tus fotos.'**
  String get photosPermissionRationale;

  /// Snackbar after a successful photo upload
  ///
  /// In es, this message translates to:
  /// **'Foto subida'**
  String get photosUploadedSnack;

  /// Notice shown when the post-event photo upload window has closed
  ///
  /// In es, this message translates to:
  /// **'La ventana de subida de fotos ya cerró'**
  String get photosUploadWindowClosed;

  /// Like count on a photo tile
  ///
  /// In es, this message translates to:
  /// **'{count} likes'**
  String photosLikesCount(int count);

  /// Tooltip for the like button on a photo tile
  ///
  /// In es, this message translates to:
  /// **'Me gusta'**
  String get photosLikeTooltip;

  /// Long-press report dialog title
  ///
  /// In es, this message translates to:
  /// **'Reportar foto'**
  String get photosReportTitle;

  /// Long-press report dialog body
  ///
  /// In es, this message translates to:
  /// **'Describe por qué quieres reportar esta foto. El equipo de moderación la revisará.'**
  String get photosReportBody;

  /// Long-press report dialog reason input hint
  ///
  /// In es, this message translates to:
  /// **'Escribe el motivo (opcional)'**
  String get photosReportHint;

  /// Long-press report dialog submit button
  ///
  /// In es, this message translates to:
  /// **'Enviar reporte'**
  String get photosReportSubmit;

  /// Snackbar after submitting a photo report
  ///
  /// In es, this message translates to:
  /// **'Reporte enviado'**
  String get photosReportSent;

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

  /// Notification center app bar title
  ///
  /// In es, this message translates to:
  /// **'notis'**
  String get notificationsTitle;

  /// Notification preference toggle: event reminders
  ///
  /// In es, this message translates to:
  /// **'Recordatorios de eventos'**
  String get notificationSettingsEventReminders;

  /// Notification preference toggle: friend requests
  ///
  /// In es, this message translates to:
  /// **'Solicitudes de amistad'**
  String get notificationSettingsFriendRequests;

  /// Notification preference toggle: chat messages
  ///
  /// In es, this message translates to:
  /// **'Mensajes de chat'**
  String get notificationSettingsChatMessages;

  /// Notification preference toggle: shards and ranking updates
  ///
  /// In es, this message translates to:
  /// **'Shards y ranking'**
  String get notificationSettingsShardsRank;

  /// Empty state when the user has no notifications
  ///
  /// In es, this message translates to:
  /// **'Sin notificaciones'**
  String get notificationsEmpty;

  /// Empty-state body explaining where new notifications appear
  ///
  /// In es, this message translates to:
  /// **'Cuando recibas novedades, aparecerán aquí.'**
  String get notificationsEmptyBody;

  /// App-bar action that marks every notification as read
  ///
  /// In es, this message translates to:
  /// **'Marcar todo como leído'**
  String get notificationsMarkAllRead;

  /// Error state when the notification history fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las notificaciones'**
  String get notificationsLoadError;

  /// Relative timestamp for a notification created under a minute ago
  ///
  /// In es, this message translates to:
  /// **'Ahora'**
  String get notificationsTimeNow;

  /// Relative timestamp in minutes
  ///
  /// In es, this message translates to:
  /// **'hace {minutes} min'**
  String notificationsTimeMinutes(int minutes);

  /// Relative timestamp in hours
  ///
  /// In es, this message translates to:
  /// **'hace {hours} h'**
  String notificationsTimeHours(int hours);

  /// Relative timestamp in days
  ///
  /// In es, this message translates to:
  /// **'hace {days} d'**
  String notificationsTimeDays(int days);

  /// Chat screen app bar title
  ///
  /// In es, this message translates to:
  /// **'chat'**
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

  /// Long-press action: delete the message for everyone (sender only, 5-minute window)
  ///
  /// In es, this message translates to:
  /// **'Eliminar para todos'**
  String get chatDeleteForEveryone;

  /// Long-press action: hide the message on this device only
  ///
  /// In es, this message translates to:
  /// **'Eliminar para mí'**
  String get chatDeleteForMe;

  /// Snackbar when delete-for-everyone is attempted past the 5-minute window
  ///
  /// In es, this message translates to:
  /// **'Solo puedes eliminar mensajes enviados hace menos de 5 minutos'**
  String get chatDeleteTooOld;

  /// Snackbar when a message deletion fails
  ///
  /// In es, this message translates to:
  /// **'No se pudo eliminar el mensaje'**
  String get chatDeleteFailed;

  /// Notice shown once per peer when their published identity changed (reinstall)
  ///
  /// In es, this message translates to:
  /// **'El otro usuario reinstaló la app o cambió de dispositivo'**
  String get chatPeerReinstalled;

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

  /// Button that loads the previous page of older messages
  ///
  /// In es, this message translates to:
  /// **'Cargar anteriores'**
  String get chatLoadOlder;

  /// Inbox / chat list screen title (also the feed button tooltip)
  ///
  /// In es, this message translates to:
  /// **'chats'**
  String get chatInboxTitle;

  /// Empty state title when the inbox has no chats
  ///
  /// In es, this message translates to:
  /// **'No hay conversaciones'**
  String get chatInboxEmpty;

  /// Empty state body explaining how to start a chat
  ///
  /// In es, this message translates to:
  /// **'Toca \'Enviar mensaje\' en el perfil de alguien para iniciar un chat.'**
  String get chatInboxEmptyBody;

  /// Error state when the inbox fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los chats'**
  String get chatInboxLoadError;

  /// Prefix for the preview of a chat whose last message the user sent
  ///
  /// In es, this message translates to:
  /// **'Tú: '**
  String get chatInboxPreviewOwn;

  /// Relative time label for something that just happened
  ///
  /// In es, this message translates to:
  /// **'ahora'**
  String get commonNow;

  /// Date separator chip label for messages sent today
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get commonToday;

  /// Date separator chip label for messages sent yesterday
  ///
  /// In es, this message translates to:
  /// **'Ayer'**
  String get commonYesterday;

  /// Settings row: WhatsApp-style read receipts privacy switch
  ///
  /// In es, this message translates to:
  /// **'Confirmaciones de lectura'**
  String get chatReadReceipts;

  /// Settings row subtitle explaining the read-receipts switch
  ///
  /// In es, this message translates to:
  /// **'Si está desactivado, tus mensajes nunca se marcan como leídos.'**
  String get chatReadReceiptsBody;

  /// Snackbar when persisting the read-receipts switch fails
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar las confirmaciones de lectura'**
  String get chatReadReceiptsSaveError;

  /// Semantics label for a message that was sent but not yet confirmed
  ///
  /// In es, this message translates to:
  /// **'Enviado'**
  String get chatSent;

  /// Semantics label for a message delivered but not yet read
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get chatReceived;

  /// Semantics label for a message the peer has read
  ///
  /// In es, this message translates to:
  /// **'Leído'**
  String get chatRead;

  /// Event creation: type selector section label
  ///
  /// In es, this message translates to:
  /// **'Tipo de evento'**
  String get eventsTypeLabel;

  /// Event type chip: casual (movies, dinner, informal)
  ///
  /// In es, this message translates to:
  /// **'Casual'**
  String get eventsTypeCasual;

  /// Event type chip helper text for casual events
  ///
  /// In es, this message translates to:
  /// **'Películas, cenas, informales — sin preshards'**
  String get eventsTypeCasualDescription;

  /// Event type chip: juerga (private venue)
  ///
  /// In es, this message translates to:
  /// **'Juerga'**
  String get eventsTypeJuerga;

  /// Event type chip helper text for juerga events
  ///
  /// In es, this message translates to:
  /// **'Local privado — los invitados verán la dirección'**
  String get eventsTypeJuergaDescription;

  /// Event type chip: tono (public venue, bar or club)
  ///
  /// In es, this message translates to:
  /// **'Tono'**
  String get eventsTypeTono;

  /// Event type chip helper text for tono events
  ///
  /// In es, this message translates to:
  /// **'Bar, club o local público'**
  String get eventsTypeTonoDescription;

  /// Event creation: event-name input label
  ///
  /// In es, this message translates to:
  /// **'Nombre del evento'**
  String get eventsNameLabel;

  /// Event creation: optional description input label
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get eventsDescriptionOptional;

  /// Event creation: start date/time picker label
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get eventsStartsLabel;

  /// Event creation: end date/time picker label
  ///
  /// In es, this message translates to:
  /// **'Fin'**
  String get eventsEndsLabel;

  /// Event creation: location address input label
  ///
  /// In es, this message translates to:
  /// **'Dirección / lugar'**
  String get eventsLocationLabel;

  /// Event creation: visibility section label
  ///
  /// In es, this message translates to:
  /// **'Visibilidad'**
  String get eventsVisibilityLabel;

  /// Event creation: public visibility chip
  ///
  /// In es, this message translates to:
  /// **'Público'**
  String get eventsVisibilityPublic;

  /// Event creation: group-scoped visibility chip
  ///
  /// In es, this message translates to:
  /// **'Grupo'**
  String get eventsVisibilityGroup;

  /// Event creation: group dropdown label
  ///
  /// In es, this message translates to:
  /// **'Grupo del evento'**
  String get eventsGroupSelectorLabel;

  /// Event creation: group dropdown placeholder
  ///
  /// In es, this message translates to:
  /// **'Selecciona un grupo'**
  String get eventsGroupSelectorHint;

  /// Event creation: error when the user's groups fail to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar tus grupos'**
  String get eventsGroupsLoadError;

  /// Event creation: join mode section label (public events)
  ///
  /// In es, this message translates to:
  /// **'Modo de acceso'**
  String get eventsJoinModeLabel;

  /// Event creation: open join mode chip
  ///
  /// In es, this message translates to:
  /// **'Abierto'**
  String get eventsJoinModeOpen;

  /// Event creation: open join mode helper text
  ///
  /// In es, this message translates to:
  /// **'Cualquiera con el enlace de invitación puede unirse'**
  String get eventsJoinModeOpenDescription;

  /// Event creation: approval join mode chip
  ///
  /// In es, this message translates to:
  /// **'Aprobación'**
  String get eventsJoinModeApproval;

  /// Event creation: approval join mode helper text
  ///
  /// In es, this message translates to:
  /// **'El host aprueba cada solicitud'**
  String get eventsJoinModeApprovalDescription;

  /// Juerga location warning dialog title
  ///
  /// In es, this message translates to:
  /// **'Aviso de ubicación'**
  String get eventsJuergaWarningTitle;

  /// Juerga location warning dialog body (ECRT step 4)
  ///
  /// In es, this message translates to:
  /// **'Los invitados verán esta dirección. Solo invita a personas en quienes confíes.'**
  String get eventsJuergaWarningBody;

  /// Juerga location warning confirm button
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get eventsJuergaWarningConfirm;

  /// Event creation: preshards section label
  ///
  /// In es, this message translates to:
  /// **'Preshards'**
  String get eventsPreshardsLabel;

  /// Event creation: preshards pool input label
  ///
  /// In es, this message translates to:
  /// **'Pool de preshards'**
  String get eventsPreshardsPoolLabel;

  /// Event creation: per-attendee preshards cap input label
  ///
  /// In es, this message translates to:
  /// **'Tope por asistente (opcional)'**
  String get eventsPreshardsCapLabel;

  /// Event creation: remainder action section label
  ///
  /// In es, this message translates to:
  /// **'Resto del pool'**
  String get eventsRemainderLabel;

  /// Event creation: return remainder proportionally option
  ///
  /// In es, this message translates to:
  /// **'Devolver proporcionalmente'**
  String get eventsRemainderReturn;

  /// Event creation: redistribute remainder option
  ///
  /// In es, this message translates to:
  /// **'Redistribuir entre asistentes'**
  String get eventsRemainderRedistribute;

  /// Event creation: dynamic QR auto-enable hint
  ///
  /// In es, this message translates to:
  /// **'Con pool mayor a 0, el QR dinámico se activa automáticamente'**
  String get eventsDynamicQrHint;

  /// Validation error: event name is required
  ///
  /// In es, this message translates to:
  /// **'El nombre del evento es obligatorio'**
  String get eventsErrorNameRequired;

  /// Validation error: end date must be after start date
  ///
  /// In es, this message translates to:
  /// **'La fecha de fin debe ser posterior a la de inicio'**
  String get eventsErrorTimeRange;

  /// Validation error: casual events cannot have a preshards pool
  ///
  /// In es, this message translates to:
  /// **'Los eventos casuales no pueden tener pool'**
  String get eventsErrorCasualPool;

  /// Validation error: juerga location warning must be confirmed
  ///
  /// In es, this message translates to:
  /// **'Confirma el aviso de ubicación para continuar'**
  String get eventsErrorJuergaConfirm;

  /// Validation error: a group is required for group-scoped events
  ///
  /// In es, this message translates to:
  /// **'Selecciona un grupo'**
  String get eventsErrorGroup;

  /// Validation error: a join mode is required for public events
  ///
  /// In es, this message translates to:
  /// **'Selecciona el modo de acceso'**
  String get eventsErrorJoinMode;

  /// Event detail screen app bar title
  ///
  /// In es, this message translates to:
  /// **'evento'**
  String get eventDetailTitle;

  /// Badge for events scoped to a group
  ///
  /// In es, this message translates to:
  /// **'Evento de grupo'**
  String get eventGroupScoped;

  /// Button to open the scoping group from an event
  ///
  /// In es, this message translates to:
  /// **'Ver grupo'**
  String get eventViewGroup;

  /// Placeholder when an event has no location
  ///
  /// In es, this message translates to:
  /// **'Sin ubicación'**
  String get eventNoLocation;

  /// Preshard pool amount
  ///
  /// In es, this message translates to:
  /// **'{pool} preshards'**
  String eventPoolAmount(int pool);

  /// Pool already distributed to attendees
  ///
  /// In es, this message translates to:
  /// **'Distribuido'**
  String get eventPoolDistributed;

  /// Pool not yet distributed
  ///
  /// In es, this message translates to:
  /// **'Pendiente de distribuir'**
  String get eventPoolNotDistributed;

  /// Per-user distribution cap
  ///
  /// In es, this message translates to:
  /// **'Tope por asistente: {cap} preshards'**
  String eventCapPerUser(int cap);

  /// Placeholder when an event has no preshard pool
  ///
  /// In es, this message translates to:
  /// **'Sin pool de preshards'**
  String get eventNoPool;

  /// Remainder-action line on the pool card
  ///
  /// In es, this message translates to:
  /// **'Sobrante: {action}'**
  String eventRemainderAction(String action);

  /// Hosts section heading
  ///
  /// In es, this message translates to:
  /// **'Anfitrión y staff'**
  String get eventHosts;

  /// Host role badge
  ///
  /// In es, this message translates to:
  /// **'Anfitrión'**
  String get eventRoleHost;

  /// Staff role badge
  ///
  /// In es, this message translates to:
  /// **'Staff'**
  String get eventRoleStaff;

  /// Hosts section error fallback
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el anfitrión y staff'**
  String get eventHostsError;

  /// Empty hosts state
  ///
  /// In es, this message translates to:
  /// **'Aún no hay anfitriones ni staff'**
  String get eventNoHosts;

  /// Host action that opens the staff picker
  ///
  /// In es, this message translates to:
  /// **'Añadir staff'**
  String get eventStaffAddButton;

  /// Event staff-picker app bar title
  ///
  /// In es, this message translates to:
  /// **'elegir staff'**
  String get eventStaffPickerTitle;

  /// Confirm button with the number of selected staff
  ///
  /// In es, this message translates to:
  /// **'Añadir ({count})'**
  String eventStaffCount(int count);

  /// Snackbar confirming staff were designated
  ///
  /// In es, this message translates to:
  /// **'Staff añadido'**
  String get eventStaffAdded;

  /// Snackbar confirming a staff member was removed
  ///
  /// In es, this message translates to:
  /// **'Staff eliminado'**
  String get eventStaffRemoved;

  /// Host action that removes a staff member
  ///
  /// In es, this message translates to:
  /// **'Quitar staff'**
  String get eventStaffRemove;

  /// Confirm dialog title before removing a staff member
  ///
  /// In es, this message translates to:
  /// **'¿Quitar a @{username}?'**
  String eventStaffRemoveDialogTitle(String username);

  /// Confirm dialog body before removing a staff member
  ///
  /// In es, this message translates to:
  /// **'Dejará de ser staff y no podrá escanear códigos de asistencia.'**
  String get eventStaffRemoveDialogBody;

  /// Confirm button of the remove-staff dialog
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get eventStaffRemoveConfirm;

  /// Own invite status line
  ///
  /// In es, this message translates to:
  /// **'Tu invitación: {status}'**
  String eventInviteStatus(String status);

  /// Pending invite status
  ///
  /// In es, this message translates to:
  /// **'pendiente'**
  String get eventInvitePending;

  /// Accepted invite status
  ///
  /// In es, this message translates to:
  /// **'aceptada'**
  String get eventInviteAccepted;

  /// Declined invite status
  ///
  /// In es, this message translates to:
  /// **'declinada'**
  String get eventInviteDeclined;

  /// Attended invite status
  ///
  /// In es, this message translates to:
  /// **'asistida'**
  String get eventInviteAttended;

  /// Event guest-roster section heading (host view)
  ///
  /// In es, this message translates to:
  /// **'Invitados'**
  String get eventGuestsTitle;

  /// Empty guest roster state
  ///
  /// In es, this message translates to:
  /// **'Aún no hay invitados'**
  String get eventGuestsEmpty;

  /// Guest roster load error fallback
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los invitados'**
  String get eventGuestsLoadError;

  /// Confirmed-attendees section heading on the attendee's event detail
  ///
  /// In es, this message translates to:
  /// **'Asistentes'**
  String get eventAttendeesTitle;

  /// Empty confirmed-attendees state on the attendee's event detail
  ///
  /// In es, this message translates to:
  /// **'Aún no hay asistentes confirmados'**
  String get eventAttendeesEmpty;

  /// Confirmed-attendees load error fallback
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los asistentes'**
  String get eventAttendeesLoadError;

  /// Host action that opens the guest picker
  ///
  /// In es, this message translates to:
  /// **'Invitar personas'**
  String get eventInviteGuestsButton;

  /// Event guest-picker app bar title
  ///
  /// In es, this message translates to:
  /// **'invitar'**
  String get eventsInviteTitle;

  /// Confirm button with the number of selected guests
  ///
  /// In es, this message translates to:
  /// **'Invitar ({count})'**
  String eventsInviteCount(int count);

  /// Snackbar / roster tag confirming an invite was sent
  ///
  /// In es, this message translates to:
  /// **'Invitación enviada'**
  String get eventsInviteSent;

  /// Picker row tag for users who already hold an invite
  ///
  /// In es, this message translates to:
  /// **'invitada'**
  String get eventsInviteSentTag;

  /// Pending-invite accept/decline card body
  ///
  /// In es, this message translates to:
  /// **'Te invitaron a este evento. Confirma tu asistencia.'**
  String get eventInvitePendingBody;

  /// Accept-invite button
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get eventInviteAccept;

  /// Decline-invite button
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get eventInviteDecline;

  /// Snackbar after accepting an event invite
  ///
  /// In es, this message translates to:
  /// **'Asistencia confirmada'**
  String get eventInviteAcceptedSnack;

  /// Snackbar after declining an event invite
  ///
  /// In es, this message translates to:
  /// **'Invitación rechazada'**
  String get eventInviteDeclinedSnack;

  /// Edit-event button
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get eventEditButton;

  /// Cancel-event button
  ///
  /// In es, this message translates to:
  /// **'Cancelar evento'**
  String get eventCancelButton;

  /// Cancel-event confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'¿Cancelar evento?'**
  String get eventCancelDialogTitle;

  /// Cancel-event confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'Se devolverán los preshards a los hosts. Los invitados serán notificados.'**
  String get eventCancelDialogBody;

  /// Cancel-event confirmation button
  ///
  /// In es, this message translates to:
  /// **'Sí, cancelar'**
  String get eventCancelConfirm;

  /// Snackbar after cancelling an event
  ///
  /// In es, this message translates to:
  /// **'Evento cancelado'**
  String get eventCancelledSnack;

  /// Event editor app bar title
  ///
  /// In es, this message translates to:
  /// **'editar'**
  String get eventEditTitle;

  /// Notice that the pool fields lock at starts_at
  ///
  /// In es, this message translates to:
  /// **'El pool, tope y sobrante pueden editarse hasta que comience el evento.'**
  String get eventPoolLockedNotice;

  /// Snackbar after saving the event
  ///
  /// In es, this message translates to:
  /// **'Evento actualizado'**
  String get eventEditUpdatedSnack;

  /// Validation error for an invalid pool amount
  ///
  /// In es, this message translates to:
  /// **'Ingresa un monto de pool válido'**
  String get eventInvalidPoolAmount;

  /// Draft status badge
  ///
  /// In es, this message translates to:
  /// **'Borrador'**
  String get eventStatusDraft;

  /// Upcoming status badge
  ///
  /// In es, this message translates to:
  /// **'Próximamente'**
  String get eventStatusUpcoming;

  /// Live status badge
  ///
  /// In es, this message translates to:
  /// **'En vivo'**
  String get eventStatusLive;

  /// Ended status badge
  ///
  /// In es, this message translates to:
  /// **'Finalizado'**
  String get eventStatusEnded;

  /// Cancelled status badge
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get eventStatusCancelled;

  /// Attendance QR screen title
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get qrAttendanceTitle;

  /// Attendance QR: event load error message
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el evento.'**
  String get qrEventLoadError;

  /// Attendance QR: countdown to activation time
  ///
  /// In es, this message translates to:
  /// **'Se activa en {time}'**
  String qrActivationCountdown(String time);

  /// QR scanner screen title
  ///
  /// In es, this message translates to:
  /// **'Escáner'**
  String get qrScannerTitle;

  /// QR scanner: scan instruction
  ///
  /// In es, this message translates to:
  /// **'Escanea el código QR del asistente'**
  String get qrScanPrompt;

  /// QR scanner: event name label
  ///
  /// In es, this message translates to:
  /// **'Evento: {name}'**
  String qrScanEventName(String name);

  /// QR scanner: event name fallback
  ///
  /// In es, this message translates to:
  /// **'Evento'**
  String get qrScanEventFallback;

  /// QR scanner: torch-on tooltip
  ///
  /// In es, this message translates to:
  /// **'Encender linterna'**
  String get qrTorchOn;

  /// QR scanner: torch-off tooltip
  ///
  /// In es, this message translates to:
  /// **'Apagar linterna'**
  String get qrTorchOff;

  /// QR scanner: validating a scanned code
  ///
  /// In es, this message translates to:
  /// **'Verificando…'**
  String get qrScanProcessing;

  /// QR scanner: attendance confirmed banner
  ///
  /// In es, this message translates to:
  /// **'¡Asistencia confirmada!'**
  String get qrScanConfirmed;

  /// QR scanner: confirmed attendee name
  ///
  /// In es, this message translates to:
  /// **'Asistente: {name}'**
  String qrScanAttendee(String name);

  /// QR scanner: ready-state label after confirmation
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get qrScanReady;

  /// QR scanner: double-scan error
  ///
  /// In es, this message translates to:
  /// **'Este código QR ya fue escaneado.'**
  String get qrScanAlreadyScanned;

  /// QR scanner: attendee not invited error
  ///
  /// In es, this message translates to:
  /// **'El usuario no está invitado a este evento.'**
  String get qrScanNotInvited;

  /// QR scanner: event outside attendance window
  ///
  /// In es, this message translates to:
  /// **'El evento no está activo para confirmación de asistencia.'**
  String get qrScanNotInWindow;

  /// QR scanner: caller lacks host role
  ///
  /// In es, this message translates to:
  /// **'No tienes permisos para escanear en este evento.'**
  String get qrScanNotHost;

  /// QR scanner: unrecognized code
  ///
  /// In es, this message translates to:
  /// **'Código QR inválido.'**
  String get qrScanInvalidCode;

  /// QR scanner: connection/RPC error with retry
  ///
  /// In es, this message translates to:
  /// **'Error de conexión. Reintentar...'**
  String get qrScanNetworkError;

  /// QR scanner: camera unavailable
  ///
  /// In es, this message translates to:
  /// **'No se pudo acceder a la cámara.'**
  String get qrCameraUnavailable;

  /// QR scanner: camera unavailable hint
  ///
  /// In es, this message translates to:
  /// **'Cierra y vuelve a abrir el escáner, o revisa los permisos de la cámara.'**
  String get qrCameraUnavailableBody;

  /// QR scanner: camera permission needed
  ///
  /// In es, this message translates to:
  /// **'Se necesita acceso a la cámara para escanear.'**
  String get qrCameraDenied;

  /// QR scanner: settings dialog title
  ///
  /// In es, this message translates to:
  /// **'Acceso a la cámara'**
  String get qrCameraSettingsTitle;

  /// QR scanner: settings dialog body
  ///
  /// In es, this message translates to:
  /// **'Samay necesita acceso a la cámara para escanear los códigos QR de asistencia.'**
  String get qrCameraSettingsBody;

  /// QR scanner: settings dialog action
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get qrCameraSettingsAction;

  /// Attendance code: pre-activation message (code unlocks 30 minutes before the event)
  ///
  /// In es, this message translates to:
  /// **'Tu código de asistencia aún no está listo.'**
  String get codeNotReadyYet;

  /// Attendance code: code load error message
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar tu código.'**
  String get codeLoadError;

  /// Attendance code: post-event message
  ///
  /// In es, this message translates to:
  /// **'El evento finalizó. Ya no se necesita un código de asistencia.'**
  String get codeEventEnded;

  /// Attendance code: caller is not an attendee
  ///
  /// In es, this message translates to:
  /// **'No tienes un código para este evento.'**
  String get codeNotInvited;

  /// Attendance code: server refused inside the presumed window
  ///
  /// In es, this message translates to:
  /// **'El servidor aún no emitió tu código.'**
  String get codeServerPending;

  /// Attendance code: server-pending retry hint
  ///
  /// In es, this message translates to:
  /// **'Si el problema continúa, presiona Reintentar.'**
  String get codeServerPendingBody;

  /// Attendance code: terminal word revealed under the check mark once assisted
  ///
  /// In es, this message translates to:
  /// **'LISTO'**
  String get codeAssistedDone;

  /// Cosmetics shop screen app-bar title
  ///
  /// In es, this message translates to:
  /// **'cosméticos'**
  String get cosmeticsShopTitle;

  /// Cosmetics shop category tab: avatar frames
  ///
  /// In es, this message translates to:
  /// **'Marcos'**
  String get cosmeticsTabFrames;

  /// Cosmetics shop category tab: profile backgrounds
  ///
  /// In es, this message translates to:
  /// **'Fondos'**
  String get cosmeticsTabBackgrounds;

  /// Cosmetics shop category tab: badges
  ///
  /// In es, this message translates to:
  /// **'Insignias'**
  String get cosmeticsTabBadges;

  /// VIP subscription tier label
  ///
  /// In es, this message translates to:
  /// **'VIP'**
  String get cosmeticsTierVip;

  /// PRO subscription tier label
  ///
  /// In es, this message translates to:
  /// **'PRO'**
  String get cosmeticsTierPro;

  /// Free subscription tier label
  ///
  /// In es, this message translates to:
  /// **'Gratis'**
  String get cosmeticsTierFree;

  /// Cosmetics purchase confirmation dialog title
  ///
  /// In es, this message translates to:
  /// **'Confirmar compra'**
  String get cosmeticsPurchaseTitle;

  /// Cosmetics purchase confirmation dialog body
  ///
  /// In es, this message translates to:
  /// **'¿Comprar {name} por {cost} shards?'**
  String cosmeticsPurchaseConfirm(String name, int cost);

  /// Confirm button on the cosmetics purchase dialog
  ///
  /// In es, this message translates to:
  /// **'Comprar'**
  String get cosmeticsBuy;

  /// Cosmetics shop buy button showing the shard cost
  ///
  /// In es, this message translates to:
  /// **'Comprar — {cost}'**
  String cosmeticsBuyWithCost(int cost);

  /// Snackbar after a successful cosmetics purchase
  ///
  /// In es, this message translates to:
  /// **'¡Cosmético adquirido!'**
  String get cosmeticsPurchaseSuccess;

  /// Snackbar when the user's subscription tier is below the item requirement
  ///
  /// In es, this message translates to:
  /// **'Requiere una suscripción de nivel superior.'**
  String get cosmeticsTierRequired;

  /// Badge on an already-owned cosmetic card
  ///
  /// In es, this message translates to:
  /// **'Adquirido'**
  String get cosmeticsOwned;

  /// Button label when the cosmetic is currently equipped
  ///
  /// In es, this message translates to:
  /// **'Equipado'**
  String get cosmeticsEquipped;

  /// Button label to equip an owned cosmetic
  ///
  /// In es, this message translates to:
  /// **'Equipar'**
  String get cosmeticsEquip;

  /// Tier-locked cosmetic card hint
  ///
  /// In es, this message translates to:
  /// **'Requiere {tier}'**
  String cosmeticsRequiresTier(String tier);

  /// Empty state on the cosmetics shop
  ///
  /// In es, this message translates to:
  /// **'No hay cosméticos disponibles aún'**
  String get cosmeticsEmptyCatalog;

  /// App bar title of the group minigames hub
  ///
  /// In es, this message translates to:
  /// **'juegos'**
  String get minigamesTitle;

  /// Second header row of the minigames hub (match list)
  ///
  /// In es, this message translates to:
  /// **'Te atreves'**
  String get minigamesTagline;

  /// Título del selector de grupo al empezar un juego desde el feed principal
  ///
  /// In es, this message translates to:
  /// **'Elige un grupo'**
  String get minigamesChooseGroup;

  /// Create-partida wizard: placeholder shown where the selected group name goes before any group is chosen
  ///
  /// In es, this message translates to:
  /// **'…'**
  String get minigamesChooseGroupEllipsis;

  /// Título del snackbar al intentar jugar sin pertenecer a ningún grupo
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes grupos'**
  String get minigamesNoGroups;

  /// Cuerpo del snackbar al intentar jugar sin pertenecer a ningún grupo
  ///
  /// In es, this message translates to:
  /// **'Únete o crea un grupo para jugar con tus amigos.'**
  String get minigamesNoGroupsBody;

  /// Section heading above the five game-type cards
  ///
  /// In es, this message translates to:
  /// **'Elige un juego'**
  String get minigamesPickGame;

  /// Game #3 name (Truth or Dare)
  ///
  /// In es, this message translates to:
  /// **'Verdad o Reto'**
  String get minigamesGameTruthDare;

  /// Game #3 one-line tagline
  ///
  /// In es, this message translates to:
  /// **'¿Te atreves...?'**
  String get minigamesGameTruthDareTagline;

  /// Game #3 explanation on the dedicated game page
  ///
  /// In es, this message translates to:
  /// **'Cada jugador elige Verdad o Reto y el grupo decide si cumpliste. Sin escapatoria.'**
  String get minigamesGameTruthDareExplanation;

  /// Game #4 name (Drunk Bottle)
  ///
  /// In es, this message translates to:
  /// **'Botella'**
  String get minigamesGameDrunkBottle;

  /// Game #4 one-line tagline
  ///
  /// In es, this message translates to:
  /// **'Gira la botella y veamos a quién apunta'**
  String get minigamesGameDrunkBottleTagline;

  /// Game #4 explanation on the dedicated game page
  ///
  /// In es, this message translates to:
  /// **'Gira la botella: a quien apunte le toca cumplir. Ideal para reuniones con amigos.'**
  String get minigamesGameDrunkBottleExplanation;

  /// Drunk bottle: button that starts the spin
  ///
  /// In es, this message translates to:
  /// **'Girar'**
  String get minigamesBottleSpin;

  /// Drunk bottle: button that stops the spin
  ///
  /// In es, this message translates to:
  /// **'Parar'**
  String get minigamesBottleStop;

  /// Game #6 name (Charades)
  ///
  /// In es, this message translates to:
  /// **'Charadas'**
  String get minigamesGameCharades;

  /// Game #6 one-line tagline
  ///
  /// In es, this message translates to:
  /// **'Celular en la frente y que adivinen'**
  String get minigamesGameCharadesTagline;

  /// Game #6 explanation on the dedicated game page
  ///
  /// In es, this message translates to:
  /// **'Te pones el celular en la frente sin mirar la pantalla. El grupo actúa la palabra que aparece y tú adivinas. Cada acierto suma un punto y, cuando se acaba el tiempo, le toca al siguiente.'**
  String get minigamesGameCharadesExplanation;

  /// Charades: rules card heading
  ///
  /// In es, this message translates to:
  /// **'Cómo se juega'**
  String get charadesRulesTitle;

  /// Charades rule 1
  ///
  /// In es, this message translates to:
  /// **'Pon el celular en tu frente, con la pantalla hacia el grupo. No mires.'**
  String get charadesRule1;

  /// Charades rule 2
  ///
  /// In es, this message translates to:
  /// **'El grupo actúa la palabra sin decirla ni deletrearla.'**
  String get charadesRule2;

  /// Charades rule 3
  ///
  /// In es, this message translates to:
  /// **'Si adivinas, toca Acerté. Si se complica, toca Paso.'**
  String get charadesRule3;

  /// Charades rule 4
  ///
  /// In es, this message translates to:
  /// **'Al terminar el tiempo se cuentan tus aciertos y pasa el turno.'**
  String get charadesRule4;

  /// Charades: category picker heading
  ///
  /// In es, this message translates to:
  /// **'Elige una categoría'**
  String get charadesPickCategory;

  /// Charades: turn duration label
  ///
  /// In es, this message translates to:
  /// **'Duración'**
  String get charadesDuration;

  /// Charades: a duration in seconds
  ///
  /// In es, this message translates to:
  /// **'{count} s'**
  String charadesSeconds(int count);

  /// Charades: start button
  ///
  /// In es, this message translates to:
  /// **'Empezar mi turno'**
  String get charadesStartTurn;

  /// Charades: correct button
  ///
  /// In es, this message translates to:
  /// **'Acerté'**
  String get charadesHit;

  /// Charades: skip button
  ///
  /// In es, this message translates to:
  /// **'Paso'**
  String get charadesPass;

  /// Charades: end turn early
  ///
  /// In es, this message translates to:
  /// **'Terminar turno'**
  String get charadesFinish;

  /// Charades: spectator banner naming the active player
  ///
  /// In es, this message translates to:
  /// **'Está jugando {name}'**
  String charadesPlayingBy(String name);

  /// Charades: spectator instruction while a turn runs
  ///
  /// In es, this message translates to:
  /// **'¡Actúen la palabra!'**
  String get charadesActNow;

  /// Charades: time over heading
  ///
  /// In es, this message translates to:
  /// **'¡Se acabó el tiempo!'**
  String get charadesTimeUp;

  /// Charades: hits in the closed turn
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin aciertos} =1{1 acierto} other{{count} aciertos}}'**
  String charadesTurnScore(int count);

  /// Charades: scoreboard heading
  ///
  /// In es, this message translates to:
  /// **'Marcador'**
  String get charadesScoreboard;

  /// Charades: hand the turn over
  ///
  /// In es, this message translates to:
  /// **'Que juegue otro'**
  String get charadesNextPlayer;

  /// Charades: idle heading
  ///
  /// In es, this message translates to:
  /// **'Nadie está jugando todavía'**
  String get charadesWaitingTurn;

  /// Charades category: every category
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get charadesCategoryAll;

  /// Charades category: movies
  ///
  /// In es, this message translates to:
  /// **'Películas'**
  String get charadesCategoryPeliculas;

  /// Charades category: animals
  ///
  /// In es, this message translates to:
  /// **'Animales'**
  String get charadesCategoryAnimales;

  /// Charades category: actions
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get charadesCategoryAcciones;

  /// Charades category: objects
  ///
  /// In es, this message translates to:
  /// **'Objetos'**
  String get charadesCategoryObjetos;

  /// Charades category: celebrities
  ///
  /// In es, this message translates to:
  /// **'Famosos'**
  String get charadesCategoryFamosos;

  /// Charades category: party
  ///
  /// In es, this message translates to:
  /// **'Fiesta'**
  String get charadesCategoryFiesta;

  /// Lobby: label of the host-only publish switch
  ///
  /// In es, this message translates to:
  /// **'Partida abierta'**
  String get minigamesPublishTitle;

  /// Lobby: helper text under the publish switch
  ///
  /// In es, this message translates to:
  /// **'Cualquiera en la app puede verla y unirse sin invitación'**
  String get minigamesPublishSubtitle;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Ese código no es válido o venció.'**
  String get minigamesErrorInvalidCode;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Unirme con código'**
  String get minigamesJoinCodeTitle;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Pídele al anfitrión el código de 6 caracteres de una partida directa.'**
  String get minigamesJoinCodeHint;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Unirme con código'**
  String get minigamesJoinCodeButton;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'ABC234'**
  String get minigamesJoinCodePlaceholder;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Código de la partida'**
  String get minigamesJoinCodeShareTitle;

  /// Join-code share body
  ///
  /// In es, this message translates to:
  /// **'Comparte este código: {code}'**
  String minigamesJoinCodeShareBody(String code);

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Genera un código y compártelo. Solo se guarda un hash; se muestra una vez.'**
  String get minigamesJoinCodeShareHint;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Copiar'**
  String get minigamesJoinCodeCopy;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get minigamesJoinCodeDone;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Generar código'**
  String get minigamesJoinCodeGenerate;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'Revocar'**
  String get minigamesJoinCodeRevoke;

  /// E4 code-only matches
  ///
  /// In es, this message translates to:
  /// **'El código fue revocado.'**
  String get minigamesJoinCodeRevoked;

  /// Open lobby section heading
  ///
  /// In es, this message translates to:
  /// **'Partidas abiertas'**
  String get minigamesPublicLobbyTitle;

  /// Open lobby: join button
  ///
  /// In es, this message translates to:
  /// **'Unirme'**
  String get minigamesPublicJoin;

  /// Open lobby: confirmation after joining
  ///
  /// In es, this message translates to:
  /// **'Te uniste a la partida'**
  String get minigamesPublicJoined;

  /// Open lobby: tag on a partida the user already belongs to
  ///
  /// In es, this message translates to:
  /// **'Ya estás dentro'**
  String get minigamesPublicAlreadyIn;

  /// Open lobby: empty state
  ///
  /// In es, this message translates to:
  /// **'Todavía nadie publicó una partida. Crea una y ábrela para que se sumen.'**
  String get minigamesPublicEmpty;

  /// Open lobby: who hosts the partida
  ///
  /// In es, this message translates to:
  /// **'de {name}'**
  String minigamesPublicHostedBy(String name);

  /// Open lobby: roster size against the cap
  ///
  /// In es, this message translates to:
  /// **'{count}/{limit} jugadores'**
  String minigamesPublicPlayers(int count, int limit);

  /// Open lobby: tag on a partida at its player cap
  ///
  /// In es, this message translates to:
  /// **'Llena'**
  String get minigamesPublicFull;

  /// Drunk bottle: status line while the bottle spins
  ///
  /// In es, this message translates to:
  /// **'Girando…'**
  String get minigamesBottleSpinning;

  /// Drunk bottle: idle status line before the first spin
  ///
  /// In es, this message translates to:
  /// **'Toca Girar y que decida la botella'**
  String get minigamesBottleTapToSpin;

  /// Drunk bottle: status line naming the player the bottle landed on
  ///
  /// In es, this message translates to:
  /// **'Le tocó a {name}'**
  String minigamesBottleLandedOn(String name);

  /// Drunk bottle: status line when the bottle landed on the current user
  ///
  /// In es, this message translates to:
  /// **'¡Te tocó a ti!'**
  String get minigamesBottleYourTurn;

  /// Drunk bottle: heading of the dare card
  ///
  /// In es, this message translates to:
  /// **'Tu reto'**
  String get minigamesBottleDareTitle;

  /// Drunk bottle: who launched the current spin
  ///
  /// In es, this message translates to:
  /// **'Giró {name}'**
  String minigamesBottleSpunBy(String name);

  /// Drunk bottle dare category: mild
  ///
  /// In es, this message translates to:
  /// **'suave'**
  String get minigamesBottleCategorySuave;

  /// Drunk bottle dare category: medium
  ///
  /// In es, this message translates to:
  /// **'medio'**
  String get minigamesBottleCategoryMedio;

  /// Drunk bottle dare category: spicy
  ///
  /// In es, this message translates to:
  /// **'picante'**
  String get minigamesBottleCategoryPicante;

  /// Drunk bottle dare category: penalty
  ///
  /// In es, this message translates to:
  /// **'castigo'**
  String get minigamesBottleCategoryCastigo;

  /// Drunk bottle: minimum-player gate message on the lobby's Start button
  ///
  /// In es, this message translates to:
  /// **'La botella necesita al menos {min} jugadores (tienes {count})'**
  String minigamesBottleMinPlayers(int min, int count);

  /// Game #6 name (Two Lies, One Truth)
  ///
  /// In es, this message translates to:
  /// **'2 Mentiras, 1 Verdad'**
  String get minigamesGameTwoLiesOneTruth;

  /// Game #6 one-line tagline
  ///
  /// In es, this message translates to:
  /// **'Adivina cuál es la única verdad'**
  String get minigamesGameTwoLiesOneTruthTagline;

  /// Game #6 explanation on the dedicated game page
  ///
  /// In es, this message translates to:
  /// **'El protagonista escribe 3 afirmaciones sobre sí mismo: 2 mentiras y 1 verdad. Los demás deben adivinar cuál es la real.'**
  String get minigamesGameTwoLiesOneTruthExplanation;

  /// Per-game page: the game is meant to be played with friends
  ///
  /// In es, this message translates to:
  /// **'Para jugar con amigos'**
  String get minigamesAudienceFriends;

  /// Per-game page: the game is meant to be played alone
  ///
  /// In es, this message translates to:
  /// **'Para jugar solo'**
  String get minigamesAudienceSolo;

  /// Per-game page: the game works both solo and with friends
  ///
  /// In es, this message translates to:
  /// **'Con amigos o solo'**
  String get minigamesAudienceBoth;

  /// Create-partida flow: default capitalized form. The wizard AppBar title lowercases it (minigamesNewPartida.toLowerCase()); the detail CTA uses it as-is.
  ///
  /// In es, this message translates to:
  /// **'Nueva partida'**
  String get minigamesNewPartida;

  /// Create-partida wizard: section title above the Directa/Grupo scope toggle
  ///
  /// In es, this message translates to:
  /// **'Partida'**
  String get minigamesScopeLabel;

  /// Create-partida wizard: name input label (blank = auto partida-XX)
  ///
  /// In es, this message translates to:
  /// **'Nombre (opcional)'**
  String get minigamesPartidaNameLabel;

  /// Create-partida wizard: name input hint showing the next auto name (partida-1, partida-2, ...)
  ///
  /// In es, this message translates to:
  /// **'{autoName}'**
  String minigamesPartidaNameHint(String autoName);

  /// Auto partida name when the player leaves the name blank (partida-1, partida-2, ...)
  ///
  /// In es, this message translates to:
  /// **'partida-{index}'**
  String minigamesAutoName(int index);

  /// Per-game page: section heading above the ongoing partidas list
  ///
  /// In es, this message translates to:
  /// **'Partidas en curso'**
  String get minigamesOngoingTitle;

  /// Per-game page: empty state title when there are no ongoing partidas of this game
  ///
  /// In es, this message translates to:
  /// **'Aún no hay partidas de {game}'**
  String minigamesDetailEmpty(String game);

  /// Per-game page: empty state body prompting the user to start the first partida
  ///
  /// In es, this message translates to:
  /// **'Toca «Nueva partida» para crear la primera.'**
  String get minigamesDetailEmptyBody;

  /// Create-partida wizard: wager input hint (default 10 shards)
  ///
  /// In es, this message translates to:
  /// **'Por defecto: 10'**
  String get minigamesWagerDefaultHint;

  /// Create-partida wizard: total-turn target label (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'Rondas'**
  String get minigamesRoundsLabel;

  /// Create-partida wizard: rounds input hint (default 5 turns)
  ///
  /// In es, this message translates to:
  /// **'Por defecto: 5'**
  String get minigamesRoundsHint;

  /// Create-partida wizard: wager input label above the amount (Entrada: = how many shards are being used)
  ///
  /// In es, this message translates to:
  /// **'Entrada'**
  String get minigamesWagerLabel;

  /// Wager input hint: 0 means no wager
  ///
  /// In es, this message translates to:
  /// **'0 = sin apuesta'**
  String get minigamesWagerHint;

  /// Create-partida wizard: small caption above the player's shard balance, right of the amount input
  ///
  /// In es, this message translates to:
  /// **'Disponibles'**
  String get minigamesWagerBalanceCaption;

  /// Button that creates the minigame session
  ///
  /// In es, this message translates to:
  /// **'Crear partida'**
  String get minigamesCreate;

  /// Snackbar after a successful session creation
  ///
  /// In es, this message translates to:
  /// **'Partida creada'**
  String get minigamesCreated;

  /// Error snackbar: balance below the requested wager
  ///
  /// In es, this message translates to:
  /// **'No tienes suficientes shards para esta apuesta.'**
  String get minigamesErrorInsufficientShards;

  /// Error snackbar: caller is not a group member
  ///
  /// In es, this message translates to:
  /// **'No eres miembro de este grupo.'**
  String get minigamesErrorNotMember;

  /// Error snackbar: invalid game type
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la partida.'**
  String get minigamesErrorInvalidGameType;

  /// Generic error snackbar when the session could not be created
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear la partida.'**
  String get minigamesErrorCreate;

  /// Error snackbar: an invitee is blocked/deleted/self
  ///
  /// In es, this message translates to:
  /// **'Algunos jugadores no pudieron ser invitados.'**
  String get minigamesErrorInviteeNotAllowed;

  /// Error snackbar: an invitee opted into friends-only invites
  ///
  /// In es, this message translates to:
  /// **'Uno o más jugadores solo aceptan invitaciones de amigos.'**
  String get minigamesErrorInviteeFriendsOnly;

  /// Error snackbar: more than the cap of 20 invitees
  ///
  /// In es, this message translates to:
  /// **'Puedes invitar hasta 20 jugadores.'**
  String get minigamesErrorTooManyInvitees;

  /// Error view message when the session list fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar las partidas'**
  String get minigamesErrorLoad;

  /// Empty state title on the minigames hub
  ///
  /// In es, this message translates to:
  /// **'Aún no hay partidas en este grupo'**
  String get minigamesEmpty;

  /// Empty state body on the minigames hub
  ///
  /// In es, this message translates to:
  /// **'Crea la primera partida con uno de los juegos de arriba.'**
  String get minigamesEmptyBody;

  /// Lifecycle chip label for active sessions
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get minigamesStatusActive;

  /// Lifecycle chip label for finished sessions
  ///
  /// In es, this message translates to:
  /// **'Terminada'**
  String get minigamesStatusFinished;

  /// Button on a finished match's session detail that opens the finished leaderboard
  ///
  /// In es, this message translates to:
  /// **'Ver clasificación'**
  String get minigamesViewLeaderboard;

  /// Dialog title: how the partida's shard pool is split among the paid places
  ///
  /// In es, this message translates to:
  /// **'Premios'**
  String get minigamesPoolBreakdownTitle;

  /// Pool breakdown row: the ordinal of a paid place (its amount renders separately beside the shard icon)
  ///
  /// In es, this message translates to:
  /// **'{rank}º'**
  String minigamesPoolRank(int rank);

  /// Pool breakdown line for a free partida (no shard pool)
  ///
  /// In es, this message translates to:
  /// **'Sin premio'**
  String get minigamesPoolNoPrize;

  /// Placeholder snackbar when tapping a session (per-game UIs are future work)
  ///
  /// In es, this message translates to:
  /// **'La partida se jugará aquí pronto.'**
  String get minigamesDetailComingSoon;

  /// Play screen app bar title for the Verdad o Reto game
  ///
  /// In es, this message translates to:
  /// **'Verdad o Reto'**
  String get minigamesPlayTitle;

  /// Play screen header title word shown while the game state loads
  ///
  /// In es, this message translates to:
  /// **'esperando…'**
  String get minigamesBarWaiting;

  /// Play screen header title word shown when the game state fails to load
  ///
  /// In es, this message translates to:
  /// **'error'**
  String get minigamesBarError;

  /// Play screen header title word shown on the finished leaderboard
  ///
  /// In es, this message translates to:
  /// **'clasificación'**
  String get minigamesBarLeaderboard;

  /// Async-mode header word while the caller still owes a round (they answer next)
  ///
  /// In es, this message translates to:
  /// **'respondiendo'**
  String get minigamesBarResponding;

  /// Small muted lead-in before the current subject's name in the play header (Spanish word order: 'turno de {name}'). Trailing space included.
  ///
  /// In es, this message translates to:
  /// **'turno de '**
  String get minigamesTurnBarPrefix;

  /// Small muted trailing words after the current subject's name in the play header (empty for Spanish word order)
  ///
  /// In es, this message translates to:
  /// **''**
  String get minigamesTurnBarSuffix;

  /// Small muted lead-in before the author's name in the async header (Spanish: 'respuesta de {name}'). Trailing space included.
  ///
  /// In es, this message translates to:
  /// **'respuesta de '**
  String get minigamesResponseBarPrefix;

  /// Small muted trailing words after the author's name in the async header (empty for Spanish word order)
  ///
  /// In es, this message translates to:
  /// **''**
  String get minigamesResponseBarSuffix;

  /// Header asking the judge to pick a prompt kind when no subject name is resolved
  ///
  /// In es, this message translates to:
  /// **'¡Es tu turno! Elige Verdad o Reto'**
  String get minigamesChoosePromptGeneric;

  /// Header asking the judge to pick a prompt kind for the named subject
  ///
  /// In es, this message translates to:
  /// **'Le toca a {name}: elige Verdad o Reto'**
  String minigamesChoosePromptFor(String name);

  /// Button label for the truth (verdad) prompt kind
  ///
  /// In es, this message translates to:
  /// **'Verdad'**
  String get minigamesTruth;

  /// Button label for the dare (reto) prompt kind
  ///
  /// In es, this message translates to:
  /// **'Reto'**
  String get minigamesDare;

  /// Header revealing who must answer the prompt
  ///
  /// In es, this message translates to:
  /// **'¡Toca {name}!'**
  String minigamesPromptHeader(String name);

  /// Prompt header when the subject name is not resolved
  ///
  /// In es, this message translates to:
  /// **'¡Toca jugar!'**
  String get minigamesPromptGeneric;

  /// Button the subject taps once the truth is answered / dare is done — closes the round and moves on
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get minigamesPromptDone;

  /// Shown on the finished leaderboard in place of a question+answer when the prompt can no longer be resolved (deactivated/removed)
  ///
  /// In es, this message translates to:
  /// **'ERROR AL CARGAR LA PREGUNTA'**
  String get minigamesPromptLoadError;

  /// Button the subject taps to skip the prompt — the round closes and the turn advances
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get minigamesPromptSkip;

  /// Turn label when the subject name is not resolved
  ///
  /// In es, this message translates to:
  /// **'Turno de un jugador'**
  String get minigamesTurnGeneric;

  /// By-turns header when the current subject is the caller
  ///
  /// In es, this message translates to:
  /// **'tu turno…'**
  String get minigamesYourTurn;

  /// Prefix of the default anonymous temp nickname (202_minigame_play_v2)
  ///
  /// In es, this message translates to:
  /// **'anónimo'**
  String get minigamesAnonAliasPrefix;

  /// Title of the current-turn subject's answer input
  ///
  /// In es, this message translates to:
  /// **'Tu respuesta'**
  String get minigamesAnswerTitle;

  /// Placeholder of the answer text field
  ///
  /// In es, this message translates to:
  /// **'Escribe tu respuesta…'**
  String get minigamesAnswerPlaceholder;

  /// Button to attach an image to a Reto answer
  ///
  /// In es, this message translates to:
  /// **'Añadir imagen'**
  String get minigamesAnswerImageLabel;

  /// Button to remove the attached answer image
  ///
  /// In es, this message translates to:
  /// **'Quitar imagen'**
  String get minigamesAnswerRemoveImage;

  /// Button the subject taps to submit their answer
  ///
  /// In es, this message translates to:
  /// **'Responder'**
  String get minigamesAnswerSubmit;

  /// Label shown to the others once the subject has answered
  ///
  /// In es, this message translates to:
  /// **'Respondida'**
  String get minigamesAnswerRevealed;

  /// Shown to the others while the subject has not answered yet
  ///
  /// In es, this message translates to:
  /// **'Esperando la respuesta…'**
  String get minigamesAnswerWaiting;

  /// Shown to the subject after submitting: how many of the other participants have reacted so far
  ///
  /// In es, this message translates to:
  /// **'esperando {reacted}/{required} reacciones…'**
  String minigamesAnswerWaitingReactions(int reacted, int required);

  /// Shown while a participant who reinstalled the app waits for another participant to resend the round key
  ///
  /// In es, this message translates to:
  /// **'Esperando a que otro participante se conecte para descifrar…'**
  String get minigamesKeyRequesting;

  /// Shown when no participant was online to resend the lost round key — invites a retry
  ///
  /// In es, this message translates to:
  /// **'Nadie conectado para reenviar la clave.'**
  String get minigamesKeyMissing;

  /// Button the subject taps to skip (blocks reactions, score -1)
  ///
  /// In es, this message translates to:
  /// **'Pasar'**
  String get minigamesPasar;

  /// Suffix shown when the subject passed the round
  ///
  /// In es, this message translates to:
  /// **'pasó'**
  String get minigamesPasarSkipped;

  /// Label of the play-mode selector in the create wizard
  ///
  /// In es, this message translates to:
  /// **'Modo de juego'**
  String get minigamesModeLabel;

  /// By-turns play mode: answer -> all react -> next turn
  ///
  /// In es, this message translates to:
  /// **'Por turnos'**
  String get minigamesModeByTurns;

  /// Async play mode: per-player rounds, reactable list, timer end
  ///
  /// In es, this message translates to:
  /// **'Asíncrono'**
  String get minigamesModeAsync;

  /// Per-player round target in async mode
  ///
  /// In es, this message translates to:
  /// **'Rondas por jugador'**
  String get minigamesAsyncRoundsLabel;

  /// Async timer duration in days (settable at creation, no override)
  ///
  /// In es, this message translates to:
  /// **'Tiempo de la partida (días)'**
  String get minigamesAsyncEndsLabel;

  /// Anonymous-mode toggle: hide usernames, temp nicknames during play
  ///
  /// In es, this message translates to:
  /// **'Partida anónima'**
  String get minigamesAnonymousLabel;

  /// Label of the temp-nickname input in anonymous mode
  ///
  /// In es, this message translates to:
  /// **'Apodo temporal'**
  String get minigamesAliasLabel;

  /// Button to update the temp nickname in anonymous mode
  ///
  /// In es, this message translates to:
  /// **'Actualizar nombre'**
  String get minigamesAliasUpdate;

  /// Snackbar after a temp-nickname update
  ///
  /// In es, this message translates to:
  /// **'Nombre actualizado'**
  String get minigamesAliasUpdated;

  /// Per-player async progress
  ///
  /// In es, this message translates to:
  /// **'Tus rondas: {done}/{target}'**
  String minigamesAsyncProgress(int done, int target);

  /// Heading of the async reactable-rounds list
  ///
  /// In es, this message translates to:
  /// **'Rondas para reaccionar'**
  String get minigamesAsyncAvailable;

  /// Shows the async settable deadline
  ///
  /// In es, this message translates to:
  /// **'La partida termina el {date}'**
  String minigamesAsyncTimerEnds(String date);

  /// Hint under the answer card that Pasar is available
  ///
  /// In es, this message translates to:
  /// **'puedes pasar si no quieres responder'**
  String get minigamesAnswerPasarLine;

  /// Turn label naming the current subject
  ///
  /// In es, this message translates to:
  /// **'Turno de {name}'**
  String minigamesTurnFor(String name);

  /// Caption naming the server-authoritative next player
  ///
  /// In es, this message translates to:
  /// **'Siguiente: {name}'**
  String minigamesNextTurn(String name);

  /// Non-subject view before the prompt is revealed — waiting copy
  ///
  /// In es, this message translates to:
  /// **'Esperando al jugador actual…'**
  String get minigamesWaitingChoiceGeneric;

  /// Lobby countdown overlay caption
  ///
  /// In es, this message translates to:
  /// **'La partida empieza en…'**
  String get minigamesCountdownStarting;

  /// Non-host countdown overlay after the on-device countdown ends — waiting for the host to confirm the match start
  ///
  /// In es, this message translates to:
  /// **'Esperando al anfitrión…'**
  String get minigamesCountdownWaitingHost;

  /// Non-host countdown overlay — the host did not confirm/cancel within the watchdog window
  ///
  /// In es, this message translates to:
  /// **'El anfitrión no confirmó la partida. Inténtalo de nuevo.'**
  String get minigamesCountdownHostError;

  /// Lobby countdown overlay — host-only button that cancels the start
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get minigamesCountdownCancel;

  /// Host-only X tooltip/action to end the party game (draw settlement)
  ///
  /// In es, this message translates to:
  /// **'Terminar juego'**
  String get minigamesComplete;

  /// Confirmation dialog body when ending the party game
  ///
  /// In es, this message translates to:
  /// **'¿Seguro? Las apuestas se redistribuirán.'**
  String get minigamesCompleteConfirm;

  /// Confirmation dialog title when ending the party game
  ///
  /// In es, this message translates to:
  /// **'¿Terminar la partida?'**
  String get minigamesCompleteConfirmTitle;

  /// Finished state header on the play screen
  ///
  /// In es, this message translates to:
  /// **'¡Juego terminado!'**
  String get minigamesFinished;

  /// Play screen round counter: the current turn out of the total-turn target (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'Ronda {current} / {total}'**
  String minigamesRoundCounter(int current, int total);

  /// Leaderboard fallback name when the winner username is missing
  ///
  /// In es, this message translates to:
  /// **'Jugador'**
  String get minigamesAnonymousPlayer;

  /// Leaderboard prize per ranked winner (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'{amount} shards'**
  String minigamesPrizeAmount(int amount);

  /// Leaderboard score label per ranked player
  ///
  /// In es, this message translates to:
  /// **'{count} puntos'**
  String minigamesPointsAmount(int count);

  /// Discreet retry prompt inside a leaderboard card when the decrypted answers fail to load
  ///
  /// In es, this message translates to:
  /// **'Ups, no pudimos cargar las respuestas de la partida. Inténtalo más tarde.'**
  String get minigamesAnswersLoadError;

  /// Neutral leaderboard card state for a player with no recorded answers
  ///
  /// In es, this message translates to:
  /// **'Sin respuestas registradas'**
  String get minigamesNoAnswers;

  /// First-run hint on the finished-game leaderboard that swiping reveals more rank cards
  ///
  /// In es, this message translates to:
  /// **'Desliza para ver más rangos'**
  String get minigamesLeaderboardSwipeHint;

  /// Error state on the play screen when the game state fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el juego'**
  String get minigamesErrorLoadGame;

  /// Shard & preshard ledger screen app bar title
  ///
  /// In es, this message translates to:
  /// **'shards'**
  String get shardsLedgerTitle;

  /// Ledger tab label for the earned shard movements
  ///
  /// In es, this message translates to:
  /// **'Shards'**
  String get shardsLedgerTabShards;

  /// Ledger tab label for the preshard movements
  ///
  /// In es, this message translates to:
  /// **'Preshards'**
  String get shardsLedgerTabPreshards;

  /// Label above the derived sum of the visible ledger entries
  ///
  /// In es, this message translates to:
  /// **'Neto'**
  String get shardsLedgerNet;

  /// Empty state heading when a ledger side has no movements
  ///
  /// In es, this message translates to:
  /// **'Sin movimientos todavía'**
  String get shardsLedgerEmpty;

  /// Empty state body explaining where new movements appear
  ///
  /// In es, this message translates to:
  /// **'Cuando ganes o gastes shards, aparecerán aquí.'**
  String get shardsLedgerEmptyBody;

  /// Error state when the ledger history fails to load
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los movimientos'**
  String get shardsLedgerLoadError;

  /// Balance header label for personal (earned) shards
  ///
  /// In es, this message translates to:
  /// **'Ganados'**
  String get shardsLedgerEarned;

  /// Balance header label for preshards (bought or granted)
  ///
  /// In es, this message translates to:
  /// **'Comprados/Bonos'**
  String get shardsLedgerBought;

  /// Economy note: earned shards never expire
  ///
  /// In es, this message translates to:
  /// **'Los shards ganados nunca expiran.'**
  String get shardsLedgerEarnedNote;

  /// Economy note: preshards are event-only
  ///
  /// In es, this message translates to:
  /// **'Los preshards solo se usan para eventos.'**
  String get shardsLedgerPreshardsNote;

  /// Short reference id of the entity that caused a movement
  ///
  /// In es, this message translates to:
  /// **'Ref: {reference}'**
  String shardsLedgerReference(String reference);

  /// Ledger reason: shards earned by attending an event
  ///
  /// In es, this message translates to:
  /// **'Asistencia a evento'**
  String get shardsReasonEventAttendance;

  /// Ledger reason: shards spent on a cosmetic
  ///
  /// In es, this message translates to:
  /// **'Compra de cosmético'**
  String get shardsReasonCosmeticPurchase;

  /// Ledger reason: shards donated to a group
  ///
  /// In es, this message translates to:
  /// **'Donación a grupo'**
  String get shardsReasonGroupDonation;

  /// Ledger reason: shards wagered on a minigame
  ///
  /// In es, this message translates to:
  /// **'Apuesta en minigame'**
  String get shardsReasonMinigameWager;

  /// Ledger reason: shards won on a minigame
  ///
  /// In es, this message translates to:
  /// **'¡Ganaste el minigame!'**
  String get shardsReasonMinigameWin;

  /// Ledger reason: shards refunded from a minigame
  ///
  /// In es, this message translates to:
  /// **'Reembolso de minigame'**
  String get shardsReasonMinigameRefund;

  /// Ledger reason: shards granted by a subscription bonus
  ///
  /// In es, this message translates to:
  /// **'Bono de suscripción'**
  String get shardsReasonSubscriptionGrant;

  /// Ledger reason: shards granted by the Samay team
  ///
  /// In es, this message translates to:
  /// **'Otorgado por Samay'**
  String get shardsReasonAdminGrant;

  /// Ledger reason: shards earned by posting to the feed
  ///
  /// In es, this message translates to:
  /// **'Publicación en feed'**
  String get shardsReasonFeedPost;

  /// Preshard ledger reason: preshards bought
  ///
  /// In es, this message translates to:
  /// **'Compra de preshards'**
  String get preshardsReasonPurchased;

  /// Preshard ledger reason: monthly subscription preshard bonus
  ///
  /// In es, this message translates to:
  /// **'Bono mensual'**
  String get preshardsReasonSubscriptionGrant;

  /// Preshard ledger reason: preshards assigned to an event pool
  ///
  /// In es, this message translates to:
  /// **'Asignado a evento'**
  String get preshardsReasonEventPoolSet;

  /// Preshard ledger reason: event pool consumed by distribution
  ///
  /// In es, this message translates to:
  /// **'Distribuido en evento'**
  String get preshardsReasonEventPoolConsumed;

  /// Preshard ledger reason: event pool returned to the host
  ///
  /// In es, this message translates to:
  /// **'Devuelto de evento'**
  String get preshardsReasonEventPoolReturned;

  /// Preshard ledger reason: preshards granted by the Samay team
  ///
  /// In es, this message translates to:
  /// **'Otorgado por Samay'**
  String get preshardsReasonAdminGrant;

  /// Events tab hero heading (R1 events sweep)
  ///
  /// In es, this message translates to:
  /// **'eventos'**
  String get eventsTabTitle;

  /// Events tab create-event CTA
  ///
  /// In es, this message translates to:
  /// **'Crear evento'**
  String get eventsCreateCta;

  /// Events tab helper under the create-event CTA
  ///
  /// In es, this message translates to:
  /// **'Crea tu evento e invita personas — tu plan limita los asistentes.'**
  String get eventsCreateCtaBody;

  /// Create-event capacity section heading
  ///
  /// In es, this message translates to:
  /// **'¿Cuántas personas pueden asistir?'**
  String get eventsCapacityTitle;

  /// Create-event capacity helper under the stepper
  ///
  /// In es, this message translates to:
  /// **'Personas en total, incluyéndote.'**
  String get eventsCapacityHint;

  /// Create-event upsell button shown when the plan cap is reached
  ///
  /// In es, this message translates to:
  /// **'¿Quieres más? Contáctanos'**
  String get eventsCapacityContact;

  /// Snackbar for the static contact-us button
  ///
  /// In es, this message translates to:
  /// **'Muy pronto — te contactaremos.'**
  String get eventsContactSoon;

  /// Events tab empty state heading
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes eventos'**
  String get eventsEmpty;

  /// Events tab empty state body
  ///
  /// In es, this message translates to:
  /// **'Cuando te inviten o crees uno, aparecerá aquí.'**
  String get eventsEmptyBody;

  /// Validation message for a too-short search query (SR002)
  ///
  /// In es, this message translates to:
  /// **'Escribe al menos 2 caracteres para buscar'**
  String get searchTooShort;

  /// Events tab search field placeholder
  ///
  /// In es, this message translates to:
  /// **'Buscar eventos'**
  String get eventsSearchHint;

  /// Events tab search action tooltip
  ///
  /// In es, this message translates to:
  /// **'Buscar eventos'**
  String get eventsSearchTooltip;

  /// Events tab km filter action tooltip
  ///
  /// In es, this message translates to:
  /// **'Filtrar por distancia'**
  String get eventsFilterTooltip;

  /// Events tab button that resolves the device location
  ///
  /// In es, this message translates to:
  /// **'Usar mi ubicación'**
  String get eventsUseMyLocation;

  /// Events tab button that opens the map picker; becomes the chosen location
  ///
  /// In es, this message translates to:
  /// **'Elegir ubicación'**
  String get eventsPickLocation;

  /// Distance to an event rendered on a card
  ///
  /// In es, this message translates to:
  /// **'{km} km'**
  String eventsDistanceKm(String km);

  /// Accepted-friend signal on an event card
  ///
  /// In es, this message translates to:
  /// **'{count} amigos van'**
  String eventsFriendsGoing(int count);

  /// Create/edit event location section heading
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get eventsLocationSectionTitle;

  /// Create/edit event location helper
  ///
  /// In es, this message translates to:
  /// **'Opcional — arrastra el mapa para fijar el punto exacto.'**
  String get eventsLocationOptionalHint;

  /// Location picker sheet title
  ///
  /// In es, this message translates to:
  /// **'Elegir una ubicación'**
  String get locationPickerTitle;

  /// Location picker: paste a maps link
  ///
  /// In es, this message translates to:
  /// **'Enlace'**
  String get locationPickerLinkTab;

  /// Location picker: type lat,lng
  ///
  /// In es, this message translates to:
  /// **'Coords'**
  String get locationPickerCoordsTab;

  /// Location picker: pick on the map
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get locationPickerMapTab;

  /// Location picker link-mode hint
  ///
  /// In es, this message translates to:
  /// **'Pega un enlace de Google Maps o lat,lng'**
  String get locationPickerLinkHint;

  /// Location picker coords-mode hint
  ///
  /// In es, this message translates to:
  /// **'p. ej. -16.3988, -71.5369'**
  String get locationPickerCoordsHint;

  /// Location picker resolve button
  ///
  /// In es, this message translates to:
  /// **'Resolver'**
  String get locationPickerResolve;

  /// Location picker use resolved point
  ///
  /// In es, this message translates to:
  /// **'Usar'**
  String get locationPickerUse;

  /// Location picker confirm map center
  ///
  /// In es, this message translates to:
  /// **'Usar esta ubicación'**
  String get locationPickerUseThisLocation;

  /// Resolved coordinates readout
  ///
  /// In es, this message translates to:
  /// **'Coordenadas: {value}'**
  String locationPickerCoordinates(String value);

  /// Location picker permission denied error
  ///
  /// In es, this message translates to:
  /// **'Permiso de ubicación denegado'**
  String get locationPickerDenied;

  /// Location picker device-location failure
  ///
  /// In es, this message translates to:
  /// **'Ubicación no disponible'**
  String get locationPickerUnavailable;

  /// Location picker link/coords resolve failure
  ///
  /// In es, this message translates to:
  /// **'No se pudo resolver esa ubicación'**
  String get locationPickerResolveFailed;

  /// Location picker empty-input prompt
  ///
  /// In es, this message translates to:
  /// **'Primero pega un enlace o coordenadas'**
  String get locationPickerPastePrompt;

  /// Neutral flag-gate fallback heading (no coming-soon copy)
  ///
  /// In es, this message translates to:
  /// **'No disponible'**
  String get featureUnavailableTitle;

  /// Neutral flag-gate fallback body
  ///
  /// In es, this message translates to:
  /// **'Esta función aún no está disponible.'**
  String get featureUnavailableBody;

  /// Event collage screen app bar title
  ///
  /// In es, this message translates to:
  /// **'collage'**
  String get collageTitle;

  /// Event collage empty state heading
  ///
  /// In es, this message translates to:
  /// **'Aún no hay fotos para el collage'**
  String get collageEmpty;

  /// Event collage empty state body
  ///
  /// In es, this message translates to:
  /// **'El collage se arma solo con las fotos del evento.'**
  String get collageEmptyBody;

  /// Event collage photo count label
  ///
  /// In es, this message translates to:
  /// **'{count} fotos'**
  String collagePhotoCount(int count);

  /// Global banner shown while the device has no network connection (I-67)
  ///
  /// In es, this message translates to:
  /// **'Sin conexión — los datos podrían no estar actualizados'**
  String get connectivityOfflineBanner;

  /// Dismissible banner shown after the app recovered from a previous crash (LOG-03)
  ///
  /// In es, this message translates to:
  /// **'La app se recuperó de un cierre inesperado'**
  String get crashRecoveryBannerTitle;

  /// Long-press action: show the own message's delivery/read status sheet
  ///
  /// In es, this message translates to:
  /// **'Información del mensaje'**
  String get chatMessageInfo;

  /// Message-info sheet: the send timestamp label
  ///
  /// In es, this message translates to:
  /// **'Enviado'**
  String get chatMessageInfoSent;

  /// Message-info sheet (group): how many of the other members read the message. {count} readers, {total} other members
  ///
  /// In es, this message translates to:
  /// **'Leído por {count} de {total}'**
  String chatMessageInfoReadBy(int count, int total);

  /// Message-info sheet (1:1): the read timestamp label
  ///
  /// In es, this message translates to:
  /// **'Leído'**
  String get chatMessageInfoReadAt;

  /// Message-info sheet (1:1): the peer has not read the message yet
  ///
  /// In es, this message translates to:
  /// **'No leído'**
  String get chatMessageInfoNotRead;

  /// App bar title of the minigame player picker
  ///
  /// In es, this message translates to:
  /// **'invitar'**
  String get minigamesInviteTitle;

  /// App bar confirm action for the minigame player picker
  ///
  /// In es, this message translates to:
  /// **'Enviar ({count})'**
  String minigamesInviteCount(int count);

  /// App bar title of the minigame session detail
  ///
  /// In es, this message translates to:
  /// **'partida'**
  String get minigamesDetailTitle;

  /// Partida lobby: heading above the realtime participant list
  ///
  /// In es, this message translates to:
  /// **'Jugadores'**
  String get minigamesParticipantsTitle;

  /// Partida lobby: the ready chip/label on a participant row
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get minigamesReady;

  /// Partida lobby: a participant who has not toggled ready
  ///
  /// In es, this message translates to:
  /// **'No listo'**
  String get minigamesNotReady;

  /// Partida lobby: the emphasized ready toggle for a non-creator participant who is not ready yet
  ///
  /// In es, this message translates to:
  /// **'¿Listo?'**
  String get minigamesReadyQuestion;

  /// Partida lobby: marker on the session creator's participant row
  ///
  /// In es, this message translates to:
  /// **'Anfitrión'**
  String get minigamesCreator;

  /// Partida lobby: creator-only button that starts the partida
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get minigamesStart;

  /// Partida lobby: button for a returning participant (host or player) to get back into an already-running match
  ///
  /// In es, this message translates to:
  /// **'Volver a la partida'**
  String get minigamesRejoin;

  /// Partida lobby: creator-only tooltip/action to remove a participant
  ///
  /// In es, this message translates to:
  /// **'Quitar jugador'**
  String get minigamesRemovePlayer;

  /// Partida lobby: confirmation dialog title before removing a participant
  ///
  /// In es, this message translates to:
  /// **'¿Quitar a {name} de esta partida?'**
  String minigamesRemovePlayerConfirm(String name);

  /// Partida lobby: confirmation dialog body before removing a participant
  ///
  /// In es, this message translates to:
  /// **'Se le devolverá su apuesta y se le quitará del juego.'**
  String get minigamesRemovePlayerConfirmBody;

  /// Partida lobby: error when a non-creator tries to start
  ///
  /// In es, this message translates to:
  /// **'Solo el anfitrión puede empezar la partida.'**
  String get minigamesStartOnlyCreator;

  /// Lobby: host's Start is blocked until every other player is ready (2+ names)
  ///
  /// In es, this message translates to:
  /// **'Falta que {names} marquen Listo'**
  String minigamesWaitingReady(String names);

  /// Lobby: host's Start is blocked until every other player is ready (one name)
  ///
  /// In es, this message translates to:
  /// **'Falta que {name} marque Listo'**
  String minigamesWaitingReadyOne(String name);

  /// Rules sheet heading, shared by every game
  ///
  /// In es, this message translates to:
  /// **'Cómo se juega'**
  String get minigamesRulesTitle;

  /// Play-screen action that opens the rules sheet
  ///
  /// In es, this message translates to:
  /// **'Cómo se juega'**
  String get minigamesRulesAction;

  /// Rules step for the truthDare sheet
  ///
  /// In es, this message translates to:
  /// **'Cada ronda le toca a una persona: elige Verdad o Reto.'**
  String get truthDareRule1;

  /// Rules step for the truthDare sheet
  ///
  /// In es, this message translates to:
  /// **'La app saca al azar una pregunta o un reto.'**
  String get truthDareRule2;

  /// Rules step for the truthDare sheet
  ///
  /// In es, this message translates to:
  /// **'Responde o cúmplelo y envía tu respuesta al grupo.'**
  String get truthDareRule3;

  /// Rules step for the truthDare sheet
  ///
  /// In es, this message translates to:
  /// **'Los demás reaccionan y el turno pasa al siguiente.'**
  String get truthDareRule4;

  /// Rules step for the bottle sheet
  ///
  /// In es, this message translates to:
  /// **'La mesa se reparte en porciones: una por jugador.'**
  String get bottleRule1;

  /// Rules step for the bottle sheet
  ///
  /// In es, this message translates to:
  /// **'Toca Girar y, cuando quieras, toca Parar.'**
  String get bottleRule2;

  /// Rules step for the bottle sheet
  ///
  /// In es, this message translates to:
  /// **'La botella frena sola: la porción que señala es la elegida.'**
  String get bottleRule3;

  /// Rules step for the bottle sheet
  ///
  /// In es, this message translates to:
  /// **'Esa persona cumple el reto que aparece y se vuelve a girar.'**
  String get bottleRule4;

  /// Rules step for the twoLies sheet
  ///
  /// In es, this message translates to:
  /// **'Cada ronda le toca a una persona: escribe 3 afirmaciones sobre sí misma.'**
  String get twoLiesRule1;

  /// Rules step for the twoLies sheet
  ///
  /// In es, this message translates to:
  /// **'Dos son mentira y una es verdad. Nadie más las ve mientras las escribe.'**
  String get twoLiesRule2;

  /// Rules step for the twoLies sheet
  ///
  /// In es, this message translates to:
  /// **'Los demás votan cuál creen que es la verdadera.'**
  String get twoLiesRule3;

  /// Rules step for the twoLies sheet
  ///
  /// In es, this message translates to:
  /// **'Se revela la respuesta, se reparten puntos y pasa el turno.'**
  String get twoLiesRule4;

  /// Partida lobby: shown before the creator starts the game
  ///
  /// In es, this message translates to:
  /// **'Esperando jugadores...'**
  String get minigamesWaitingForPlayers;

  /// Hub toggle: play without a group (direct session)
  ///
  /// In es, this message translates to:
  /// **'Directa'**
  String get minigamesScopeDirect;

  /// Hub toggle: play inside a group
  ///
  /// In es, this message translates to:
  /// **'Grupo'**
  String get minigamesScopeGroup;

  /// Home games sheet: start a group-less (direct) session
  ///
  /// In es, this message translates to:
  /// **'Jugar directo'**
  String get minigamesPlayDirect;

  /// Hub: switch to another group
  ///
  /// In es, this message translates to:
  /// **'Cambiar grupo'**
  String get minigamesChangeGroup;

  /// Direct hub: empty state title
  ///
  /// In es, this message translates to:
  /// **'Aún no hay partidas directas'**
  String get minigamesDirectEmpty;

  /// Direct hub: empty state body
  ///
  /// In es, this message translates to:
  /// **'Crea una partida para jugar ya con un amigo, sin necesidad de un grupo.'**
  String get minigamesDirectEmptyBody;

  /// Create/join/accept rejection: the session is at its frozen player cap
  ///
  /// In es, this message translates to:
  /// **'Esta partida alcanzó su límite de jugadores.'**
  String get minigamesErrorPlayerLimitReached;

  /// Create rejection: p_rounds < 1 (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'El número de rondas no es válido.'**
  String get minigamesErrorInvalidRounds;

  /// Create rejection: p_prize_positions < 1 (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'El número de puestos premiados no es válido.'**
  String get minigamesErrorInvalidPrizePositions;

  /// Create rejection: p_play_mode is not by_turns/async (202_minigame_play_v2)
  ///
  /// In es, this message translates to:
  /// **'El modo de juego no es válido.'**
  String get minigamesErrorInvalidPlayMode;

  /// Create rejection: p_async_rounds_per_player < 1 (202_minigame_play_v2)
  ///
  /// In es, this message translates to:
  /// **'Las rondas por jugador no son válidas.'**
  String get minigamesErrorInvalidAsyncRounds;

  /// Create rejection: async deadline missing/past (202_minigame_play_v2)
  ///
  /// In es, this message translates to:
  /// **'La fecha de fin de la partida asíncrona no es válida.'**
  String get minigamesErrorInvalidAsyncEndsAt;

  /// Join/finish rejection: a non-participant on a direct session
  ///
  /// In es, this message translates to:
  /// **'No puedes unirte a esta partida.'**
  String get minigamesErrorNotAllowed;

  /// Session detail: the user has a pending invite
  ///
  /// In es, this message translates to:
  /// **'Te invitaron a esta partida.'**
  String get minigamesInvitePendingBody;

  /// Per-game list pending invite: who invited you (direct session)
  ///
  /// In es, this message translates to:
  /// **'Invitado por {name}'**
  String minigamesInviteFromDirect(String name);

  /// Per-game list pending invite: which group invited you (group session)
  ///
  /// In es, this message translates to:
  /// **'Grupo {name}'**
  String minigamesInviteFromGroup(String name);

  /// Group chat notice bubble: a group match was created (216_minigame_group_message)
  ///
  /// In es, this message translates to:
  /// **'Nueva partida de {game}'**
  String minigamesGroupMessage(String game);

  /// Group chat notice: direct access to the minigame
  ///
  /// In es, this message translates to:
  /// **'Unirse'**
  String get minigamesJoin;

  /// Group chat notice: view a finished minigame
  ///
  /// In es, this message translates to:
  /// **'Ver'**
  String get minigamesView;

  /// Session detail pending invite: subtitle under the inviter's username (mirrors the participant 'Anfitrión' subtitle)
  ///
  /// In es, this message translates to:
  /// **'Invitado por'**
  String get minigamesInvitedBy;

  /// Session detail: accept the pending invite button
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get minigamesInviteAccept;

  /// Session detail: decline the pending invite button
  ///
  /// In es, this message translates to:
  /// **'Rechazar'**
  String get minigamesInviteDecline;

  /// Snackbar after accepting a minigame invite
  ///
  /// In es, this message translates to:
  /// **'Te uniste a la partida'**
  String get minigamesInviteAccepted;

  /// Snackbar after declining a minigame invite
  ///
  /// In es, this message translates to:
  /// **'Invitación rechazada'**
  String get minigamesInviteDeclined;

  /// Snackbar after the HOST invites players from the lobby (205_minigame_invite_lobby)
  ///
  /// In es, this message translates to:
  /// **'Invitación enviada'**
  String get minigamesInviteSent;

  /// Lobby invite picker: compact right-aligned tag on a user who already holds a pending invite for this session
  ///
  /// In es, this message translates to:
  /// **'enviada'**
  String get minigamesInviteSentTag;

  /// Session detail: the invite can no longer be accepted because the game finished
  ///
  /// In es, this message translates to:
  /// **'Esta partida ya terminó. Ya no puedes aceptar la invitación.'**
  String get minigamesInviteClosed;

  /// Removed-player popup title when the host kicks the current user
  ///
  /// In es, this message translates to:
  /// **'¡Oops!'**
  String get minigamesKickedTitle;

  /// Settings switch label: friends-only minigame invites
  ///
  /// In es, this message translates to:
  /// **'Solo amigos pueden invitarme'**
  String get minigamesInviteFriendsOnly;

  /// Settings switch body: explains the friends-only invite privacy option
  ///
  /// In es, this message translates to:
  /// **'Cuando está activado, solo tus amigos pueden invitarte a un minijuego.'**
  String get minigamesInviteFriendsOnlyBody;

  /// Settings snackbar when persisting the friends-only invite switch fails
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la preferencia.'**
  String get minigamesInviteFriendsOnlySaveError;

  /// Button to navigate to an ongoing game from the lobby
  ///
  /// In es, this message translates to:
  /// **'Ir a la partida'**
  String get minigamesGoToGame;

  /// Header for each statement input
  ///
  /// In es, this message translates to:
  /// **'Afirmación {number}'**
  String minigamesTwoLiesStatementNumber(int number);

  /// Snackbar prompt shown when submitting without marking the truth statement
  ///
  /// In es, this message translates to:
  /// **'Marca cuál es la verdad'**
  String get minigamesTwoLiesMarkTruthPrompt;

  /// Header for voters asking which statement is the truth
  ///
  /// In es, this message translates to:
  /// **'¿Cuál de estas 3 afirmaciones es LA VERDAD?'**
  String get minigamesTwoLiesGuessPrompt;

  /// Hint telling the subject to long-press a card to mark their true statement
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada una tarjeta para marcar tu verdad'**
  String get minigamesTwoLiesHoldHint;

  /// Button to confirm vote for the selected statement
  ///
  /// In es, this message translates to:
  /// **'Votar por esta opción'**
  String get minigamesTwoLiesVoteConfirm;

  /// Badge showing that voter's guess has been recorded
  ///
  /// In es, this message translates to:
  /// **'Tu voto está registrado'**
  String get minigamesTwoLiesVoteConfirmed;

  /// Badge marking the revealed true statement
  ///
  /// In es, this message translates to:
  /// **'LA VERDAD'**
  String get minigamesTwoLiesTruthBadge;

  /// Badge marking a revealed lie statement
  ///
  /// In es, this message translates to:
  /// **'MENTIRA'**
  String get minigamesTwoLiesLieBadge;

  /// Waiting message shown to non-subjects while subject is writing
  ///
  /// In es, this message translates to:
  /// **'{name} está escribiendo sus 3 afirmaciones...'**
  String minigamesTwoLiesWaitingSubject(String name);

  /// Tally shown to the subject after submitting
  ///
  /// In es, this message translates to:
  /// **'Esperando los votos de los demás... ({voted}/{total})'**
  String minigamesTwoLiesWaitingVotes(int voted, int total);

  /// Validation error when some statements are empty
  ///
  /// In es, this message translates to:
  /// **'Debes completar las 3 afirmaciones'**
  String get minigamesTwoLiesFillAllError;

  /// Attendance code: return button on the already-attended terminal state
  ///
  /// In es, this message translates to:
  /// **'Regresar'**
  String get codeAlreadyAttendedReturn;

  /// Finished-game leaderboard title (201_minigame_voting)
  ///
  /// In es, this message translates to:
  /// **'Clasificación'**
  String get minigamesLeaderboardTitle;

  /// Chat long-press action: report the specific message (226_chat_moderation)
  ///
  /// In es, this message translates to:
  /// **'Reportar mensaje'**
  String get chatReportMessage;

  /// Chat long-press action: block the message sender (226_chat_moderation)
  ///
  /// In es, this message translates to:
  /// **'Bloquear usuario'**
  String get chatBlockUser;

  /// Legal screen action: open the policy in the browser
  ///
  /// In es, this message translates to:
  /// **'Ver en el navegador'**
  String get legalOpenOnline;

  /// Q17: missing DOB blocked before create_my_profile
  ///
  /// In es, this message translates to:
  /// **'La fecha de nacimiento es obligatoria.'**
  String get authDobRequired;

  /// Q17: unparsable DOB blocked before create_my_profile
  ///
  /// In es, this message translates to:
  /// **'La fecha de nacimiento no es válida.'**
  String get authDobInvalid;

  /// SEC-050: export file path shown to the user
  ///
  /// In es, this message translates to:
  /// **'Copia guardada en el almacenamiento de la app:'**
  String get profileExportSaved;

  /// No description provided for @notificationCategoryMinigames.
  ///
  /// In es, this message translates to:
  /// **'Minijuegos'**
  String get notificationCategoryMinigames;

  /// No description provided for @notificationCategoryMarketing.
  ///
  /// In es, this message translates to:
  /// **'Promociones'**
  String get notificationCategoryMarketing;

  /// No description provided for @notificationCategorySecurity.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get notificationCategorySecurity;

  /// No description provided for @notificationCategoryModeration.
  ///
  /// In es, this message translates to:
  /// **'Moderación'**
  String get notificationCategoryModeration;

  /// No description provided for @notificationCategoryLegal.
  ///
  /// In es, this message translates to:
  /// **'Legal'**
  String get notificationCategoryLegal;

  /// No description provided for @notificationCategoryAlwaysOnTitle.
  ///
  /// In es, this message translates to:
  /// **'Siempre se entregan'**
  String get notificationCategoryAlwaysOnTitle;

  /// No description provided for @notificationCategoryAlwaysOn.
  ///
  /// In es, this message translates to:
  /// **'Siempre activo'**
  String get notificationCategoryAlwaysOn;

  /// No description provided for @notificationSettingsServerNote.
  ///
  /// In es, this message translates to:
  /// **'Estas preferencias se guardan en tu cuenta.'**
  String get notificationSettingsServerNote;

  /// No description provided for @notificationSettingsSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la preferencia.'**
  String get notificationSettingsSaveError;

  /// No description provided for @profileMutedUsers.
  ///
  /// In es, this message translates to:
  /// **'Usuarios silenciados'**
  String get profileMutedUsers;

  /// No description provided for @friendsNoneMuted.
  ///
  /// In es, this message translates to:
  /// **'No hay usuarios silenciados'**
  String get friendsNoneMuted;

  /// No description provided for @friendsUnmute.
  ///
  /// In es, this message translates to:
  /// **'Reactivar'**
  String get friendsUnmute;

  /// No description provided for @profileMute.
  ///
  /// In es, this message translates to:
  /// **'Silenciar'**
  String get profileMute;

  /// No description provided for @profileUnmute.
  ///
  /// In es, this message translates to:
  /// **'Reactivar'**
  String get profileUnmute;

  /// No description provided for @profileUserMuted.
  ///
  /// In es, this message translates to:
  /// **'Usuario silenciado'**
  String get profileUserMuted;

  /// No description provided for @profileMuteError.
  ///
  /// In es, this message translates to:
  /// **'Error al silenciar'**
  String get profileMuteError;

  /// No description provided for @reportTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportar contenido'**
  String get reportTitle;

  /// No description provided for @reportSent.
  ///
  /// In es, this message translates to:
  /// **'Gracias por reportar. Lo revisaremos.'**
  String get reportSent;

  /// No description provided for @reportCategoryHarassment.
  ///
  /// In es, this message translates to:
  /// **'Acoso o abuso'**
  String get reportCategoryHarassment;

  /// No description provided for @reportCategoryHate.
  ///
  /// In es, this message translates to:
  /// **'Discurso de odio'**
  String get reportCategoryHate;

  /// No description provided for @reportCategorySpam.
  ///
  /// In es, this message translates to:
  /// **'Spam'**
  String get reportCategorySpam;

  /// No description provided for @reportCategoryImpersonation.
  ///
  /// In es, this message translates to:
  /// **'Suplantación de identidad'**
  String get reportCategoryImpersonation;

  /// No description provided for @reportCategoryNcii.
  ///
  /// In es, this message translates to:
  /// **'Imágenes íntimas sin consentimiento'**
  String get reportCategoryNcii;

  /// No description provided for @reportCategoryThreat.
  ///
  /// In es, this message translates to:
  /// **'Amenaza creíble'**
  String get reportCategoryThreat;

  /// No description provided for @reportCategoryCsam.
  ///
  /// In es, this message translates to:
  /// **'Contenido ilegal'**
  String get reportCategoryCsam;

  /// No description provided for @reportCategoryOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get reportCategoryOther;

  /// No description provided for @reportAvatar.
  ///
  /// In es, this message translates to:
  /// **'Reportar avatar'**
  String get reportAvatar;

  /// No description provided for @reportGroupCover.
  ///
  /// In es, this message translates to:
  /// **'Reportar portada del grupo'**
  String get reportGroupCover;

  /// No description provided for @reportEventDescription.
  ///
  /// In es, this message translates to:
  /// **'Reportar descripción del evento'**
  String get reportEventDescription;

  /// No description provided for @reportMinigameAnswer.
  ///
  /// In es, this message translates to:
  /// **'Reportar respuesta'**
  String get reportMinigameAnswer;

  /// No description provided for @appealsTitle.
  ///
  /// In es, this message translates to:
  /// **'Apelaciones'**
  String get appealsTitle;

  /// No description provided for @appealsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No tienes apelaciones'**
  String get appealsEmpty;

  /// No description provided for @appealsSubmit.
  ///
  /// In es, this message translates to:
  /// **'Enviar apelación'**
  String get appealsSubmit;

  /// No description provided for @appealsMessageHint.
  ///
  /// In es, this message translates to:
  /// **'Explica por qué esta decisión debe revisarse (mínimo 10 caracteres).'**
  String get appealsMessageHint;

  /// No description provided for @appealsSubmitted.
  ///
  /// In es, this message translates to:
  /// **'Apelación enviada. La revisaremos.'**
  String get appealsSubmitted;

  /// No description provided for @appealStatusOpen.
  ///
  /// In es, this message translates to:
  /// **'Abierta'**
  String get appealStatusOpen;

  /// No description provided for @appealStatusReviewing.
  ///
  /// In es, this message translates to:
  /// **'En revisión'**
  String get appealStatusReviewing;

  /// No description provided for @appealStatusUpheld.
  ///
  /// In es, this message translates to:
  /// **'Rechazada'**
  String get appealStatusUpheld;

  /// No description provided for @appealStatusOverturned.
  ///
  /// In es, this message translates to:
  /// **'Aceptada'**
  String get appealStatusOverturned;

  /// No description provided for @appealStatusClosed.
  ///
  /// In es, this message translates to:
  /// **'Cerrada'**
  String get appealStatusClosed;

  /// No description provided for @reportOutcomesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus reportes'**
  String get reportOutcomesTitle;

  /// No description provided for @reportOutcomeEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay resultados de reportes'**
  String get reportOutcomeEmpty;

  /// No description provided for @bannedAppealCta.
  ///
  /// In es, this message translates to:
  /// **'Apelar esta decisión'**
  String get bannedAppealCta;

  /// No description provided for @bannedAppealTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviar apelación de suspensión'**
  String get bannedAppealTitle;

  /// No description provided for @bannedAppealSubmitted.
  ///
  /// In es, this message translates to:
  /// **'Apelación de suspensión enviada.'**
  String get bannedAppealSubmitted;

  /// No description provided for @eventsVenueLabel.
  ///
  /// In es, this message translates to:
  /// **'Lugar exacto'**
  String get eventsVenueLabel;

  /// No description provided for @eventsCityLabel.
  ///
  /// In es, this message translates to:
  /// **'Ciudad'**
  String get eventsCityLabel;

  /// No description provided for @eventsShareLink.
  ///
  /// In es, this message translates to:
  /// **'Compartir enlace'**
  String get eventsShareLink;

  /// No description provided for @eventsShareLinkRotate.
  ///
  /// In es, this message translates to:
  /// **'Rotar enlace'**
  String get eventsShareLinkRotate;

  /// No description provided for @eventsShareLinkRevoke.
  ///
  /// In es, this message translates to:
  /// **'Revocar enlace'**
  String get eventsShareLinkRevoke;

  /// No description provided for @eventsShareLinkCopied.
  ///
  /// In es, this message translates to:
  /// **'Enlace copiado'**
  String get eventsShareLinkCopied;

  /// No description provided for @eventsShareLinkCopiedBody.
  ///
  /// In es, this message translates to:
  /// **'Comparte este enlace: {url}'**
  String eventsShareLinkCopiedBody(String url);

  /// No description provided for @eventsShareLinkRevoked.
  ///
  /// In es, this message translates to:
  /// **'Enlace revocado'**
  String get eventsShareLinkRevoked;

  /// No description provided for @linkConsentTitle.
  ///
  /// In es, this message translates to:
  /// **'Invitación'**
  String get linkConsentTitle;

  /// No description provided for @linkJoinEvent.
  ///
  /// In es, this message translates to:
  /// **'Unirme al evento'**
  String get linkJoinEvent;

  /// No description provided for @linkRequestJoin.
  ///
  /// In es, this message translates to:
  /// **'Solicitar unirme'**
  String get linkRequestJoin;

  /// No description provided for @linkJoinGroup.
  ///
  /// In es, this message translates to:
  /// **'Unirme al grupo'**
  String get linkJoinGroup;

  /// No description provided for @linkAddFriend.
  ///
  /// In es, this message translates to:
  /// **'Enviar solicitud'**
  String get linkAddFriend;

  /// No description provided for @linkRequestSent.
  ///
  /// In es, this message translates to:
  /// **'Solicitud enviada'**
  String get linkRequestSent;

  /// No description provided for @linkEventJoined.
  ///
  /// In es, this message translates to:
  /// **'Te uniste al evento'**
  String get linkEventJoined;

  /// No description provided for @linkInvalid.
  ///
  /// In es, this message translates to:
  /// **'Enlace inválido o vencido'**
  String get linkInvalid;

  /// No description provided for @linkDistance.
  ///
  /// In es, this message translates to:
  /// **'a {km} km'**
  String linkDistance(String km);

  /// No description provided for @linkAlreadyMember.
  ///
  /// In es, this message translates to:
  /// **'Ya eres miembro'**
  String get linkAlreadyMember;

  /// No description provided for @linkOwnProfile.
  ///
  /// In es, this message translates to:
  /// **'Este es tu perfil'**
  String get linkOwnProfile;
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
