// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Samay';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonReject => 'Reject';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonPassword => 'Password';

  @override
  String get commonConfirmPassword => 'Confirm password';

  @override
  String get commonUsername => 'Username';

  @override
  String get commonUser => 'User';

  @override
  String get commonGroup => 'Group';

  @override
  String get commonFriends => 'Friends';

  @override
  String get commonCreateAccount => 'Create account';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonError => 'Error';

  @override
  String get commonInvite => 'Invite';

  @override
  String get commonMoreOptions => 'More options';

  @override
  String get welcomeVive => 'VIVE';

  @override
  String get welcomeTagline => 'Your social life, all in one place';

  @override
  String get authVerifyAge => 'Verify age';

  @override
  String get authBirthDateQuestion => 'What is your date of birth?';

  @override
  String get authMinAgeMessage =>
      'You must be at least 18 years old to use Samay';

  @override
  String get authSelectDate => 'Select date';

  @override
  String get authUnderageMessage => 'You must be 18 years old to use Samay';

  @override
  String authSelectedDate(int day, int month, int year) {
    return '$day/$month/$year';
  }

  @override
  String get authForgotPassword => 'Forgot my password';

  @override
  String get authUnknownLoginError => 'Unknown error signing in';

  @override
  String get authVerifyCode => 'Verify code';

  @override
  String get authEnterVerificationCode => 'Enter the verification code';

  @override
  String authOtpSentTo(String email) {
    return 'We sent a 6-digit code to $email';
  }

  @override
  String get authVerify => 'Verify';

  @override
  String get authResendCode => 'Resend code';

  @override
  String authResendCodeIn(int seconds) {
    return 'Resend code (${seconds}s)';
  }

  @override
  String get authOtpTooManyAttempts =>
      'Too many failed attempts. Request a new code.';

  @override
  String get authEmailAlreadyRegistered => 'Email already registered';

  @override
  String get authEmailAlreadyRegisteredBody =>
      'This email already has a complete account. Sign in instead.';

  @override
  String get authBackToLogin => 'Back to sign in';

  @override
  String authOtpAttemptsRemaining(int attempts) {
    String _temp0 = intl.Intl.pluralLogic(
      attempts,
      locale: localeName,
      other: '$attempts attempts left',
      one: '1 attempt left',
    );
    return 'You have $_temp0';
  }

  @override
  String get authForgotPasswordTitle => 'Recover password';

  @override
  String get authForgotPasswordHeading => 'Forgot your password?';

  @override
  String get authForgotPasswordHint =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get authForgotPasswordSend => 'Send link';

  @override
  String get authForgotPasswordSuccessTitle => 'Check your email';

  @override
  String authForgotPasswordSuccessBody(String email) {
    return 'If an account exists for $email, you\'ll receive a link to reset your password.';
  }

  @override
  String get authForgotPasswordSnack =>
      'We sent you a link to reset your password';

  @override
  String get authTermsTitle => 'Terms and conditions';

  @override
  String get authAcceptTermsToContinue => 'Accept the terms to continue';

  @override
  String get authPrivacyPolicy => 'I accept the Privacy Policy';

  @override
  String get authPrivacyPolicySubtitle =>
      'Learn how we handle your personal data';

  @override
  String get authServiceTerms => 'I accept the Terms of Service';

  @override
  String get authServiceTermsSubtitle => 'Terms of use of the application';

  @override
  String get authCompleteProfile => 'Complete your profile';

  @override
  String get authUsernameHint => '@username';

  @override
  String get authUsernameImmutable =>
      'You won\'t be able to change your username after registration.';

  @override
  String get authCreateYourAccount => 'Create your account';

  @override
  String get authSignupSubtitle => 'Enter your email and create a password';

  @override
  String get authPasswordWithRequirements =>
      'Password (min. 8 characters, 1 number)';

  @override
  String get authPasswordTooWeak =>
      'The password must be at least 8 characters and contain a number.';

  @override
  String get authPasswordsDontMatch => 'The passwords don\'t match.';

  @override
  String get bannedTitle => 'Account suspended';

  @override
  String get bannedDefaultBody => 'Your account has been suspended.';

  @override
  String bannedReasonLabel(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get feedBrand => 'Samay';

  @override
  String get feedFeatured => 'Featured';

  @override
  String get feedFeaturedBadge => 'Featured';

  @override
  String feedRadiusKm(int radius) {
    return '$radius km';
  }

  @override
  String get feedRadiusAnywhere => 'Anywhere';

  @override
  String get feedNoLocationNotice =>
      'No location available — showing all events';

  @override
  String get feedNoEvents => 'No upcoming events';

  @override
  String get feedNoEventsBody => 'Check back soon for new events near you.';

  @override
  String get feedLoadError => 'Couldn\'t load the feed';

  @override
  String get shellFeed => 'Feed';

  @override
  String get shellGroups => 'Groups';

  @override
  String get shellEvents => 'Events';

  @override
  String get shellNotifications => 'Notis';

  @override
  String get shellProfile => 'Profile';

  @override
  String get friendsTitle => 'Friends';

  @override
  String get friendsBlockedTitle => 'Blocked users';

  @override
  String get friendsNoneBlocked => 'You haven\'t blocked anyone';

  @override
  String get friendsUnblock => 'Unblock';

  @override
  String get friendsSearchHint => 'Search among friends';

  @override
  String get friendsNoneYet => 'No friends yet';

  @override
  String get friendsSearchPrompt => 'Search for users to add friends';

  @override
  String get friendsNoResults => 'No results';

  @override
  String get friendsRequestsTitle => 'Requests';

  @override
  String get friendsTabReceived => 'Received';

  @override
  String get friendsTabSent => 'Sent';

  @override
  String get friendsTabInvites => 'Invitations';

  @override
  String get friendsNoReceived => 'No received requests';

  @override
  String get friendsNoSent => 'No sent requests';

  @override
  String get friendsSentYouRequest => 'Sent you a request';

  @override
  String get friendsRequestSent => 'Request sent';

  @override
  String get friendsNoInvites => 'No invitations';

  @override
  String get friendsSearchUsers => 'Search users';

  @override
  String get friendsSearchPlaceholder => 'Search by username';

  @override
  String get friendsNoUsersFound => 'No users found';

  @override
  String get friendsStatusAccepted => 'Friends';

  @override
  String get friendsStatusPending => 'Requested';

  @override
  String get friendsStatusBlocked => 'Blocked';

  @override
  String get friendsAddFriendButton => 'Add';

  @override
  String get friendsMinCharsHint => 'Type at least 2 characters to search';

  @override
  String get friendsMutualAcceptedTitle => 'Request accepted!';

  @override
  String get friendsMutualAcceptedBody =>
      'You both sent a request: you are friends now.';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsTooltipFindFriends => 'Find friends';

  @override
  String get groupsCreateGroup => 'Create group';

  @override
  String get groupsRanking => 'Ranking';

  @override
  String get groupsRequests => 'Requests';

  @override
  String get groupsNoneYet => 'You don\'t belong to any group';

  @override
  String get groupsNoneYetSubtitle => 'Create a group or join an existing one';

  @override
  String get groupsLimitReached => 'Limit reached';

  @override
  String get groupsLimitReachedBody =>
      'You\'ve reached the limit of 5 groups as a promotor. Upgrade your subscription to create more.';

  @override
  String get groupsCreatedSnack => 'Group created';

  @override
  String get groupsAddCover => 'Add cover photo';

  @override
  String get groupsNameLabel => 'Group name';

  @override
  String get groupsDescriptionOptional => 'Description (optional)';

  @override
  String get groupsInvalidAmount => 'Enter a valid amount';

  @override
  String get groupsDonationSuccess => 'Donation successful';

  @override
  String get groupsDonateTitle => 'Donate shards';

  @override
  String groupsDonateTo(String groupName) {
    return 'Donate to $groupName';
  }

  @override
  String get groupsDonateBlurb =>
      'These shards will boost the group\'s ranking for 14 days';

  @override
  String get groupsShardsAmount => 'Amount of shards';

  @override
  String get groupsDonate => 'Donate';

  @override
  String get groupsTabChat => 'Chat';

  @override
  String get groupsTabMembers => 'Members';

  @override
  String get groupsTabEvents => 'Events';

  @override
  String get groupsFrozenBadge => 'Frozen group';

  @override
  String get groupsLeave => 'Leave group';

  @override
  String get groupsFrozenBanner =>
      'Frozen group — upgrade your subscription or transfer the promotor role';

  @override
  String groupsShardsCount(int shards) {
    return '$shards group shards';
  }

  @override
  String groupsMemberCount(int members, int limit) {
    return '$members / $limit members';
  }

  @override
  String groupsMyContribution(int shards) {
    return 'My contribution: $shards active shards';
  }

  @override
  String get groupsCreateEvent => 'Create event';

  @override
  String get groupsChatComingSoon => 'Chat coming soon';

  @override
  String get groupsNoMembers => 'No members';

  @override
  String get groupsTopContributors => 'Top contributors';

  @override
  String groupsShardsCountShort(int shards) {
    return '$shards shards';
  }

  @override
  String groupsMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get groupsEventsComingSoon => 'Events coming soon';

  @override
  String get groupsConfirmLeave => 'Are you sure?';

  @override
  String get groupsAbandon => 'Leave';

  @override
  String get groupsPromoteCoPromotor => 'Make co-promoter';

  @override
  String get groupsDemoteMember => 'Make member';

  @override
  String get groupsKickMember => 'Remove from group';

  @override
  String groupsKickConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get groupsKickConfirmBody => 'This action cannot be undone.';

  @override
  String get groupsKick => 'Remove';

  @override
  String get groupsNotFound => 'The group was not found';

  @override
  String get groupsMembersTitle => 'Members';

  @override
  String get groupsInviteTitle => 'Invite';

  @override
  String groupsInviteCount(int count) {
    return 'Invite ($count)';
  }

  @override
  String groupsInvitedCount(int count) {
    return '$count invited';
  }

  @override
  String get groupsSearchUsersHint => 'Search users by username...';

  @override
  String get groupsMinCharsHint => 'Type at least 2 characters to search';

  @override
  String get groupsNoResults => 'No results';

  @override
  String get groupsLeaderboardTitle => 'Group rankings';

  @override
  String get groupsNoRankingData => 'No ranking data';

  @override
  String groupsLeaderboardSubtitle(int count, int score) {
    return '$count members · $score shards';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileEditTitle => 'Edit profile';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSubscription => 'Subscription';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profilePrivacy => 'Privacy';

  @override
  String get profileBlockedUsers => 'Blocked users';

  @override
  String get profileDeleteMyAccount => 'Delete my account';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignOutQuestion => 'Sign out?';

  @override
  String get profileSignOutBody =>
      'Your session will be closed on this device.';

  @override
  String get profileVersion => 'Samay v1.0.0';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get profileBio => 'Bio';

  @override
  String get profileSaveChanges => 'Save changes';

  @override
  String get profileChangePassword => 'Change password';

  @override
  String get profileUpdatedSnack => 'Profile updated';

  @override
  String get profileMyGroups => 'Groups';

  @override
  String get profileNoGroupsYet => 'You don\'t belong to any group yet';

  @override
  String get profileNoGroupsHint => 'Create or join a group to see it here.';

  @override
  String profileShardsCount(int shards) {
    return '$shards shards';
  }

  @override
  String profilePreshardsCount(int preshards) {
    return '$preshards preshards';
  }

  @override
  String get profileNoBio => 'No bio';

  @override
  String get profileSharedGroups => 'Shared groups';

  @override
  String get profileNoSharedGroups => 'No shared groups';

  @override
  String get profileFriendRequestSent => 'Friend request sent';

  @override
  String get profileRequestAccepted => 'Request accepted';

  @override
  String get profileAcceptError => 'Error accepting request';

  @override
  String get profileReport => 'Report';

  @override
  String get profileBlock => 'Block';

  @override
  String get profileCancelRequest => 'Cancel request';

  @override
  String get profileAccepting => 'Accepting...';

  @override
  String get profileAcceptRequest => 'Accept request';

  @override
  String get profileSending => 'Sending...';

  @override
  String get profileAddFriend => 'Add friend';

  @override
  String get profileReportComingSoon => 'Reporting will be implemented soon';

  @override
  String get profileUserBlocked => 'User blocked';

  @override
  String get profileBlockError => 'Error blocking';

  @override
  String get profileUserUnblocked => 'User unblocked';

  @override
  String get profileUnblockError => 'Error unblocking';

  @override
  String get profileDeleteTitle => 'Delete account';

  @override
  String get profileDeleteQuestion => 'Delete account?';

  @override
  String get profileDeleteBody =>
      'This action cannot be undone. Your data will be anonymized and your account will be permanently deleted after 30 days.';

  @override
  String get profileDeleteExplanation =>
      'When you delete your account, your data will be anonymized. Your messages and group ranking contributions will remain but will not be linked to you. You can recover your account within 30 days.';

  @override
  String get profileConfirmEmail => 'Confirm your email to continue:';

  @override
  String get profileEmailMismatch => 'The email doesn\'t match your account';

  @override
  String get profileCosmetics => 'Cosmetics';

  @override
  String get profileNoCosmeticsYet =>
      'Your cosmetics collection will appear here.';

  @override
  String get profileAvatarUpdatedSnack => 'Profile photo updated';

  @override
  String get profileAvatarChange => 'Change profile photo';

  @override
  String get interestMusica => 'Music';

  @override
  String get interestFiestas => 'Parties';

  @override
  String get interestDeportes => 'Sports';

  @override
  String get interestGaming => 'Gaming';

  @override
  String get interestCine => 'Movies';

  @override
  String get interestArte => 'Art';

  @override
  String get interestViajes => 'Travel';

  @override
  String get interestComida => 'Food';

  @override
  String get comingSoonSoon => 'Coming soon';

  @override
  String get comingSoonBack => 'Back';

  @override
  String get comingSoonEventsTitle => 'Events';

  @override
  String get comingSoonEventsBody =>
      'Your groups\' events will appear here soon.';

  @override
  String get comingSoonNotificationsTitle => 'Notifications';

  @override
  String get comingSoonNotificationsBody =>
      'Your notifications will appear here soon.';

  @override
  String get comingSoonEventTitle => 'Event';

  @override
  String get comingSoonEventBody => 'Event details will be available soon.';

  @override
  String get comingSoonEditEventTitle => 'Edit event';

  @override
  String get comingSoonEditEventBody => 'Event editing will be available soon.';

  @override
  String get comingSoonEventInviteTitle => 'Invite';

  @override
  String get comingSoonEventInviteBody =>
      'Event invitations will be available soon.';

  @override
  String get comingSoonPhotosTitle => 'Photos';

  @override
  String get comingSoonPhotosBody => 'Event photos will be available soon.';

  @override
  String get comingSoonCollageTitle => 'Collage';

  @override
  String get comingSoonCollageBody =>
      'The photo collage will be available soon.';

  @override
  String get comingSoonInvitationTitle => 'Invitation';

  @override
  String get comingSoonInvitationBody =>
      'Event invitations will appear here soon.';

  @override
  String get comingSoonCreateEventTitle => 'Create event';

  @override
  String get comingSoonCreateEventBody =>
      'Event creation will be available soon.';

  @override
  String get comingSoonChatTitle => 'Chat';

  @override
  String get comingSoonChatBody => 'The chat will be available soon.';

  @override
  String get comingSoonQrTitle => 'QR';

  @override
  String get comingSoonQrBody => 'The event QR code will be available soon.';

  @override
  String get comingSoonScannerTitle => 'Scanner';

  @override
  String get comingSoonScannerBody =>
      'The QR code scanner will be available soon.';

  @override
  String get comingSoonSubscriptionsTitle => 'Subscriptions';

  @override
  String get comingSoonSubscriptionsBody =>
      'Subscriptions will be available soon.';

  @override
  String get comingSoonPartyFinderTitle => 'Party Finder';

  @override
  String get comingSoonPartyFinderBody =>
      'The Party Finder will be available soon.';

  @override
  String get paywallHeader => 'Subscription';

  @override
  String get paywallAllTiersVisible =>
      'All plans are visible with no hidden pricing. Choose the one that fits you best.';

  @override
  String get paywallTierFree => 'Free';

  @override
  String get paywallTierPro => 'PRO';

  @override
  String get paywallTierVip => 'VIP';

  @override
  String get paywallPerMonth => '/mo';

  @override
  String paywallAnnualEquivalent(String monthly) {
    return '$monthly saving 17%';
  }

  @override
  String get paywallCurrentBadge => 'Current';

  @override
  String get paywallRestore => 'Restore purchases';

  @override
  String get paywallUpgradePro => 'Upgrade to PRO';

  @override
  String get paywallUpgradeVip => 'Upgrade to VIP';

  @override
  String get paywallRowEvents => 'Events per day';

  @override
  String get paywallRowGroups => 'Max groups';

  @override
  String get paywallRowMembers => 'Members per group';

  @override
  String get paywallRowPreshards => 'Monthly preshards';

  @override
  String get paywallRowFeed => 'Post to feed';

  @override
  String get paywallRowVideo => 'Video souvenir';

  @override
  String get paywallRowCosmetics => 'Group cosmetics';

  @override
  String get paywallRowRank => 'Group rank';

  @override
  String get paywallUnlimited => 'Unlimited';

  @override
  String get paywallLimited => 'Limited';

  @override
  String get paywallCosmeticsFull => 'Full';

  @override
  String get paywallCosmeticsFullExclusive => 'Full + exclusive';

  @override
  String get paywallRankMicro => 'micro';

  @override
  String get paywallRankUpToMedium => 'up to medium';

  @override
  String get paywallRankAll => 'all';

  @override
  String get routerRouteNotFound => 'Route not found';

  @override
  String get routerRouteNotFoundBody =>
      'The requested route doesn\'t exist or isn\'t available. Go back and try again.';

  @override
  String get routerMissingSignupData =>
      'Signup data is missing. Go back and start the signup again.';

  @override
  String get routerMissingAgeGateData =>
      'Age verification data is missing. Go back and try again.';

  @override
  String get routerMissingProfileData =>
      'Signup data is missing. Go back and try again.';

  @override
  String get routerEventNotFound => 'The requested event was not found.';

  @override
  String get routerGroupNotFound => 'The requested group was not found.';

  @override
  String get routerChatNotFound => 'The requested chat was not found.';

  @override
  String get routerUserNotFound => 'The requested user was not found.';

  @override
  String get routerInvalidInvite => 'The requested invitation is not valid.';

  @override
  String get routerErrorTitle => 'Something went wrong';

  @override
  String get routerErrorBody =>
      'This screen could not be shown. Go back and try again.';

  @override
  String get errorsNetwork => 'Connection error. Check your internet.';

  @override
  String get errorsUnauthorized => 'Session expired. Sign in again.';

  @override
  String get errorsServer => 'Server error. Try again.';

  @override
  String get errorsInvalidData => 'Invalid data. Check the fields.';

  @override
  String get errorsPermission =>
      'You don\'t have permission to perform this action.';

  @override
  String get errorsRateLimit => 'Too many requests. Wait a moment.';

  @override
  String errorsNotFound(String resource) {
    return '$resource not found.';
  }

  @override
  String get errorsNotFoundGeneric => 'Not found.';

  @override
  String get errorsInvalidCredentials => 'Invalid email or password';

  @override
  String get errorsOtpExpired => 'The code has expired. Request a new one.';

  @override
  String get errorsInvalidReference => 'Invalid reference';

  @override
  String get errorsAlreadyExists => 'Already exists';

  @override
  String get errorsInvalidFormat => 'Invalid format';

  @override
  String get errorsInsufficientShards => 'You don\'t have enough shards';

  @override
  String get errorsFriendshipExists =>
      'A request or friendship with this user already exists';

  @override
  String get errorsGeneric => 'An error occurred';

  @override
  String get errorCodeLabel => 'Error code';

  @override
  String get rankFullVibe => 'Full Vibe';

  @override
  String get rankVibeLegends => 'Vibe Legends';

  @override
  String get rankVibeCreators => 'Vibe Creators';

  @override
  String get rankVibeFollowers => 'Vibe Followers';

  @override
  String get rankVibeSeekers => 'Vibe Seekers';

  @override
  String get rankInSearch => 'In the Search';

  @override
  String get photosTitle => 'Photos';

  @override
  String get photosEmpty => 'No photos yet';

  @override
  String get photosEmptyBody => 'Be the first to upload one!';

  @override
  String get photosUpload => 'Upload photo';

  @override
  String get photosPermissionRationale =>
      'To upload event photos, Samay needs access to your photos.';

  @override
  String get photosUploadedSnack => 'Photo uploaded';

  @override
  String get photosUploadWindowClosed => 'The photo upload window has closed';

  @override
  String photosLikesCount(int count) {
    return '$count likes';
  }

  @override
  String get photosLikeTooltip => 'Like';

  @override
  String get photosReportTitle => 'Report photo';

  @override
  String get photosReportBody =>
      'Describe why you want to report this photo. Our moderation team will review it.';

  @override
  String get photosReportHint => 'Reason for the report (optional)';

  @override
  String get photosReportSubmit => 'Submit report';

  @override
  String get photosReportSent => 'Report sent';

  @override
  String get permissionsPhotoRationale =>
      'To pick a cover photo, Samay needs access to your photos.';

  @override
  String get permissionsCameraRationale =>
      'To scan QR codes and take photos, Samay needs access to your camera.';

  @override
  String get permissionsSettingsTitle => 'Permission required';

  @override
  String get permissionsSettingsBody =>
      'This permission was blocked by the system. To use this feature, enable it in your device settings.';

  @override
  String get permissionsOpenSettings => 'Open Settings';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsEmptyBody =>
      'When you get updates, they\'ll show up here.';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get notificationsLoadError => 'Couldn\'t load notifications';

  @override
  String get notificationsTimeNow => 'Now';

  @override
  String notificationsTimeMinutes(int minutes) {
    return '$minutes min ago';
  }

  @override
  String notificationsTimeHours(int hours) {
    return '$hours h ago';
  }

  @override
  String notificationsTimeDays(int days) {
    return '$days d ago';
  }

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatInputHint => 'Write a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatUndecryptable => 'Message can\'t be decrypted';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String get chatLoadError => 'Couldn\'t load messages';

  @override
  String get chatSendError => 'Couldn\'t send the message';

  @override
  String get chatLoadOlder => 'Load older messages';

  @override
  String get eventsTypeLabel => 'Event type';

  @override
  String get eventsTypeCasual => 'Casual';

  @override
  String get eventsTypeCasualDescription =>
      'Movies, dinner, informal — no preshards';

  @override
  String get eventsTypeJuerga => 'Juerga';

  @override
  String get eventsTypeJuergaDescription =>
      'Private venue — invitees will see the address';

  @override
  String get eventsTypeTono => 'Tono';

  @override
  String get eventsTypeTonoDescription => 'Public venue, bar or club';

  @override
  String get eventsNameLabel => 'Event name';

  @override
  String get eventsDescriptionOptional => 'Description (optional)';

  @override
  String get eventsStartsLabel => 'Starts';

  @override
  String get eventsEndsLabel => 'Ends';

  @override
  String get eventsLocationLabel => 'Address / venue';

  @override
  String get eventsVisibilityLabel => 'Visibility';

  @override
  String get eventsVisibilityPublic => 'Public';

  @override
  String get eventsVisibilityGroup => 'Group';

  @override
  String get eventsGroupSelectorLabel => 'Event group';

  @override
  String get eventsGroupSelectorHint => 'Select a group';

  @override
  String get eventsGroupsLoadError => 'Couldn\'t load your groups';

  @override
  String get eventsJoinModeLabel => 'Join mode';

  @override
  String get eventsJoinModeOpen => 'Open';

  @override
  String get eventsJoinModeOpenDescription =>
      'Anyone with the invite link can join';

  @override
  String get eventsJoinModeApproval => 'Approval';

  @override
  String get eventsJoinModeApprovalDescription =>
      'The promotor approves each request';

  @override
  String get eventsJuergaWarningTitle => 'Location warning';

  @override
  String get eventsJuergaWarningBody =>
      'Invitees will see this address. Only invite people you trust.';

  @override
  String get eventsJuergaWarningConfirm => 'Confirm';

  @override
  String get eventsPreshardsLabel => 'Preshards';

  @override
  String get eventsPreshardsPoolLabel => 'Preshards pool';

  @override
  String get eventsPreshardsCapLabel => 'Cap per attendee (optional)';

  @override
  String get eventsRemainderLabel => 'Pool remainder';

  @override
  String get eventsRemainderReturn => 'Return proportionally';

  @override
  String get eventsRemainderRedistribute => 'Redistribute among attendees';

  @override
  String get eventsDynamicQrHint =>
      'With a pool above 0, the dynamic QR is enabled automatically';

  @override
  String get eventsErrorNameRequired => 'Event name is required';

  @override
  String get eventsErrorTimeRange =>
      'The end date must be after the start date';

  @override
  String get eventsErrorCasualPool => 'Casual events cannot have a pool';

  @override
  String get eventsErrorJuergaConfirm =>
      'Confirm the location warning to continue';

  @override
  String get eventsErrorGroup => 'Select a group';

  @override
  String get eventsErrorJoinMode => 'Select a join mode';

  @override
  String get eventDetailTitle => 'Event';

  @override
  String get eventGroupScoped => 'Group event';

  @override
  String get eventViewGroup => 'View group';

  @override
  String get eventNoLocation => 'No location';

  @override
  String eventPoolAmount(int pool) {
    return '$pool preshards';
  }

  @override
  String get eventPoolDistributed => 'Distributed';

  @override
  String get eventPoolNotDistributed => 'Pending distribution';

  @override
  String eventCapPerUser(int cap) {
    return 'Cap per attendee: $cap preshards';
  }

  @override
  String get eventNoPool => 'No preshard pool';

  @override
  String eventRemainderAction(String action) {
    return 'Remainder: $action';
  }

  @override
  String get eventPromotores => 'Promotores';

  @override
  String get eventRolePromotor => 'Promotor';

  @override
  String get eventRoleCoPromotor => 'Co-promotor';

  @override
  String get eventPromotoresError => 'Couldn\'t load promotores';

  @override
  String get eventNoPromotores => 'No promotores';

  @override
  String eventInviteStatus(String status) {
    return 'Your invitation: $status';
  }

  @override
  String get eventInvitePending => 'pending';

  @override
  String get eventInviteAccepted => 'accepted';

  @override
  String get eventInviteDeclined => 'declined';

  @override
  String get eventInviteAttended => 'attended';

  @override
  String get eventEditButton => 'Edit';

  @override
  String get eventCancelButton => 'Cancel event';

  @override
  String get eventCancelDialogTitle => 'Cancel event?';

  @override
  String get eventCancelDialogBody =>
      'The preshards will be returned to the promotores. Invitees will be notified.';

  @override
  String get eventCancelConfirm => 'Yes, cancel';

  @override
  String get eventCancelledSnack => 'Event cancelled';

  @override
  String get eventEditTitle => 'Edit event';

  @override
  String get eventPoolLockedNotice =>
      'The pool, cap and remainder can be edited until the event starts.';

  @override
  String get eventEditUpdatedSnack => 'Event updated';

  @override
  String get eventInvalidPoolAmount => 'Enter a valid pool amount';

  @override
  String get eventStatusDraft => 'Draft';

  @override
  String get eventStatusUpcoming => 'Upcoming';

  @override
  String get eventStatusLive => 'Live';

  @override
  String get eventStatusEnded => 'Ended';

  @override
  String get eventStatusCancelled => 'Cancelled';

  @override
  String get qrAttendanceTitle => 'Attendance QR';

  @override
  String get qrEventLoadError => 'Could not load the event.';

  @override
  String get qrTokenLoadError => 'Could not load the QR code.';

  @override
  String qrActivatesIn(int minutes) {
    return 'The QR code will activate $minutes minutes before the event';
  }

  @override
  String qrActivationCountdown(String time) {
    return 'Activates in $time';
  }

  @override
  String qrNewCodeIn(int seconds) {
    return 'New code in: $seconds';
  }

  @override
  String get qrEventEnded =>
      'The event has ended. The QR code is no longer needed.';

  @override
  String get qrServerPending =>
      'The QR code could not be generated yet. The server is not rotating tokens yet.';

  @override
  String get qrServerPendingBody => 'If the problem persists, press Retry.';

  @override
  String get qrUpdating => 'Updating code…';

  @override
  String get qrAttendeeExpired => 'The QR code expired. Generating a new one…';

  @override
  String get qrAttendeeExpiredBody => 'If the problem persists, press Retry.';

  @override
  String get qrScannerTitle => 'Attendance scanner';

  @override
  String get qrScanPrompt => 'Scan the attendee\'s QR code';

  @override
  String qrScanEventName(String name) {
    return 'Event: $name';
  }

  @override
  String get qrScanEventFallback => 'Event';

  @override
  String get qrTorchOn => 'Turn on flashlight';

  @override
  String get qrTorchOff => 'Turn off flashlight';

  @override
  String get qrScanProcessing => 'Verifying…';

  @override
  String get qrScanConfirmed => 'Attendance confirmed!';

  @override
  String qrScanAttendee(String name) {
    return 'Attendee: $name';
  }

  @override
  String get qrScanReady => 'Done';

  @override
  String get qrScanExpired =>
      'QR code expired. Ask the attendee to refresh their QR.';

  @override
  String get qrScanAlreadyScanned => 'This QR code was already scanned.';

  @override
  String get qrScanNotInvited => 'This user is not invited to this event.';

  @override
  String get qrScanNotInWindow =>
      'The event is not active for attendance confirmation.';

  @override
  String get qrScanNotPromotor =>
      'You don\'t have permission to scan at this event.';

  @override
  String get qrScanInvalidToken => 'Invalid QR code.';

  @override
  String get qrScanNetworkError => 'Connection error. Retrying...';

  @override
  String get qrCameraUnavailable => 'Could not access the camera.';

  @override
  String get qrCameraUnavailableBody =>
      'Close and reopen the scanner, or check camera permissions.';

  @override
  String get qrCameraDenied => 'Camera access is needed to scan.';

  @override
  String get qrCameraSettingsTitle => 'Camera access';

  @override
  String get qrCameraSettingsBody =>
      'Samay needs camera access to scan attendance QR codes.';

  @override
  String get qrCameraSettingsAction => 'Open settings';

  @override
  String get partyFinderTitle => 'Party Finder';

  @override
  String get partyFinderOptInLabel => 'Appear in Party Finder';

  @override
  String get partyFinderOptInOff => 'Discovery is off';

  @override
  String get partyFinderOptInOffBody =>
      'Turn on the switch to appear in other people\'s matches. Nobody can see you while it\'s off.';

  @override
  String get partyFinderEmpty => 'No matches yet';

  @override
  String get partyFinderEmptyBody =>
      'Add more interests to your profile to find like-minded people.';

  @override
  String get partyFinderError => 'Couldn\'t load the Party Finder';

  @override
  String partyFinderSharedInterests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shared interests',
      one: '1 shared interest',
    );
    return '$_temp0';
  }

  @override
  String get cosmeticsShopTitle => 'Cosmetics shop';

  @override
  String get cosmeticsTabFrames => 'Frames';

  @override
  String get cosmeticsTabBackgrounds => 'Backgrounds';

  @override
  String get cosmeticsTabBadges => 'Badges';

  @override
  String get cosmeticsTierVip => 'VIP';

  @override
  String get cosmeticsTierPro => 'PRO';

  @override
  String get cosmeticsTierFree => 'Free';

  @override
  String get cosmeticsPurchaseTitle => 'Confirm purchase';

  @override
  String cosmeticsPurchaseConfirm(String name, int cost) {
    return 'Buy $name for $cost shards?';
  }

  @override
  String get cosmeticsBuy => 'Buy';

  @override
  String cosmeticsBuyWithCost(int cost) {
    return 'Buy — $cost';
  }

  @override
  String get cosmeticsPurchaseSuccess => 'Cosmetic acquired!';

  @override
  String get cosmeticsTierRequired => 'Requires a higher subscription tier.';

  @override
  String get cosmeticsOwned => 'Owned';

  @override
  String get cosmeticsEquipped => 'Equipped';

  @override
  String get cosmeticsEquip => 'Equip';

  @override
  String cosmeticsRequiresTier(String tier) {
    return 'Requires $tier';
  }

  @override
  String get cosmeticsEmptyCatalog => 'No cosmetics available yet';

  @override
  String get comingSoonCosmeticsTitle => 'Cosmetics';

  @override
  String get comingSoonCosmeticsBody =>
      'Your cosmetics collection will appear here.';

  @override
  String get minigamesTitle => 'Games';

  @override
  String get minigamesPickGame => 'Pick a game';

  @override
  String get minigamesGamePokeChain => 'Poke Chain';

  @override
  String get minigamesGamePokeChainTagline =>
      'Pass the poke before the timer runs out';

  @override
  String get minigamesGameQuestions => 'Questions';

  @override
  String get minigamesGameQuestionsTagline => 'Answer from the hot seat';

  @override
  String get minigamesGameTruthDare => 'Truth or Dare';

  @override
  String get minigamesGameTruthDareTagline => 'Take turns, no escaping';

  @override
  String get minigamesGameDrunkBottle => 'Drunk Bottle';

  @override
  String get minigamesGameDrunkBottleTagline =>
      'Spin the bottle and see who it points to';

  @override
  String get minigamesGameChallenge => 'Challenges';

  @override
  String get minigamesGameChallengeTagline =>
      'Complete the challenge before the deadline';

  @override
  String get minigamesWagerLabel => 'Wager (shards)';

  @override
  String get minigamesWagerHint => '0 = no wager';

  @override
  String get minigamesCreate => 'Create game';

  @override
  String get minigamesCreated => 'Game created';

  @override
  String get minigamesErrorInsufficientShards =>
      'You don\'t have enough shards for this wager.';

  @override
  String get minigamesErrorNotMember => 'You\'re not a member of this group.';

  @override
  String get minigamesErrorInvalidGameType => 'The game could not be created.';

  @override
  String get minigamesErrorCreate => 'The game could not be created.';

  @override
  String get minigamesErrorLoad => 'Couldn\'t load the games';

  @override
  String get minigamesEmpty => 'No games in this group yet';

  @override
  String get minigamesEmptyBody =>
      'Create the first game with one of the games above.';

  @override
  String get minigamesStatusActive => 'Active';

  @override
  String get minigamesStatusFinished => 'Finished';

  @override
  String minigamesParticipants(int count) {
    return 'Participants: $count';
  }

  @override
  String minigamesWagerPerPerson(int amount) {
    return 'Wager: $amount shards';
  }

  @override
  String get minigamesDetailComingSoon =>
      'The game will be playable here soon.';

  @override
  String get comingSoonMinigamesTitle => 'Games';

  @override
  String get comingSoonMinigamesBody =>
      'Group mini-games will be available soon.';

  @override
  String get shardsLedgerTitle => 'Shards ledger';

  @override
  String get shardsLedgerTabShards => 'Shards';

  @override
  String get shardsLedgerTabPreshards => 'Preshards';

  @override
  String get shardsLedgerNet => 'Net';

  @override
  String get shardsLedgerEmpty => 'No activity yet';

  @override
  String get shardsLedgerEmptyBody =>
      'When you earn or spend shards, they\'ll show up here.';

  @override
  String get shardsLedgerLoadError => 'Couldn\'t load the ledger';

  @override
  String get shardsLedgerEarned => 'Earned';

  @override
  String get shardsLedgerBought => 'Bought/Bonus';

  @override
  String get shardsLedgerEarnedNote => 'Earned shards never expire.';

  @override
  String get shardsLedgerPreshardsNote =>
      'Preshards can only be used for events.';

  @override
  String shardsLedgerReference(String reference) {
    return 'Ref: $reference';
  }

  @override
  String get shardsReasonEventAttendance => 'Event attendance';

  @override
  String get shardsReasonCosmeticPurchase => 'Cosmetic purchase';

  @override
  String get shardsReasonGroupDonation => 'Group donation';

  @override
  String get shardsReasonMinigameWager => 'Minigame wager';

  @override
  String get shardsReasonMinigameWin => 'Minigame win!';

  @override
  String get shardsReasonMinigameRefund => 'Minigame refund';

  @override
  String get shardsReasonSubscriptionGrant => 'Subscription grant';

  @override
  String get shardsReasonAdminGrant => 'Granted by Samay';

  @override
  String get shardsReasonFeedPost => 'Feed post';

  @override
  String get preshardsReasonPurchased => 'Preshard purchase';

  @override
  String get preshardsReasonSubscriptionGrant => 'Monthly grant';

  @override
  String get preshardsReasonEventPoolSet => 'Assigned to event';

  @override
  String get preshardsReasonEventPoolConsumed => 'Distributed at event';

  @override
  String get preshardsReasonEventPoolReturned => 'Returned from event';

  @override
  String get preshardsReasonAdminGrant => 'Granted by Samay';

  @override
  String get connectivityOfflineBanner =>
      'No connection — data might not be up to date';
}
