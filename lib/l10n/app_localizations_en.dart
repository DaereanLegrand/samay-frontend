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
  String get welcomeSamay => 'samay';

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
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOrDivider => 'or';

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
  String get authFieldRequired => 'This field is required.';

  @override
  String get authCheckFields => 'Check the highlighted fields.';

  @override
  String get authOtpLengthError => 'Enter the 6-digit code.';

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
  String get resetPasswordTitle => 'Set a new password';

  @override
  String get resetPasswordBody =>
      'Enter and confirm your new password. Use at least 8 characters.';

  @override
  String get resetPasswordNew => 'New password';

  @override
  String get resetPasswordConfirm => 'Confirm password';

  @override
  String get resetPasswordSubmit => 'Save password';

  @override
  String get resetPasswordMismatch => 'The passwords do not match.';

  @override
  String get resetPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get resetPasswordError =>
      'Could not save the password. Try the recovery link again.';

  @override
  String get resetPasswordSuccess => 'Your password has been updated.';

  @override
  String get resetPasswordContinue => 'Continue';

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
  String get feedBrand => 'samay';

  @override
  String get feedFeatured => 'Featured';

  @override
  String get feedFeaturedBadge => 'Featured';

  @override
  String feedRadiusKm(int radius) {
    return '$radius km';
  }

  @override
  String get feedAllCaughtUp => 'You\'re all caught up';

  @override
  String get feedComeBackLater => 'Come back later';

  @override
  String get feedMinigameInvite => 'Invite';

  @override
  String get feedLoadError => 'Couldn\'t load the feed';

  @override
  String get shellFeed => 'Feed';

  @override
  String get shellGroups => 'Groups';

  @override
  String get shellSocial => 'Social';

  @override
  String get shellGames => 'Games';

  @override
  String get shellEvents => 'Events';

  @override
  String get shellNotifications => 'Notis';

  @override
  String get shellProfile => 'Profile';

  @override
  String get friendsTitle => 'friends';

  @override
  String get friendsBlockedTitle => 'blocked';

  @override
  String get friendsNoneBlocked => 'You haven\'t blocked anyone';

  @override
  String get profileBlockedUnblockPrompt => 'User is blocked. Unblock?';

  @override
  String get profileChatUnavailable => 'Could not open the chat.';

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
  String get friendsRequestsTitle => 'requests';

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
  String get friendsSearchUsers => 'search';

  @override
  String get friendsSearchPlaceholder => 'Search by username';

  @override
  String get friendsNoUsersFound => 'No users found';

  @override
  String get friendsStatusAccepted => 'Friends';

  @override
  String get profileMessage => 'Message';

  @override
  String get friendsStatusPending => 'Requested';

  @override
  String get friendsStatusBlocked => 'Blocked';

  @override
  String get friendsAddFriendButton => 'Add';

  @override
  String get friendsMinCharsHint => 'Type at least 5 characters to search';

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
  String get groupsCreateGroup => 'create';

  @override
  String get groupsCreateGroupAction => 'Create group';

  @override
  String get groupsRequests => 'Requests';

  @override
  String get socialTitle => 'social';

  @override
  String get socialTabGroups => 'Groups';

  @override
  String get socialTabFriends => 'Friends';

  @override
  String get socialSearchTooltip => 'Search users';

  @override
  String get socialRankingEntry => 'Ranking';

  @override
  String get socialRankingTitle => 'ranking';

  @override
  String get rankingsUsers => 'Users';

  @override
  String get rankingsGroups => 'Groups';

  @override
  String get socialRankingEmpty => 'No ranking data yet';

  @override
  String get socialCensoredName => 'User';

  @override
  String get socialPublicProfileLabel => 'Public profile';

  @override
  String get socialPublicProfileBody =>
      'Let your name and photo appear in the global user ranking';

  @override
  String get groupsNoneYet => 'You don\'t belong to any group';

  @override
  String get groupsNoneYetSubtitle => 'Create a group or join an existing one';

  @override
  String get groupsLimitReached => 'Limit reached';

  @override
  String get groupsLimitReachedBody =>
      'You\'ve reached the limit of 5 groups as a host. Upgrade your subscription to create more.';

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
  String get groupsDonateTitle => 'donate';

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
  String get groupsTabInfo => 'Info';

  @override
  String get groupsTabChat => 'Chat';

  @override
  String get groupsTabMembers => 'Members';

  @override
  String get groupsTabEvents => 'Events';

  @override
  String get groupsInvitePending => 'Pending invite';

  @override
  String get groupsInvitePendingTitle => 'Group invitation';

  @override
  String get groupsInvitePendingBody =>
      'You have been invited to this group. Accept to join it.';

  @override
  String get groupsFrozenBadge => 'Frozen group';

  @override
  String get groupsLeave => 'Leave group';

  @override
  String get groupsFrozenBanner =>
      'Frozen group — upgrade your subscription or transfer the host role';

  @override
  String groupsShardsCount(int shards) {
    return '$shards group shards';
  }

  @override
  String groupsMemberCount(int members, int limit) {
    return '$members / $limit members';
  }

  @override
  String groupsMembersCountShort(int count) {
    return '$count members';
  }

  @override
  String groupsMyContribution(int shards) {
    return 'My contribution: $shards active shards';
  }

  @override
  String get groupsCreateEvent => 'Create event';

  @override
  String get groupsChatOneToOneTitle => 'Chats are 1:1 for now';

  @override
  String get groupsChatOneToOneBody =>
      'Group chats will be enabled from the messages list.';

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
  String get groupsEventsEmptyTitle => 'No events in this group';

  @override
  String get groupsEventsEmptyBody =>
      'Create the group\'s first event with the Create event button.';

  @override
  String get groupsConfirmLeave => 'Are you sure?';

  @override
  String get groupsAbandon => 'Leave';

  @override
  String get groupsPromoteStaff => 'Make staff';

  @override
  String get groupsRoleHost => 'Host';

  @override
  String get groupsRoleStaff => 'Staff';

  @override
  String get groupsRoleMember => 'Member';

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
  String get groupsMembersTitle => 'members';

  @override
  String get groupsInviteTitle => 'invite';

  @override
  String groupsInviteCount(int count) {
    return 'Invite ($count)';
  }

  @override
  String groupsInvitedCount(int count) {
    return '$count invited';
  }

  @override
  String get groupsSearchUsersHint => 'Search here...';

  @override
  String get groupsMinCharsHint => 'Type at least 2 characters to search';

  @override
  String get groupsNoResults => 'No results';

  @override
  String get groupsNoRankingData => 'No ranking data';

  @override
  String groupsLeaderboardSubtitle(int count, int score) {
    return '$count members · $score shards';
  }

  @override
  String get profileTitle => 'profile';

  @override
  String get profileEditTitle => 'edit';

  @override
  String get profileSettingsTitle => 'settings';

  @override
  String get profileSubscription => 'Subscription';

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profilePrivacy => 'privacy';

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
  String get appThemeTitle => 'App colour';

  @override
  String get appThemeSubtitle => 'Pick the colour of the whole app';

  @override
  String get appThemeClassic => 'Classic';

  @override
  String get appThemeMidnight => 'Midnight';

  @override
  String get appThemeForest => 'Forest';

  @override
  String get appThemeViolet => 'Violet';

  @override
  String get appThemeEmber => 'Ember';

  @override
  String get appThemeTeal => 'Teal';

  @override
  String get appThemeRose => 'Rose';

  @override
  String get appThemeLockedPro => 'Requires Pro';

  @override
  String get appThemeLockedVip => 'Requires VIP';

  @override
  String get appThemeGroupFollowsApp =>
      'Groups with no theme of their own use the app colour.';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionChat => 'Chat';

  @override
  String get settingsSectionGames => 'Games';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsClearLocalData => 'Clear local data';

  @override
  String get settingsClearLocalDataQuestion => 'Clear local data?';

  @override
  String get settingsClearLocalDataBody =>
      'Your session on this device will end and locally stored messages, notifications, photos and preferences will be deleted. Your account is not deleted.';

  @override
  String get settingsClearLocalDataDone => 'Local data cleared';

  @override
  String get pushGenericTitle => 'Samay';

  @override
  String get pushGenericBody => 'New activity in Samay';

  @override
  String get settingsPrivacyPolicyBody =>
      'Your personal data is used only to operate Samay: sign you in, keep your groups and events running, and protect the community. It is never sold or shared with third parties for advertising.';

  @override
  String get settingsServiceTermsBody =>
      'By using Samay you agree to behave respectfully: no harassment, no spam, and no inappropriate content. Misuse may lead to account suspension.';

  @override
  String get notificationSettingsTitle => 'notis';

  @override
  String get notificationSettingsLocalNote =>
      'These preferences are saved on this device.';

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
  String get profileReportTitle => 'Report user';

  @override
  String get profileReportReasonHarassment => 'Harassment or abuse';

  @override
  String get profileReportReasonSpam => 'Spam';

  @override
  String get profileReportReasonInappropriate => 'Inappropriate content';

  @override
  String get profileReportReasonOther => 'Other reason';

  @override
  String get profileReportSent =>
      'Thanks for reporting. We\'ll review it soon.';

  @override
  String get profileUserBlocked => 'User blocked';

  @override
  String get profileBlockError => 'Error blocking';

  @override
  String get profileUserUnblocked => 'User unblocked';

  @override
  String get profileUnblockError => 'Error unblocking';

  @override
  String get profileDeleteTitle => 'delete';

  @override
  String get profileDeleteQuestion => 'Delete account?';

  @override
  String get profileDeleteBody =>
      'This action is immediate and irreversible. Your account, profile, credentials, content, and tokens are deleted. Only pseudonymized shard/attendance records (5 years) and restricted report evidence (2 years; illegal content per law) are kept. There is no recovery window.';

  @override
  String get profileDeleteExplanation =>
      'Deleting your account immediately removes your profile, credentials, content, friendships, memberships, and tokens. Only pseudonymized shard/attendance records (5 years) and restricted report evidence (2 years; illegal content per law) are kept. There is no recovery window.';

  @override
  String get profileDeleteNowLabel => 'Delete my account permanently';

  @override
  String get profileDeleteNowBody =>
      'Your profile, credentials, content, and tokens are deleted. Only pseudonymized shard/attendance records (5 years) and restricted report evidence (2 years; illegal content per law) remain. This cannot be undone.';

  @override
  String get profileDeleteNowQuestion => 'Delete your account permanently?';

  @override
  String get profileExportData => 'Export my data';

  @override
  String get profileExportTitle => 'export';

  @override
  String get profileExportBody =>
      'Save a copy of your profile, friendships, groups, events, shards, received messages (ciphertext), minigame answers, device tokens, and reports.';

  @override
  String get profileExportChatNote =>
      'Chat is end-to-end encrypted: the server can only export ciphertext. E2EE keys and moderation evidence are not exported; the document lists its exclusions and the retention matrix.';

  @override
  String get profileExportCta => 'Generate file';

  @override
  String get profileExportCopy => 'Copy to clipboard';

  @override
  String get profileExportSuccess =>
      'Export saved on this device and copied to the clipboard.';

  @override
  String get profileExportError => 'Export failed. Please try again.';

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
  String get paywallBillingMonthly => 'Monthly';

  @override
  String get paywallBillingAnnual => 'Annual';

  @override
  String paywallAnnualEquivalent(String monthly, String percent) {
    return '$monthly saving $percent%';
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
  String get routerErrorTitle => 'oops';

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
  String get errorsEmailNotConfirmed =>
      'Email not confirmed. Check your inbox.';

  @override
  String get errorsInvalidEmail => 'Invalid email address.';

  @override
  String get errorsSamePassword => 'Choose a different password.';

  @override
  String get errorsOtpDisabled => 'Code sign-in is disabled.';

  @override
  String get errorsUserBanned => 'Your account is suspended.';

  @override
  String get errorsReauthenticationNeeded => 'Sign in again to continue.';

  @override
  String get errorsInvalidCredentials => 'Invalid email or password';

  @override
  String get errorsOtpExpired => 'The code has expired. Request a new one.';

  @override
  String get errorsOtpInvalid =>
      'The code is incorrect or has expired. Request a new one.';

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
  String get notificationsTitle => 'notis';

  @override
  String get notificationSettingsEventReminders => 'Event reminders';

  @override
  String get notificationSettingsFriendRequests => 'Friend requests';

  @override
  String get notificationSettingsChatMessages => 'Chat messages';

  @override
  String get notificationSettingsShardsRank => 'Shards and ranking';

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
  String get chatTitle => 'chat';

  @override
  String get chatInputHint => 'Write a message...';

  @override
  String get chatSend => 'Send';

  @override
  String get chatUndecryptable => 'Message can\'t be decrypted';

  @override
  String get chatDeleteForEveryone => 'Delete for everyone';

  @override
  String get chatDeleteForMe => 'Delete for me';

  @override
  String get chatDeleteTooOld =>
      'You can only delete messages sent less than 5 minutes ago';

  @override
  String get chatDeleteFailed => 'Couldn\'t delete the message';

  @override
  String get chatPeerReinstalled =>
      'The other user reinstalled the app or changed devices';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String get chatLoadError => 'Couldn\'t load messages';

  @override
  String get chatSendError => 'Couldn\'t send the message';

  @override
  String get chatLoadOlder => 'Load older messages';

  @override
  String get chatInboxTitle => 'chats';

  @override
  String get chatInboxEmpty => 'No conversations yet';

  @override
  String get chatInboxEmptyBody =>
      'Tap \"Send message\" on someone\'s profile to start a chat.';

  @override
  String get chatInboxLoadError => 'Couldn\'t load chats';

  @override
  String get chatInboxPreviewOwn => 'You: ';

  @override
  String get commonNow => 'now';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String get chatReadReceipts => 'Read receipts';

  @override
  String get chatReadReceiptsBody =>
      'When off, your messages are never marked as read.';

  @override
  String get chatReadReceiptsSaveError => 'Couldn\'t update read receipts';

  @override
  String get chatSent => 'Sent';

  @override
  String get chatReceived => 'Received';

  @override
  String get chatRead => 'Read';

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
      'The host approves each request';

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
  String get eventDetailTitle => 'event';

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
  String get eventHosts => 'Host & staff';

  @override
  String get eventRoleHost => 'Host';

  @override
  String get eventRoleStaff => 'Staff';

  @override
  String get eventHostsError => 'Couldn\'t load host & staff';

  @override
  String get eventNoHosts => 'No hosts yet';

  @override
  String get eventStaffAddButton => 'Add staff';

  @override
  String get eventStaffPickerTitle => 'pick staff';

  @override
  String eventStaffCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get eventStaffAdded => 'Staff added';

  @override
  String get eventStaffRemoved => 'Staff removed';

  @override
  String get eventStaffRemove => 'Remove staff';

  @override
  String eventStaffRemoveDialogTitle(String username) {
    return 'Remove @$username?';
  }

  @override
  String get eventStaffRemoveDialogBody =>
      'They\'ll no longer be staff and won\'t be able to scan attendance codes.';

  @override
  String get eventStaffRemoveConfirm => 'Remove';

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
  String get eventGuestsTitle => 'Guests';

  @override
  String get eventGuestsEmpty => 'No guests yet';

  @override
  String get eventGuestsLoadError => 'Couldn\'t load guests';

  @override
  String get eventAttendeesTitle => 'Attendees';

  @override
  String get eventAttendeesEmpty => 'No confirmed attendees yet';

  @override
  String get eventAttendeesLoadError => 'Couldn\'t load attendees';

  @override
  String get eventInviteGuestsButton => 'Invite people';

  @override
  String get eventsInviteTitle => 'invite';

  @override
  String eventsInviteCount(int count) {
    return 'Invite ($count)';
  }

  @override
  String get eventsInviteSent => 'Invitation sent';

  @override
  String get eventsInviteSentTag => 'invited';

  @override
  String get eventInvitePendingBody =>
      'You\'ve been invited to this event. Confirm you\'ll attend.';

  @override
  String get eventInviteAccept => 'Accept';

  @override
  String get eventInviteDecline => 'Decline';

  @override
  String get eventInviteAcceptedSnack => 'Attendance confirmed';

  @override
  String get eventInviteDeclinedSnack => 'Invitation declined';

  @override
  String get eventEditButton => 'Edit';

  @override
  String get eventCancelButton => 'Cancel event';

  @override
  String get eventCancelDialogTitle => 'Cancel event?';

  @override
  String get eventCancelDialogBody =>
      'The preshards will be returned to the hosts. Invitees will be notified.';

  @override
  String get eventCancelConfirm => 'Yes, cancel';

  @override
  String get eventCancelledSnack => 'Event cancelled';

  @override
  String get eventEditTitle => 'edit';

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
  String get qrAttendanceTitle => 'QR';

  @override
  String get qrEventLoadError => 'Could not load the event.';

  @override
  String qrActivationCountdown(String time) {
    return 'Activates in $time';
  }

  @override
  String get qrScannerTitle => 'Scanner';

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
  String get qrScanAlreadyScanned => 'This QR code was already scanned.';

  @override
  String get qrScanNotInvited => 'This user is not invited to this event.';

  @override
  String get qrScanNotInWindow =>
      'The event is not active for attendance confirmation.';

  @override
  String get qrScanNotHost =>
      'You don\'t have permission to scan at this event.';

  @override
  String get qrScanInvalidCode => 'Invalid QR code.';

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
  String get codeNotReadyYet => 'Your attendance code isn\'t ready yet.';

  @override
  String get codeLoadError => 'Could not load your attendance code.';

  @override
  String get codeEventEnded =>
      'The event has ended. No attendance code is needed.';

  @override
  String get codeNotInvited => 'You don\'t have a code for this event.';

  @override
  String get codeServerPending => 'The server has not issued your code yet.';

  @override
  String get codeServerPendingBody => 'If the problem persists, press Retry.';

  @override
  String get codeAssistedDone => 'DONE';

  @override
  String get cosmeticsShopTitle => 'cosmetics';

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
  String get minigamesTitle => 'games';

  @override
  String get minigamesTagline => 'Do you dare';

  @override
  String get minigamesChooseGroup => 'Choose a group';

  @override
  String get minigamesChooseGroupEllipsis => '…';

  @override
  String get minigamesNoGroups => 'No groups yet';

  @override
  String get minigamesNoGroupsBody =>
      'Join or create a group to play games with your friends.';

  @override
  String get minigamesPickGame => 'Pick a game';

  @override
  String get minigamesGameTruthDare => 'Truth or Dare';

  @override
  String get minigamesGameTruthDareTagline => 'Do you dare...?';

  @override
  String get minigamesGameTruthDareExplanation =>
      'Each player picks Truth or Dare and the group decides if you delivered. No escaping.';

  @override
  String get minigamesGameDrunkBottle => 'Drunk Bottle';

  @override
  String get minigamesGameDrunkBottleTagline =>
      'Spin the bottle and see who it points to';

  @override
  String get minigamesGameDrunkBottleExplanation =>
      'Spin the bottle: whoever it points to has to take it on. Perfect for hangouts with friends.';

  @override
  String get minigamesBottleSpin => 'Spin';

  @override
  String get minigamesBottleStop => 'Stop';

  @override
  String get minigamesGameCharades => 'Charades';

  @override
  String get minigamesGameCharadesTagline =>
      'Phone on your forehead and let them guess';

  @override
  String get minigamesGameCharadesExplanation =>
      'Hold the phone on your forehead without looking at the screen. The group acts out the word that appears and you guess it. Every correct answer scores a point and, when time runs out, it is the next player\'s turn.';

  @override
  String get charadesRulesTitle => 'How to play';

  @override
  String get charadesRule1 =>
      'Put the phone on your forehead with the screen facing the group. Do not look.';

  @override
  String get charadesRule2 =>
      'The group acts out the word without saying or spelling it.';

  @override
  String get charadesRule3 =>
      'If you guess it, tap Got it. If it gets hard, tap Pass.';

  @override
  String get charadesRule4 =>
      'When time runs out, your hits are counted and the turn passes.';

  @override
  String get charadesPickCategory => 'Pick a category';

  @override
  String get charadesDuration => 'Duration';

  @override
  String charadesSeconds(int count) {
    return '$count s';
  }

  @override
  String get charadesStartTurn => 'Start my turn';

  @override
  String get charadesHit => 'Got it';

  @override
  String get charadesPass => 'Pass';

  @override
  String get charadesFinish => 'End turn';

  @override
  String charadesPlayingBy(String name) {
    return '$name is playing';
  }

  @override
  String get charadesActNow => 'Act out the word!';

  @override
  String get charadesTimeUp => 'Time\'s up!';

  @override
  String charadesTurnScore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hits',
      one: '1 hit',
      zero: 'No hits',
    );
    return '$_temp0';
  }

  @override
  String get charadesScoreboard => 'Scoreboard';

  @override
  String get charadesNextPlayer => 'Next player';

  @override
  String get charadesWaitingTurn => 'No one is playing yet';

  @override
  String get charadesCategoryAll => 'All';

  @override
  String get charadesCategoryPeliculas => 'Movies';

  @override
  String get charadesCategoryAnimales => 'Animals';

  @override
  String get charadesCategoryAcciones => 'Actions';

  @override
  String get charadesCategoryObjetos => 'Objects';

  @override
  String get charadesCategoryFamosos => 'Celebrities';

  @override
  String get charadesCategoryFiesta => 'Party';

  @override
  String get minigamesPublishTitle => 'Open game';

  @override
  String get minigamesPublishSubtitle =>
      'Anyone in the app can see it and join without an invite';

  @override
  String get minigamesErrorInvalidCode =>
      'That code is not valid or has expired.';

  @override
  String get minigamesJoinCodeTitle => 'Join with a code';

  @override
  String get minigamesJoinCodeHint =>
      'Ask the host for the 6-character code of a direct partida.';

  @override
  String get minigamesJoinCodeButton => 'Join with code';

  @override
  String get minigamesJoinCodePlaceholder => 'ABC234';

  @override
  String get minigamesJoinCodeShareTitle => 'Partida code';

  @override
  String minigamesJoinCodeShareBody(String code) {
    return 'Share this code: $code';
  }

  @override
  String get minigamesJoinCodeShareHint =>
      'Generate a code and share it. Only a hash is stored; it is shown once.';

  @override
  String get minigamesJoinCodeCopy => 'Copy';

  @override
  String get minigamesJoinCodeDone => 'Done';

  @override
  String get minigamesJoinCodeGenerate => 'Generate code';

  @override
  String get minigamesJoinCodeRevoke => 'Revoke';

  @override
  String get minigamesJoinCodeRevoked => 'The join code was revoked.';

  @override
  String get minigamesPublicLobbyTitle => 'Open games';

  @override
  String get minigamesPublicJoin => 'Join';

  @override
  String get minigamesPublicJoined => 'You joined the game';

  @override
  String get minigamesPublicAlreadyIn => 'You are already in';

  @override
  String get minigamesPublicEmpty =>
      'No one has posted a game yet. Create one and open it so others can join.';

  @override
  String minigamesPublicHostedBy(String name) {
    return 'by $name';
  }

  @override
  String minigamesPublicPlayers(int count, int limit) {
    return '$count/$limit players';
  }

  @override
  String get minigamesPublicFull => 'Full';

  @override
  String get minigamesBottleSpinning => 'Spinning…';

  @override
  String get minigamesBottleTapToSpin => 'Tap Spin and let the bottle decide';

  @override
  String minigamesBottleLandedOn(String name) {
    return '$name got it';
  }

  @override
  String get minigamesBottleYourTurn => 'It\'s on you!';

  @override
  String get minigamesBottleDareTitle => 'Your dare';

  @override
  String minigamesBottleSpunBy(String name) {
    return '$name spun';
  }

  @override
  String get minigamesBottleCategorySuave => 'mild';

  @override
  String get minigamesBottleCategoryMedio => 'medium';

  @override
  String get minigamesBottleCategoryPicante => 'spicy';

  @override
  String get minigamesBottleCategoryCastigo => 'punishment';

  @override
  String minigamesBottleMinPlayers(int min, int count) {
    return 'Bottle needs at least $min players (you have $count)';
  }

  @override
  String get minigamesGameTwoLiesOneTruth => '2 Lies, 1 Truth';

  @override
  String get minigamesGameTwoLiesOneTruthTagline =>
      'Guess which one is the real truth';

  @override
  String get minigamesGameTwoLiesOneTruthExplanation =>
      'The subject writes 3 statements about themselves: 2 lies and 1 truth. The others must guess which one is real.';

  @override
  String get minigamesAudienceFriends => 'Meant for playing with friends';

  @override
  String get minigamesAudienceSolo => 'Meant for playing alone';

  @override
  String get minigamesAudienceBoth => 'With friends or solo';

  @override
  String get minigamesNewPartida => 'New game';

  @override
  String get minigamesScopeLabel => 'Partida';

  @override
  String get minigamesPartidaNameLabel => 'Name (optional)';

  @override
  String minigamesPartidaNameHint(String autoName) {
    return '$autoName';
  }

  @override
  String minigamesAutoName(int index) {
    return 'game-$index';
  }

  @override
  String get minigamesOngoingTitle => 'Ongoing games';

  @override
  String minigamesDetailEmpty(String game) {
    return 'No $game games yet';
  }

  @override
  String get minigamesDetailEmptyBody =>
      'Tap \"New game\" to start the first one.';

  @override
  String get minigamesWagerDefaultHint => 'Default: 10';

  @override
  String get minigamesRoundsLabel => 'Rounds';

  @override
  String get minigamesRoundsHint => 'Default: 5';

  @override
  String get minigamesWagerLabel => 'Entry';

  @override
  String get minigamesWagerHint => '0 = no wager';

  @override
  String get minigamesWagerBalanceCaption => 'Available';

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
  String get minigamesErrorInviteeNotAllowed =>
      'Some players couldn\'t be invited.';

  @override
  String get minigamesErrorInviteeFriendsOnly =>
      'One or more players only accept invites from friends.';

  @override
  String get minigamesErrorTooManyInvitees =>
      'You can invite up to 20 players.';

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
  String get minigamesViewLeaderboard => 'View leaderboard';

  @override
  String get minigamesPoolBreakdownTitle => 'Prizes';

  @override
  String minigamesPoolRank(int rank) {
    return '#$rank';
  }

  @override
  String get minigamesPoolNoPrize => 'No prize';

  @override
  String get minigamesDetailComingSoon =>
      'The game will be playable here soon.';

  @override
  String get minigamesPlayTitle => 'Truth or Dare';

  @override
  String get minigamesBarWaiting => 'waiting…';

  @override
  String get minigamesBarError => 'error';

  @override
  String get minigamesBarLeaderboard => 'leaderboard';

  @override
  String get minigamesBarResponding => 'answering';

  @override
  String get minigamesTurnBarPrefix => '';

  @override
  String get minigamesTurnBarSuffix => '\'s turn';

  @override
  String get minigamesResponseBarPrefix => '';

  @override
  String get minigamesResponseBarSuffix => '\'s response';

  @override
  String get minigamesChoosePromptGeneric => 'Your turn! Pick Truth or Dare';

  @override
  String minigamesChoosePromptFor(String name) {
    return 'Up to $name: pick Truth or Dare';
  }

  @override
  String get minigamesTruth => 'Truth';

  @override
  String get minigamesDare => 'Dare';

  @override
  String minigamesPromptHeader(String name) {
    return 'Your turn, $name!';
  }

  @override
  String get minigamesPromptGeneric => 'Your turn!';

  @override
  String get minigamesPromptDone => 'Done';

  @override
  String get minigamesPromptLoadError => 'ERROR LOADING PROMPT';

  @override
  String get minigamesPromptSkip => 'Skip';

  @override
  String get minigamesTurnGeneric => 'A player\'s turn';

  @override
  String get minigamesYourTurn => 'your turn…';

  @override
  String get minigamesAnonAliasPrefix => 'anonymous';

  @override
  String get minigamesAnswerTitle => 'Your answer';

  @override
  String get minigamesAnswerPlaceholder => 'Type your answer…';

  @override
  String get minigamesAnswerImageLabel => 'Add image';

  @override
  String get minigamesAnswerRemoveImage => 'Remove image';

  @override
  String get minigamesAnswerSubmit => 'Answer';

  @override
  String get minigamesAnswerRevealed => 'Answered';

  @override
  String get minigamesAnswerWaiting => 'Waiting for the answer…';

  @override
  String minigamesAnswerWaitingReactions(int reacted, int required) {
    return 'waiting for $reacted/$required reactions…';
  }

  @override
  String get minigamesKeyRequesting =>
      'Waiting for another participant to connect to decrypt…';

  @override
  String get minigamesKeyMissing => 'No one connected to resend the key.';

  @override
  String get minigamesPasar => 'Skip';

  @override
  String get minigamesPasarSkipped => 'skipped';

  @override
  String get minigamesModeLabel => 'Game mode';

  @override
  String get minigamesModeByTurns => 'By turns';

  @override
  String get minigamesModeAsync => 'Async';

  @override
  String get minigamesAsyncRoundsLabel => 'Rounds per player';

  @override
  String get minigamesAsyncEndsLabel => 'Game time (days)';

  @override
  String get minigamesAnonymousLabel => 'Anonymous game';

  @override
  String get minigamesAliasLabel => 'Temp nickname';

  @override
  String get minigamesAliasUpdate => 'Update name';

  @override
  String get minigamesAliasUpdated => 'Name updated';

  @override
  String minigamesAsyncProgress(int done, int target) {
    return 'Your rounds: $done/$target';
  }

  @override
  String get minigamesAsyncAvailable => 'Rounds to react';

  @override
  String minigamesAsyncTimerEnds(String date) {
    return 'The game ends on $date';
  }

  @override
  String get minigamesAnswerPasarLine =>
      'you can skip if you\'d rather not answer';

  @override
  String minigamesTurnFor(String name) {
    return '$name\'s turn';
  }

  @override
  String minigamesNextTurn(String name) {
    return 'Next: $name';
  }

  @override
  String get minigamesWaitingChoiceGeneric => 'Waiting for the current player…';

  @override
  String get minigamesCountdownStarting => 'The match starts in…';

  @override
  String get minigamesCountdownWaitingHost => 'Waiting for the host…';

  @override
  String get minigamesCountdownHostError =>
      'The host didn\'t confirm the match. Please try again.';

  @override
  String get minigamesCountdownCancel => 'Cancel';

  @override
  String get minigamesComplete => 'End game';

  @override
  String get minigamesCompleteConfirm =>
      'Are you sure? Wagers will be redistributed.';

  @override
  String get minigamesCompleteConfirmTitle => 'End the match?';

  @override
  String get minigamesFinished => 'Game over!';

  @override
  String minigamesRoundCounter(int current, int total) {
    return 'Round $current / $total';
  }

  @override
  String get minigamesAnonymousPlayer => 'Player';

  @override
  String minigamesPrizeAmount(int amount) {
    return '$amount shards';
  }

  @override
  String minigamesPointsAmount(int count) {
    return '$count points';
  }

  @override
  String get minigamesAnswersLoadError =>
      'Oops, we couldn\'t load the match answers. Try again later.';

  @override
  String get minigamesNoAnswers => 'No answers recorded';

  @override
  String get minigamesLeaderboardSwipeHint => 'Swipe to see more ranks';

  @override
  String get minigamesErrorLoadGame => 'Could not load the game';

  @override
  String get shardsLedgerTitle => 'shards';

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
  String get eventsTabTitle => 'events';

  @override
  String get eventsCreateCta => 'Create event';

  @override
  String get eventsCreateCtaBody =>
      'Create your event and invite people — your plan caps attendance.';

  @override
  String get eventsCapacityTitle => 'How many people can attend?';

  @override
  String get eventsCapacityHint => 'Total people, including you.';

  @override
  String get eventsCapacityContact => 'Want more? Contact us';

  @override
  String get eventsContactSoon => 'Coming soon — we will be in touch.';

  @override
  String get eventsEmpty => 'No events yet';

  @override
  String get eventsEmptyBody =>
      'Invitations and events you create will show up here.';

  @override
  String get searchTooShort => 'Type at least 2 characters to search';

  @override
  String get eventsSearchHint => 'Search events';

  @override
  String get eventsSearchTooltip => 'Search events';

  @override
  String get eventsFilterTooltip => 'Filter by distance';

  @override
  String get eventsUseMyLocation => 'Use my location';

  @override
  String get eventsPickLocation => 'Pick location';

  @override
  String eventsDistanceKm(String km) {
    return '$km km';
  }

  @override
  String eventsFriendsGoing(int count) {
    return '$count friends going';
  }

  @override
  String get eventsLocationSectionTitle => 'Location';

  @override
  String get eventsLocationOptionalHint =>
      'Optional — drag the map to set the exact spot.';

  @override
  String get locationPickerTitle => 'Pick a location';

  @override
  String get locationPickerLinkTab => 'Link';

  @override
  String get locationPickerCoordsTab => 'Coords';

  @override
  String get locationPickerMapTab => 'Map';

  @override
  String get locationPickerLinkHint => 'Paste a Google Maps link or lat,lng';

  @override
  String get locationPickerCoordsHint => 'e.g. -16.3988, -71.5369';

  @override
  String get locationPickerResolve => 'Resolve';

  @override
  String get locationPickerUse => 'Use';

  @override
  String get locationPickerUseThisLocation => 'Use this location';

  @override
  String locationPickerCoordinates(String value) {
    return 'Coordinates: $value';
  }

  @override
  String get locationPickerDenied => 'Location permission denied';

  @override
  String get locationPickerUnavailable => 'Location unavailable';

  @override
  String get locationPickerResolveFailed => 'Could not resolve that location';

  @override
  String get locationPickerPastePrompt => 'Paste a link or coordinates first';

  @override
  String get featureUnavailableTitle => 'Unavailable';

  @override
  String get featureUnavailableBody => 'This feature is not available yet.';

  @override
  String get collageTitle => 'collage';

  @override
  String get collageEmpty => 'No photos for the collage yet';

  @override
  String get collageEmptyBody =>
      'The collage builds itself from the event\'s photos.';

  @override
  String collagePhotoCount(int count) {
    return '$count photos';
  }

  @override
  String get connectivityOfflineBanner =>
      'No connection — data might not be up to date';

  @override
  String get crashRecoveryBannerTitle =>
      'The app recovered from an unexpected shutdown';

  @override
  String get chatMessageInfo => 'Message info';

  @override
  String get chatMessageInfoSent => 'Sent';

  @override
  String chatMessageInfoReadBy(int count, int total) {
    return 'Read by $count of $total';
  }

  @override
  String get chatMessageInfoReadAt => 'Read';

  @override
  String get chatMessageInfoNotRead => 'Not read';

  @override
  String get minigamesInviteTitle => 'invite';

  @override
  String minigamesInviteCount(int count) {
    return 'Invite ($count)';
  }

  @override
  String get minigamesDetailTitle => 'game';

  @override
  String get minigamesParticipantsTitle => 'Players';

  @override
  String get minigamesReady => 'Ready';

  @override
  String get minigamesNotReady => 'Not ready';

  @override
  String get minigamesReadyQuestion => 'Ready?';

  @override
  String get minigamesCreator => 'Host';

  @override
  String get minigamesStart => 'Start';

  @override
  String get minigamesRejoin => 'Back to the match';

  @override
  String get minigamesRemovePlayer => 'Remove player';

  @override
  String minigamesRemovePlayerConfirm(String name) {
    return 'Remove $name from this partida?';
  }

  @override
  String get minigamesRemovePlayerConfirmBody =>
      'Their wager will be refunded and they will be removed from the game.';

  @override
  String get minigamesStartOnlyCreator => 'Only the host can start the game.';

  @override
  String minigamesWaitingReady(String names) {
    return 'Waiting for $names to tap Ready';
  }

  @override
  String minigamesWaitingReadyOne(String name) {
    return 'Waiting for $name to tap Ready';
  }

  @override
  String get minigamesRulesTitle => 'How to play';

  @override
  String get minigamesRulesAction => 'How to play';

  @override
  String get truthDareRule1 =>
      'Each round belongs to one player: they pick Truth or Dare.';

  @override
  String get truthDareRule2 => 'The app draws a random question or dare.';

  @override
  String get truthDareRule3 =>
      'Answer it or do it, then send your reply to the table.';

  @override
  String get truthDareRule4 => 'The others react and the turn moves on.';

  @override
  String get bottleRule1 => 'The table is split into slices — one per player.';

  @override
  String get bottleRule2 => 'Tap Spin, then tap Stop whenever you like.';

  @override
  String get bottleRule3 =>
      'The bottle slows to a halt: the slice it points at is the pick.';

  @override
  String get bottleRule4 =>
      'That player does the dare that appears, then you spin again.';

  @override
  String get twoLiesRule1 =>
      'Each round belongs to one player: they write 3 statements about themselves.';

  @override
  String get twoLiesRule2 =>
      'Two are lies and one is true. Nobody else sees them while they type.';

  @override
  String get twoLiesRule3 =>
      'Everyone else votes for the one they think is true.';

  @override
  String get twoLiesRule4 =>
      'The answer is revealed, points are shared out and the turn moves on.';

  @override
  String get minigamesWaitingForPlayers => 'Waiting for players...';

  @override
  String get minigamesScopeDirect => 'Direct';

  @override
  String get minigamesScopeGroup => 'Group';

  @override
  String get minigamesPlayDirect => 'Play directly';

  @override
  String get minigamesChangeGroup => 'Change group';

  @override
  String get minigamesDirectEmpty => 'No direct games yet';

  @override
  String get minigamesDirectEmptyBody =>
      'Create a game to play right now with a friend — no group needed.';

  @override
  String get minigamesErrorPlayerLimitReached =>
      'This game has reached its player limit.';

  @override
  String get minigamesErrorInvalidRounds => 'The round count is not valid.';

  @override
  String get minigamesErrorInvalidPrizePositions =>
      'The prize-position count is not valid.';

  @override
  String get minigamesErrorInvalidPlayMode => 'The game mode is not valid.';

  @override
  String get minigamesErrorInvalidAsyncRounds =>
      'The rounds-per-player value is not valid.';

  @override
  String get minigamesErrorInvalidAsyncEndsAt =>
      'The async game end time is not valid.';

  @override
  String get minigamesErrorNotAllowed => 'You can\'t join this game.';

  @override
  String get minigamesInvitePendingBody => 'You\'ve been invited to this game.';

  @override
  String minigamesInviteFromDirect(String name) {
    return 'Invited by $name';
  }

  @override
  String minigamesInviteFromGroup(String name) {
    return 'Group $name';
  }

  @override
  String minigamesGroupMessage(String game) {
    return 'New $game match';
  }

  @override
  String get minigamesJoin => 'JOIN';

  @override
  String get minigamesView => 'View';

  @override
  String get minigamesInvitedBy => 'Invited by';

  @override
  String get minigamesInviteAccept => 'Accept';

  @override
  String get minigamesInviteDecline => 'Decline';

  @override
  String get minigamesInviteAccepted => 'You joined the game';

  @override
  String get minigamesInviteDeclined => 'Invite declined';

  @override
  String get minigamesInviteSent => 'Invite sent';

  @override
  String get minigamesInviteSentTag => 'sent';

  @override
  String get minigamesInviteClosed =>
      'This game has already finished. The invite can no longer be accepted.';

  @override
  String get minigamesKickedTitle => 'Oops!';

  @override
  String get minigamesInviteFriendsOnly => 'Only friends can invite me';

  @override
  String get minigamesInviteFriendsOnlyBody =>
      'When on, only your friends can invite you to a minigame.';

  @override
  String get minigamesInviteFriendsOnlySaveError =>
      'Couldn\'t save the preference.';

  @override
  String get minigamesGoToGame => 'Go to game';

  @override
  String minigamesTwoLiesStatementNumber(int number) {
    return 'Statement $number';
  }

  @override
  String get minigamesTwoLiesMarkTruthPrompt => 'Mark which one is the truth';

  @override
  String get minigamesTwoLiesGuessPrompt =>
      'Which of these 3 statements is THE TRUTH?';

  @override
  String get minigamesTwoLiesHoldHint => 'Hold a card to mark your truth';

  @override
  String get minigamesTwoLiesVoteConfirm => 'Vote for this option';

  @override
  String get minigamesTwoLiesVoteConfirmed => 'Your vote is recorded';

  @override
  String get minigamesTwoLiesTruthBadge => 'THE TRUTH';

  @override
  String get minigamesTwoLiesLieBadge => 'LIE';

  @override
  String minigamesTwoLiesWaitingSubject(String name) {
    return '$name is writing their 3 statements...';
  }

  @override
  String minigamesTwoLiesWaitingVotes(int voted, int total) {
    return 'Waiting for everyone to vote... ($voted/$total)';
  }

  @override
  String get minigamesTwoLiesFillAllError =>
      'You must complete all 3 statements';

  @override
  String get codeAlreadyAttendedReturn => 'Go back';

  @override
  String get minigamesLeaderboardTitle => 'leaderboard';

  @override
  String get chatReportMessage => 'Report message';

  @override
  String get chatBlockUser => 'Block user';

  @override
  String get legalOpenOnline => 'View online';

  @override
  String get authDobRequired => 'Date of birth is required.';

  @override
  String get authDobInvalid => 'Date of birth is not valid.';

  @override
  String get profileExportSaved => 'Copy saved in the app storage:';

  @override
  String get notificationCategoryMinigames => 'Minigames';

  @override
  String get notificationCategoryMarketing => 'Promotions';

  @override
  String get notificationCategorySecurity => 'Security';

  @override
  String get notificationCategoryModeration => 'Moderation';

  @override
  String get notificationCategoryLegal => 'Legal';

  @override
  String get notificationCategoryAlwaysOnTitle => 'Always delivered';

  @override
  String get notificationCategoryAlwaysOn => 'Always on';

  @override
  String get notificationSettingsServerNote =>
      'These preferences are saved to your account.';

  @override
  String get notificationSettingsSaveError => 'Could not save the preference.';

  @override
  String get profileMutedUsers => 'Muted users';

  @override
  String get friendsNoneMuted => 'No muted users';

  @override
  String get friendsUnmute => 'Unmute';

  @override
  String get profileMute => 'Mute';

  @override
  String get profileUnmute => 'Unmute';

  @override
  String get profileUserMuted => 'User muted';

  @override
  String get profileMuteError => 'Error muting the user';

  @override
  String get reportTitle => 'Report content';

  @override
  String get reportSent => 'Thanks for reporting. We will review it.';

  @override
  String get reportCategoryHarassment => 'Harassment or abuse';

  @override
  String get reportCategoryHate => 'Hate speech';

  @override
  String get reportCategorySpam => 'Spam';

  @override
  String get reportCategoryImpersonation => 'Impersonation';

  @override
  String get reportCategoryNcii => 'Non-consensual intimate images';

  @override
  String get reportCategoryThreat => 'Credible threat';

  @override
  String get reportCategoryCsam => 'Illegal content';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get reportAvatar => 'Report avatar';

  @override
  String get reportGroupCover => 'Report group cover';

  @override
  String get reportEventDescription => 'Report event description';

  @override
  String get reportMinigameAnswer => 'Report answer';

  @override
  String get appealsTitle => 'Appeals';

  @override
  String get appealsEmpty => 'You have no appeals';

  @override
  String get appealsSubmit => 'Submit appeal';

  @override
  String get appealsMessageHint =>
      'Explain why this decision should be reviewed (minimum 10 characters).';

  @override
  String get appealsSubmitted => 'Appeal submitted. We will review it.';

  @override
  String get appealStatusOpen => 'Open';

  @override
  String get appealStatusReviewing => 'Under review';

  @override
  String get appealStatusUpheld => 'Upheld';

  @override
  String get appealStatusOverturned => 'Overturned';

  @override
  String get appealStatusClosed => 'Closed';

  @override
  String get reportOutcomesTitle => 'Your reports';

  @override
  String get reportOutcomeEmpty => 'No report outcomes yet';

  @override
  String get bannedAppealCta => 'Appeal this decision';

  @override
  String get bannedAppealTitle => 'Submit a ban appeal';

  @override
  String get bannedAppealSubmitted => 'Ban appeal submitted.';

  @override
  String get eventsVenueLabel => 'Exact venue';

  @override
  String get eventsCityLabel => 'City';

  @override
  String get eventsShareLink => 'Share link';

  @override
  String get eventsShareLinkRotate => 'Rotate link';

  @override
  String get eventsShareLinkRevoke => 'Revoke link';

  @override
  String get eventsShareLinkCopied => 'Link copied';

  @override
  String eventsShareLinkCopiedBody(String url) {
    return 'Share this link: $url';
  }

  @override
  String get eventsShareLinkRevoked => 'Link revoked';

  @override
  String get linkConsentTitle => 'Invitation';

  @override
  String get linkJoinEvent => 'Join event';

  @override
  String get linkRequestJoin => 'Request to join';

  @override
  String get linkJoinGroup => 'Join group';

  @override
  String get linkAddFriend => 'Send request';

  @override
  String get linkRequestSent => 'Request sent';

  @override
  String get linkEventJoined => 'You joined the event';

  @override
  String get linkInvalid => 'Invalid or expired link';

  @override
  String linkDistance(String km) {
    return '$km km away';
  }

  @override
  String get linkAlreadyMember => 'You are already a member';

  @override
  String get linkOwnProfile => 'This is your profile';

  @override
  String get groupThemeTitle => 'Group theme';

  @override
  String get groupThemePreview => 'Preview';

  @override
  String get groupThemeControl => 'Who can change it';

  @override
  String get groupThemeControlEveryone => 'Everyone';

  @override
  String get groupThemeControlHostOnly => 'Host only';

  @override
  String get groupThemeControlLocked => 'Locked';

  @override
  String get groupThemePalette => 'Palette';

  @override
  String get groupThemePaletteFree =>
      'The free plan uses fixed black. Upgrade to PRO or VIP to pick colours.';

  @override
  String get groupThemeLockedHint => 'The host locked the theme.';

  @override
  String get groupThemeSaved => 'Theme updated';

  @override
  String get promptPacksTitle => 'packs';

  @override
  String get promptPacksEmpty => 'No packs available yet';

  @override
  String promptPacksCount(int count) {
    return '$count cards';
  }

  @override
  String get onboardingTagline => 'games to pass the time with friends';

  @override
  String get onboardingConsent => 'I confirm I am 18 or older and accept the';

  @override
  String get onboardingStart => 'accept';

  @override
  String get onboardingDecline => 'not now';

  @override
  String get onboardingDeclinedTitle => 'we can\'t let you in yet';

  @override
  String get onboardingDeclinedBody =>
      'To use Samay you have to confirm you are 18 or older and accept the terms and privacy policy. Nothing is saved until you do.';

  @override
  String get onboardingDeclinedBack => 'back to the terms';

  @override
  String get authSignInTitle => 'iniciar sesión';

  @override
  String get authSignInBody =>
      'Puedes jugar sin cuenta. Si inicias sesión con Apple o Google, tu progreso queda guardado y lo recuperas en otro dispositivo.';

  @override
  String get minigamesLocalNeedPlayers => 'Add at least two players.';

  @override
  String get minigamesLocalNoPack =>
      'No prompts are downloaded yet. Connect once to load the pack.';

  @override
  String get minigamesLocalIntro =>
      'One phone, everyone in the same room. Pass the phone: the judge reads, the player answers, then tap done or skip.';

  @override
  String minigamesLocalPlayerName(int number) {
    return 'Player $number';
  }

  @override
  String get minigamesLocalAddPlayer => 'Add player';

  @override
  String get minigamesLocalStart => 'start';

  @override
  String get minigamesLocalTie => 'tie';

  @override
  String get minigamesLocalPlayAgain => 'play again';

  @override
  String minigamesLocalJudge(String name) {
    return '$name reads';
  }

  @override
  String get minigamesLocalNoPrompt => 'No prompt for this round.';

  @override
  String get minigamesLocalDone => 'done';

  @override
  String get minigamesLocalSkip => 'skip';

  @override
  String get minigamesLocalSingleDevice => 'on this phone';

  @override
  String get minigamesLocalMode => 'one phone';

  @override
  String get minigamesLeave => 'salir de la partida';

  @override
  String get minigamesLeaveConfirm => '¿Salir de esta partida?';

  @override
  String get onboardingAcceptTerms => 'Terms';

  @override
  String get onboardingAcceptAnd => 'and the';

  @override
  String get onboardingAcceptPrivacy => 'Privacy Policy';

  @override
  String get minigamesPlayNow => 'play now';

  @override
  String get minigamesChoosePlayers => 'choose players';

  @override
  String get minigamesEditPlayers => 'players';

  @override
  String get menuSocial => 'social';

  @override
  String get menuPacks => 'paquetes';

  @override
  String get menuNotifications => 'notis';

  @override
  String get menuProfile => 'perfil';

  @override
  String get menuSettings => 'ajustes';

  @override
  String get menuSignIn => 'iniciar sesión';

  @override
  String get minigamesLobbyPlayersQuestion => 'How many are playing?';

  @override
  String get minigamesLobbyPlayersHint => 'At least 2 players.';

  @override
  String get minigamesLobbyNamePrompt => 'Enter your name or alias';

  @override
  String get minigamesLobbyPassRight =>
      'Pass the device to someone on your right';

  @override
  String minigamesLobbyNamesProgress(int done, int total) {
    return '$done of $total';
  }

  @override
  String get minigamesLobbySaveGroupQuestion => 'Save this group?';

  @override
  String get minigamesLobbySaveGroupHint =>
      'You can reuse it on the next game night.';

  @override
  String get minigamesLobbyGroupNameLabel => 'Group name';

  @override
  String get minigamesLobbySavedGroups => 'Saved groups';

  @override
  String get minigamesLobbyNoSavedGroups => 'No saved groups yet.';

  @override
  String get minigamesLobbyUseGroup => 'use';

  @override
  String get minigamesLobbyPlayersTitle => 'Players';

  @override
  String get minigamesLobbyEditPlayer => 'change name';

  @override
  String get minigamesLobbyRoundsTitle => 'Rounds';

  @override
  String get minigamesLobbyPlay => 'play';

  @override
  String get minigamesLobbyNameRequired => 'Enter a name.';

  @override
  String get minigamesLobbySaved => 'group saved';

  @override
  String get minigamesLobbyDeleteGroup => 'Delete group';

  @override
  String get charadesTiltDown => 'Tilt the phone down when they get it';

  @override
  String get charadesTiltUp => 'Tilt up to pass';

  @override
  String get charadesHoldForehead => 'Hold the phone on your forehead';

  @override
  String get charadesGetReady => 'Get ready…';

  @override
  String get charadesCorrect => 'Correct!';

  @override
  String get charadesPassed => 'Passed';

  @override
  String charadesWordsLeft(int count) {
    return '$count words left';
  }

  @override
  String charadesPrecision(int percent) {
    return '$percent% accuracy';
  }

  @override
  String get charadesCategoryAnimals => 'Animals';

  @override
  String get charadesCategoryPop => 'Pop culture';

  @override
  String get charadesCategoryLiterature => 'Literature';

  @override
  String get charadesCategoryArt => 'Art';

  @override
  String get charadesCategorySports => 'Sports';

  @override
  String get charadesCategoryDrama => 'Drama & TV';

  @override
  String get charadesCategoryFood => 'Food';

  @override
  String get charadesLobbyTitle => 'Charades';

  @override
  String get charadesLobbyPlayers => 'Player\'s turn';

  @override
  String get commonSkip => 'Skip';

  @override
  String minigamesLocalTurnOf(String name) {
    return 'turn of $name';
  }

  @override
  String minigamesLocalPassTo(String name) {
    return 'pass the phone to $name';
  }

  @override
  String get minigamesLocalSpin => 'spin the bottle';

  @override
  String get minigamesLocalSpinning => 'spinning…';

  @override
  String minigamesLocalLandedOn(String name) {
    return 'it landed on $name';
  }

  @override
  String minigamesLocalCharadesTurn(String name) {
    return '$name guesses';
  }

  @override
  String minigamesLocalRoundOf(int round, int total) {
    return 'round $round of $total';
  }

  @override
  String get minigamesLeaderboardEmpty => 'No games played yet.';

  @override
  String minigamesLeaderboardGames(int count) {
    return '$count games';
  }

  @override
  String get minigamesLobbyNeedPlayers => 'You need at least two players.';

  @override
  String get minigamesLobbyEditTitle => 'Change name';

  @override
  String get minigamesLobbyAddTitle => 'Add player';

  @override
  String minigamesLobbyPlayerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count players',
      one: '1 player',
    );
    return '$_temp0';
  }

  @override
  String get minigamesLobbyRosterHint => 'Tap a name to change it';

  @override
  String get minigamesLobbyCustom => 'Custom';

  @override
  String get minigamesLobbyCustomRounds => 'Number of rounds…';

  @override
  String get minigamesLobbyCustomSeconds => 'Number of seconds…';

  @override
  String get minigamesLobbyReorderHint => 'Hold and drag to change the order';
}
