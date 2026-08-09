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
      'Password (min. 6 characters, 1 number)';

  @override
  String get authPasswordTooWeak =>
      'The password must be at least 6 characters and contain a number.';

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
  String get feedWelcome => 'Welcome to Samay';

  @override
  String get feedEmpty =>
      'Your feed will appear here.\nSoon you\'ll see nearby events and activity from your groups.';

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
  String get profileVersion => 'Samay v1.0.0';

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
}
