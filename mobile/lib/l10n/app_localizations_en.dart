// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Skidoo';

  @override
  String get securityWarningTitle => 'Security Warning';

  @override
  String get securityWarningBody =>
      'This device appears to be jailbroken or rooted.\n\nRunning Skidoo on a compromised device exposes your account, messages, and payment data to elevated risk. We strongly recommend using a secure, unmodified device.';

  @override
  String get securityWarningContinue => 'I understand, continue anyway';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginSignInToAccount => 'Sign in to your account';

  @override
  String get loginEmailAddress => 'Email address';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginNoAccount => 'Don\'t have an account?  ';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String get signupCreateAccount => 'Create account';

  @override
  String get signupSubtitle => 'Join and explore moments that matter';

  @override
  String get signupEmailAddress => 'Email address';

  @override
  String get signupUsername => 'Username';

  @override
  String get signupPhoneNumber => 'Phone number';

  @override
  String get signupPassword => 'Password';

  @override
  String get signupConfirmPassword => 'Confirm password';

  @override
  String get signupPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get signupCreateAccountButton => 'Create Account';

  @override
  String get signupAlreadyHaveAccount => 'Already have an account?  ';

  @override
  String get signupSignIn => 'Sign in';

  @override
  String get signupAccountCreated => 'Account created! Please log in.';

  @override
  String get signupFaceCaptured => 'Face captured';

  @override
  String get signupRegisterFace => 'Register your face';

  @override
  String get signupTapToRetake => 'Tap to retake photo';

  @override
  String get signupTapToOpenCamera => 'Tap to open camera';

  @override
  String get signupFaceRequired => 'Face photo is required';

  @override
  String get signupNoCameraAvailable => 'No camera available.';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordResetTitle => 'Reset Password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email to receive a reset link';

  @override
  String get forgotPasswordEmail => 'Email';

  @override
  String get forgotPasswordSendLink => 'Send Reset Link';

  @override
  String get forgotPasswordLinkSent => 'Reset link sent to your email.';

  @override
  String get interestsTitle => 'What interests you?';

  @override
  String get interestsSubtitle => 'Select topics to personalise your feed';

  @override
  String get interestsContinue => 'Continue';

  @override
  String get interestsSkip => 'Skip for now';

  @override
  String get navHome => 'Home';

  @override
  String get navMessages => 'Messages';

  @override
  String get navGallery => 'Gallery';

  @override
  String get navCreators => 'Creators';

  @override
  String get homeSearchEvents => 'Search events...';

  @override
  String get homeSearchAiPlaceholder => 'Search your image with our AI';

  @override
  String get homeNoEventsFound => 'No events found';

  @override
  String get homeNoEventsYet => 'No events yet';

  @override
  String get searchResultsTitle => 'Search Results';

  @override
  String get searchResultsSelectAll => 'Select All';

  @override
  String get searchResultsDeselectAll => 'Deselect All';

  @override
  String get searchResultsSelect => 'Select';

  @override
  String searchResultsSelected(int count) {
    return '$count selected';
  }

  @override
  String searchResultsSaveSelected(int count) {
    return 'Save Selected ($count)';
  }

  @override
  String searchResultsSaveAll(int count) {
    return 'Save All ($count)';
  }

  @override
  String searchResultsSaveAllPhotos(int count) {
    return 'Save All Photos ($count)';
  }

  @override
  String get searchResultsPick => 'Pick';

  @override
  String get searchResultsScanningPhotos => 'Scanning your photos…';

  @override
  String get searchResultsMayTakeAMoment => 'This may take a moment';

  @override
  String get searchResultsFindingMore => 'Finding more…';

  @override
  String get searchResultsNoPhotos => 'No photos found';

  @override
  String searchResultsPhotosSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos saved to your gallery!',
      one: '1 photo saved to your gallery!',
    );
    return '$_temp0';
  }

  @override
  String get discoveryContentHidden => 'Content hidden';

  @override
  String get discoveryUndo => 'Undo';

  @override
  String get discoveryNoEventsYet => 'No events yet';

  @override
  String get savedItemsTitle => 'Saved';

  @override
  String get savedItemsNoItems => 'No saved items yet';

  @override
  String get savedItemsBookmarkHint => 'Bookmark events to find them here.';

  @override
  String get savedItemsRetry => 'Retry';

  @override
  String get savedItemsCouldNotLoad => 'Could not load saved items.';

  @override
  String get savedItemsCouldNotLoadEvent => 'Could not load event details.';

  @override
  String get savedItemsFailedToRemove => 'Failed to remove item.';

  @override
  String get savedItemsUnsave => 'Unsave';

  @override
  String get savedItemsEventSubtitle => 'Event';

  @override
  String get savedItemsDefaultName => 'Saved Event';

  @override
  String get galleryTitle => 'My Gallery';

  @override
  String galleryPhotoCount(int count) {
    return '$count photos';
  }

  @override
  String get galleryEmpty =>
      'Your gallery is empty\nPhotos from your events will appear here';

  @override
  String get shareSheetTitle => 'Send to…';

  @override
  String get shareSheetSearchByName => 'Search by name…';

  @override
  String get shareSheetTypeToSearch => 'Type a name to search';

  @override
  String get shareSheetNoUsersFound => 'No users found.';

  @override
  String get shareSheetCreator => 'Creator';

  @override
  String get shareSheetUser => 'User';

  @override
  String get shareSheetNotAcceptingMessages =>
      'This user is not accepting messages.';

  @override
  String shareSheetCouldNotOpenChat(String error) {
    return 'Could not open chat: $error';
  }

  @override
  String get cartTitle => 'My Cart';

  @override
  String get cartEmpty => 'Cart Empty';

  @override
  String cartPay(Object amount) {
    return 'Pay $amount';
  }

  @override
  String get cartPaymentSuccess => 'Payment successful!';

  @override
  String get cartImageDownloaded => 'Image downloaded successfully.';

  @override
  String get checkoutTitle => 'Pay for your images';

  @override
  String checkoutWebError(String description) {
    return 'Web error: $description';
  }

  @override
  String get photographersNoCreators => 'No creators found.';

  @override
  String get photographerProfileSampleWork => 'Sample Work';

  @override
  String get photographerProfileEvents => 'Events';

  @override
  String photographerProfileChatWith(String name) {
    return 'Chat with $name';
  }

  @override
  String get photographerProfileCouldNotLoadSamples =>
      'Could not load samples.';

  @override
  String get photographerProfileNoSamples => 'No sample images yet.';

  @override
  String get photographerProfileNoEvents => 'No events yet.';

  @override
  String get photographerProfileRetry => 'Retry';

  @override
  String get photographerProfileNotAcceptingConversations =>
      'This user isn\'t accepting new conversations.';

  @override
  String photographerProfileCouldNotOpenChat(String error) {
    return 'Could not open chat: $error';
  }

  @override
  String get accountTitle => 'Account';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountProfileUpdated => 'Profile updated successfully';

  @override
  String get accountEditProfile => 'Edit Profile';

  @override
  String get accountSaveChanges => 'Save changes';

  @override
  String get accountBasicInfo => 'Basic info';

  @override
  String get accountDisplayName => 'Display name';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountPhoneNumber => 'Phone number';

  @override
  String get accountLocaleRegion => 'Locale & region';

  @override
  String get accountCountryCode => 'Country code (e.g. US)';

  @override
  String get accountLocale => 'Locale (e.g. en-US)';

  @override
  String get accountPreferredLanguage => 'Preferred language (e.g. en)';

  @override
  String get accountTimezone => 'Timezone (e.g. America/New_York)';

  @override
  String get accountPhotographyInterests => 'Photography interests';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get accountDarkMode => 'Dark Mode';

  @override
  String get accountDarkThemeOn => 'Dark theme is on';

  @override
  String get accountLightThemeOn => 'Light theme is on';

  @override
  String get accountPublication => 'Publication';

  @override
  String get accountAlwaysPublicImages => 'Always add public images';

  @override
  String get accountUploadsPublicByDefault =>
      'New uploads are public by default';

  @override
  String get accountUploadsPrivateByDefault =>
      'New uploads are private by default';

  @override
  String get accountSavedItems => 'Saved items';

  @override
  String get accountViewBookmarkedEvents => 'View your bookmarked events';

  @override
  String get accountPrivacy => 'Privacy';

  @override
  String get accountAnonymousComments => 'Anonymous comments';

  @override
  String get accountAnonymousModeOn => 'Your name appears as \"Anonymous\"';

  @override
  String get accountAnonymousModeOff => 'Your name is shown on comments';

  @override
  String get accountHideProfile => 'Hide profile';

  @override
  String get accountHideProfileOn =>
      'Others cannot start new conversations with you';

  @override
  String get accountHideProfileOff =>
      'Anyone can start a conversation with you';

  @override
  String get accountAnonymousModeUpdateFailed =>
      'Could not update anonymous mode.';

  @override
  String get accountHideProfileUpdateFailed => 'Could not update hide profile.';

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountMuteNotifications => 'Mute message sounds & vibration';

  @override
  String get accountMutedOn => 'Messages arrive silently';

  @override
  String get accountMutedOff => 'You\'ll feel a vibration for new messages';

  @override
  String get chatRoomsTitle => 'Messages';

  @override
  String get chatRoomsGlobalChat => 'Global Chat';

  @override
  String get chatRoomsNewGroup => 'New Group';

  @override
  String get chatRoomsNoConversations => 'No conversations yet.';

  @override
  String get chatRoomsJoinGlobalChat => 'Join Global Chat';

  @override
  String get chatRoomsPendingInvites => 'Pending Invites';

  @override
  String get chatRoomsChats => 'Chats';

  @override
  String get chatRoomsYouWereInvited => 'You were invited to join';

  @override
  String get chatRoomsJoin => 'Join';

  @override
  String get chatRoomsDecline => 'Decline';

  @override
  String get chatRoomConnecting => 'Connecting…';

  @override
  String get chatRoomDisconnected => 'Disconnected';

  @override
  String get chatRoomEndToEndEncrypted => 'End-to-end encrypted';

  @override
  String get chatRoomNoMessages => 'No messages yet.\nSay hello!';

  @override
  String get chatRoomOnlyAdminsCanSend => 'Only admins can send messages';

  @override
  String get chatRoomAddPeople => 'Add people';

  @override
  String get chatRoomEditMessage => 'Edit message';

  @override
  String get chatRoomEditYourMessage => 'Edit your message…';

  @override
  String get chatRoomCancel => 'Cancel';

  @override
  String get chatRoomSave => 'Save';

  @override
  String get chatRoomDeleteMessage => 'Delete message';

  @override
  String get chatRoomDeleteForEveryone =>
      'This message will be deleted for everyone.';

  @override
  String get chatRoomDelete => 'Delete';

  @override
  String get chatRoomReply => 'Reply';

  @override
  String get chatRoomEdit => 'Edit';

  @override
  String get chatRoomMessageDirectly => 'Message directly';

  @override
  String get chatRoomNotAcceptingMessages =>
      'This user is not accepting messages.';

  @override
  String chatRoomCouldNotOpenChat(String error) {
    return 'Could not open chat: $error';
  }

  @override
  String chatRoomInvitedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people invited',
      one: '1 person invited',
    );
    return '$_temp0';
  }

  @override
  String get chatRoomEncryptedMessage => 'Encrypted message';

  @override
  String get chatRoomEdited => 'edited';

  @override
  String get chatRoomTypeSubtitleGlobal => 'Everyone';

  @override
  String get chatRoomTypeSubtitleDirect => 'Direct message';

  @override
  String get chatRoomTypeSubtitleEvent => 'Event discussion';

  @override
  String get chatRoomTypeSubtitleEventPrivate => 'Private event room';

  @override
  String get chatRoomTypeSubtitlePhoto => 'Photo comments';

  @override
  String get chatRoomTypeSubtitleSample => 'Sample image chat';

  @override
  String chatRoomTypeSubtitleGroupMembers(int count) {
    return '$count members';
  }

  @override
  String get chatRoomTypeSubtitleGroupChat => 'Group chat';

  @override
  String get chatRoomTypeSubtitleChatRoom => 'Chat room';

  @override
  String get chatRoomTimeYesterday => 'Yesterday';

  @override
  String get groupInfoTitle => 'Group info';

  @override
  String get groupInfoNoData => 'No group data.';

  @override
  String get groupInfoGroupLabel => 'Group';

  @override
  String groupInfoParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoOnlyAdminsCanSend => 'Only admins can send messages';

  @override
  String get groupInfoAdminOnlySubtitleOn =>
      'Only admins can send messages in this group.';

  @override
  String get groupInfoAdminOnlySubtitleOff => 'All members can send messages.';

  @override
  String get groupInfoAdminBadge => 'Admin';

  @override
  String get groupInfoYou => '(you)';

  @override
  String get groupInfoMakeAdmin => 'Make group admin';

  @override
  String get groupInfoRemoveAdmin => 'Remove as admin';

  @override
  String get groupInfoRemoveFromGroup => 'Remove from group';

  @override
  String get inviteToGroupTitle => 'Add People';

  @override
  String get inviteToGroupInvite => 'Invite';

  @override
  String get inviteToGroupSearchPeople => 'Search people...';

  @override
  String get inviteToGroupNoUsersFound => 'No users found.';

  @override
  String get inviteToGroupSearchForPeople => 'Search for people to add.';

  @override
  String inviteToGroupCouldNotInvite(String names) {
    return 'Could not invite: $names';
  }

  @override
  String get createGroupTitle => 'New Group';

  @override
  String get createGroupCreate => 'Create';

  @override
  String get createGroupNameHint => 'Group name';

  @override
  String get createGroupNameRequired => 'Group name is required.';

  @override
  String get createGroupSearchPeople => 'Search people to add...';

  @override
  String get createGroupNoUsersFound => 'No users found.';

  @override
  String get createGroupCouldNotCreate =>
      'Could not create group. Please try again.';
}
