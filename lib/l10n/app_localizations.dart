import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('de'),
    Locale('en')
  ];

  /// App name
  ///
  /// In en, this message translates to:
  /// **'Skidoo'**
  String get appName;

  /// No description provided for @securityWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarningTitle;

  /// No description provided for @securityWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This device appears to be jailbroken or rooted.\n\nRunning Skidoo on a compromised device exposes your account, messages, and payment data to elevated risk. We strongly recommend using a secure, unmodified device.'**
  String get securityWarningBody;

  /// No description provided for @securityWarningContinue.
  ///
  /// In en, this message translates to:
  /// **'I understand, continue anyway'**
  String get securityWarningContinue;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSignInToAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get loginSignInToAccount;

  /// No description provided for @loginEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginEmailAddress;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginSignIn;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?  '**
  String get loginNoAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get loginSignUp;

  /// No description provided for @signupCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signupCreateAccount;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join and explore moments that matter'**
  String get signupSubtitle;

  /// No description provided for @signupEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signupEmailAddress;

  /// No description provided for @signupUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get signupUsername;

  /// No description provided for @signupPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get signupPhoneNumber;

  /// No description provided for @signupPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get signupPassword;

  /// No description provided for @signupConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get signupConfirmPassword;

  /// No description provided for @signupPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupPasswordsDoNotMatch;

  /// No description provided for @signupCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupCreateAccountButton;

  /// No description provided for @signupAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?  '**
  String get signupAlreadyHaveAccount;

  /// No description provided for @signupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signupSignIn;

  /// No description provided for @signupAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please log in.'**
  String get signupAccountCreated;

  /// No description provided for @signupFaceCaptured.
  ///
  /// In en, this message translates to:
  /// **'Face captured'**
  String get signupFaceCaptured;

  /// No description provided for @signupRegisterFace.
  ///
  /// In en, this message translates to:
  /// **'Register your face'**
  String get signupRegisterFace;

  /// No description provided for @signupTapToRetake.
  ///
  /// In en, this message translates to:
  /// **'Tap to retake photo'**
  String get signupTapToRetake;

  /// No description provided for @signupTapToOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Tap to open camera'**
  String get signupTapToOpenCamera;

  /// No description provided for @signupFaceRequired.
  ///
  /// In en, this message translates to:
  /// **'Face photo is required'**
  String get signupFaceRequired;

  /// No description provided for @signupNoCameraAvailable.
  ///
  /// In en, this message translates to:
  /// **'No camera available.'**
  String get signupNoCameraAvailable;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordResetTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a reset link'**
  String get forgotPasswordSubtitle;

  /// No description provided for @forgotPasswordEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmail;

  /// No description provided for @forgotPasswordSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get forgotPasswordSendLink;

  /// No description provided for @forgotPasswordLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Reset link sent to your email.'**
  String get forgotPasswordLinkSent;

  /// No description provided for @interestsTitle.
  ///
  /// In en, this message translates to:
  /// **'What interests you?'**
  String get interestsTitle;

  /// No description provided for @interestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select topics to personalise your feed'**
  String get interestsSubtitle;

  /// No description provided for @interestsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get interestsContinue;

  /// No description provided for @interestsSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get interestsSkip;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get navGallery;

  /// No description provided for @navCreators.
  ///
  /// In en, this message translates to:
  /// **'Creators'**
  String get navCreators;

  /// No description provided for @homeSearchEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get homeSearchEvents;

  /// No description provided for @homeNoEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get homeNoEventsFound;

  /// No description provided for @homeNoEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get homeNoEventsYet;

  /// No description provided for @searchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get searchResultsTitle;

  /// No description provided for @searchResultsSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get searchResultsSelectAll;

  /// No description provided for @searchResultsSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get searchResultsSelect;

  /// No description provided for @searchResultsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String searchResultsSelected(int count);

  /// No description provided for @searchResultsSaveSelected.
  ///
  /// In en, this message translates to:
  /// **'Save Selected ({count})'**
  String searchResultsSaveSelected(int count);

  /// No description provided for @searchResultsSaveAll.
  ///
  /// In en, this message translates to:
  /// **'Save All ({count})'**
  String searchResultsSaveAll(int count);

  /// No description provided for @searchResultsSaveAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save All Photos ({count})'**
  String searchResultsSaveAllPhotos(int count);

  /// No description provided for @searchResultsPick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get searchResultsPick;

  /// No description provided for @searchResultsScanningPhotos.
  ///
  /// In en, this message translates to:
  /// **'Scanning your photos…'**
  String get searchResultsScanningPhotos;

  /// No description provided for @searchResultsMayTakeAMoment.
  ///
  /// In en, this message translates to:
  /// **'This may take a moment'**
  String get searchResultsMayTakeAMoment;

  /// No description provided for @searchResultsFindingMore.
  ///
  /// In en, this message translates to:
  /// **'Finding more…'**
  String get searchResultsFindingMore;

  /// No description provided for @searchResultsNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get searchResultsNoPhotos;

  /// No description provided for @searchResultsPhotosSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo saved to your gallery!} other{{count} photos saved to your gallery!}}'**
  String searchResultsPhotosSaved(int count);

  /// No description provided for @discoveryContentHidden.
  ///
  /// In en, this message translates to:
  /// **'Content hidden'**
  String get discoveryContentHidden;

  /// No description provided for @discoveryUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get discoveryUndo;

  /// No description provided for @discoveryNoEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get discoveryNoEventsYet;

  /// No description provided for @savedItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedItemsTitle;

  /// No description provided for @savedItemsNoItems.
  ///
  /// In en, this message translates to:
  /// **'No saved items yet'**
  String get savedItemsNoItems;

  /// No description provided for @savedItemsBookmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Bookmark events to find them here.'**
  String get savedItemsBookmarkHint;

  /// No description provided for @savedItemsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get savedItemsRetry;

  /// No description provided for @savedItemsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load saved items.'**
  String get savedItemsCouldNotLoad;

  /// No description provided for @savedItemsCouldNotLoadEvent.
  ///
  /// In en, this message translates to:
  /// **'Could not load event details.'**
  String get savedItemsCouldNotLoadEvent;

  /// No description provided for @savedItemsFailedToRemove.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove item.'**
  String get savedItemsFailedToRemove;

  /// No description provided for @savedItemsUnsave.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get savedItemsUnsave;

  /// No description provided for @savedItemsEventSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get savedItemsEventSubtitle;

  /// No description provided for @savedItemsDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Saved Event'**
  String get savedItemsDefaultName;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'My Gallery'**
  String get galleryTitle;

  /// No description provided for @galleryPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} photos'**
  String galleryPhotoCount(int count);

  /// No description provided for @galleryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your gallery is empty\nPhotos from your events will appear here'**
  String get galleryEmpty;

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to…'**
  String get shareSheetTitle;

  /// No description provided for @shareSheetSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name…'**
  String get shareSheetSearchByName;

  /// No description provided for @shareSheetTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type a name to search'**
  String get shareSheetTypeToSearch;

  /// No description provided for @shareSheetNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get shareSheetNoUsersFound;

  /// No description provided for @shareSheetCreator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get shareSheetCreator;

  /// No description provided for @shareSheetUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get shareSheetUser;

  /// No description provided for @shareSheetNotAcceptingMessages.
  ///
  /// In en, this message translates to:
  /// **'This user is not accepting messages.'**
  String get shareSheetNotAcceptingMessages;

  /// No description provided for @shareSheetCouldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat: {error}'**
  String shareSheetCouldNotOpenChat(String error);

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get cartTitle;

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart Empty'**
  String get cartEmpty;

  /// No description provided for @cartPay.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String cartPay(Object amount);

  /// No description provided for @cartPaymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get cartPaymentSuccess;

  /// No description provided for @cartImageDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Image downloaded successfully.'**
  String get cartImageDownloaded;

  /// No description provided for @checkoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Pay for your images'**
  String get checkoutTitle;

  /// No description provided for @checkoutWebError.
  ///
  /// In en, this message translates to:
  /// **'Web error: {description}'**
  String checkoutWebError(String description);

  /// No description provided for @photographersNoCreators.
  ///
  /// In en, this message translates to:
  /// **'No creators found.'**
  String get photographersNoCreators;

  /// No description provided for @photographerProfileSampleWork.
  ///
  /// In en, this message translates to:
  /// **'Sample Work'**
  String get photographerProfileSampleWork;

  /// No description provided for @photographerProfileEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get photographerProfileEvents;

  /// No description provided for @photographerProfileChatWith.
  ///
  /// In en, this message translates to:
  /// **'Chat with {name}'**
  String photographerProfileChatWith(String name);

  /// No description provided for @photographerProfileCouldNotLoadSamples.
  ///
  /// In en, this message translates to:
  /// **'Could not load samples.'**
  String get photographerProfileCouldNotLoadSamples;

  /// No description provided for @photographerProfileNoSamples.
  ///
  /// In en, this message translates to:
  /// **'No sample images yet.'**
  String get photographerProfileNoSamples;

  /// No description provided for @photographerProfileNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get photographerProfileNoEvents;

  /// No description provided for @photographerProfileRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get photographerProfileRetry;

  /// No description provided for @photographerProfileNotAcceptingConversations.
  ///
  /// In en, this message translates to:
  /// **'This user isn\'t accepting new conversations.'**
  String get photographerProfileNotAcceptingConversations;

  /// No description provided for @photographerProfileCouldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat: {error}'**
  String photographerProfileCouldNotOpenChat(String error);

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get accountLogout;

  /// No description provided for @accountProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get accountProfileUpdated;

  /// No description provided for @accountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get accountEditProfile;

  /// No description provided for @accountSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get accountSaveChanges;

  /// No description provided for @accountBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get accountBasicInfo;

  /// No description provided for @accountDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get accountDisplayName;

  /// No description provided for @accountUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get accountUsername;

  /// No description provided for @accountPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get accountPhoneNumber;

  /// No description provided for @accountLocaleRegion.
  ///
  /// In en, this message translates to:
  /// **'Locale & region'**
  String get accountLocaleRegion;

  /// No description provided for @accountCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code (e.g. US)'**
  String get accountCountryCode;

  /// No description provided for @accountLocale.
  ///
  /// In en, this message translates to:
  /// **'Locale (e.g. en-US)'**
  String get accountLocale;

  /// No description provided for @accountPreferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language (e.g. en)'**
  String get accountPreferredLanguage;

  /// No description provided for @accountTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone (e.g. America/New_York)'**
  String get accountTimezone;

  /// No description provided for @accountPhotographyInterests.
  ///
  /// In en, this message translates to:
  /// **'Photography interests'**
  String get accountPhotographyInterests;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// No description provided for @accountDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get accountDarkMode;

  /// No description provided for @accountDarkThemeOn.
  ///
  /// In en, this message translates to:
  /// **'Dark theme is on'**
  String get accountDarkThemeOn;

  /// No description provided for @accountLightThemeOn.
  ///
  /// In en, this message translates to:
  /// **'Light theme is on'**
  String get accountLightThemeOn;

  /// No description provided for @accountPublication.
  ///
  /// In en, this message translates to:
  /// **'Publication'**
  String get accountPublication;

  /// No description provided for @accountAlwaysPublicImages.
  ///
  /// In en, this message translates to:
  /// **'Always add public images'**
  String get accountAlwaysPublicImages;

  /// No description provided for @accountUploadsPublicByDefault.
  ///
  /// In en, this message translates to:
  /// **'New uploads are public by default'**
  String get accountUploadsPublicByDefault;

  /// No description provided for @accountUploadsPrivateByDefault.
  ///
  /// In en, this message translates to:
  /// **'New uploads are private by default'**
  String get accountUploadsPrivateByDefault;

  /// No description provided for @accountSavedItems.
  ///
  /// In en, this message translates to:
  /// **'Saved items'**
  String get accountSavedItems;

  /// No description provided for @accountViewBookmarkedEvents.
  ///
  /// In en, this message translates to:
  /// **'View your bookmarked events'**
  String get accountViewBookmarkedEvents;

  /// No description provided for @accountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get accountPrivacy;

  /// No description provided for @accountAnonymousComments.
  ///
  /// In en, this message translates to:
  /// **'Anonymous comments'**
  String get accountAnonymousComments;

  /// No description provided for @accountAnonymousModeOn.
  ///
  /// In en, this message translates to:
  /// **'Your name appears as \"Anonymous\"'**
  String get accountAnonymousModeOn;

  /// No description provided for @accountAnonymousModeOff.
  ///
  /// In en, this message translates to:
  /// **'Your name is shown on comments'**
  String get accountAnonymousModeOff;

  /// No description provided for @accountHideProfile.
  ///
  /// In en, this message translates to:
  /// **'Hide profile'**
  String get accountHideProfile;

  /// No description provided for @accountHideProfileOn.
  ///
  /// In en, this message translates to:
  /// **'Others cannot start new conversations with you'**
  String get accountHideProfileOn;

  /// No description provided for @accountHideProfileOff.
  ///
  /// In en, this message translates to:
  /// **'Anyone can start a conversation with you'**
  String get accountHideProfileOff;

  /// No description provided for @accountAnonymousModeUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update anonymous mode.'**
  String get accountAnonymousModeUpdateFailed;

  /// No description provided for @accountHideProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update hide profile.'**
  String get accountHideProfileUpdateFailed;

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountMuteNotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute message sounds & vibration'**
  String get accountMuteNotifications;

  /// No description provided for @accountMutedOn.
  ///
  /// In en, this message translates to:
  /// **'Messages arrive silently'**
  String get accountMutedOn;

  /// No description provided for @accountMutedOff.
  ///
  /// In en, this message translates to:
  /// **'You\'ll feel a vibration for new messages'**
  String get accountMutedOff;

  /// No description provided for @chatRoomsTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get chatRoomsTitle;

  /// No description provided for @chatRoomsGlobalChat.
  ///
  /// In en, this message translates to:
  /// **'Global Chat'**
  String get chatRoomsGlobalChat;

  /// No description provided for @chatRoomsNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get chatRoomsNewGroup;

  /// No description provided for @chatRoomsNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get chatRoomsNoConversations;

  /// No description provided for @chatRoomsJoinGlobalChat.
  ///
  /// In en, this message translates to:
  /// **'Join Global Chat'**
  String get chatRoomsJoinGlobalChat;

  /// No description provided for @chatRoomsPendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending Invites'**
  String get chatRoomsPendingInvites;

  /// No description provided for @chatRoomsChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chatRoomsChats;

  /// No description provided for @chatRoomsYouWereInvited.
  ///
  /// In en, this message translates to:
  /// **'You were invited to join'**
  String get chatRoomsYouWereInvited;

  /// No description provided for @chatRoomsJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get chatRoomsJoin;

  /// No description provided for @chatRoomsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get chatRoomsDecline;

  /// No description provided for @chatRoomConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get chatRoomConnecting;

  /// No description provided for @chatRoomDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get chatRoomDisconnected;

  /// No description provided for @chatRoomEndToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get chatRoomEndToEndEncrypted;

  /// No description provided for @chatRoomNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nSay hello!'**
  String get chatRoomNoMessages;

  /// No description provided for @chatRoomOnlyAdminsCanSend.
  ///
  /// In en, this message translates to:
  /// **'Only admins can send messages'**
  String get chatRoomOnlyAdminsCanSend;

  /// No description provided for @chatRoomAddPeople.
  ///
  /// In en, this message translates to:
  /// **'Add people'**
  String get chatRoomAddPeople;

  /// No description provided for @chatRoomEditMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get chatRoomEditMessage;

  /// No description provided for @chatRoomEditYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit your message…'**
  String get chatRoomEditYourMessage;

  /// No description provided for @chatRoomCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatRoomCancel;

  /// No description provided for @chatRoomSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatRoomSave;

  /// No description provided for @chatRoomDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message'**
  String get chatRoomDeleteMessage;

  /// No description provided for @chatRoomDeleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'This message will be deleted for everyone.'**
  String get chatRoomDeleteForEveryone;

  /// No description provided for @chatRoomDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatRoomDelete;

  /// No description provided for @chatRoomReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatRoomReply;

  /// No description provided for @chatRoomEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatRoomEdit;

  /// No description provided for @chatRoomMessageDirectly.
  ///
  /// In en, this message translates to:
  /// **'Message directly'**
  String get chatRoomMessageDirectly;

  /// No description provided for @chatRoomNotAcceptingMessages.
  ///
  /// In en, this message translates to:
  /// **'This user is not accepting messages.'**
  String get chatRoomNotAcceptingMessages;

  /// No description provided for @chatRoomCouldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat: {error}'**
  String chatRoomCouldNotOpenChat(String error);

  /// No description provided for @chatRoomInvitedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person invited} other{{count} people invited}}'**
  String chatRoomInvitedCount(int count);

  /// No description provided for @chatRoomEncryptedMessage.
  ///
  /// In en, this message translates to:
  /// **'Encrypted message'**
  String get chatRoomEncryptedMessage;

  /// No description provided for @chatRoomEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get chatRoomEdited;

  /// No description provided for @chatRoomTypeSubtitleGlobal.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get chatRoomTypeSubtitleGlobal;

  /// No description provided for @chatRoomTypeSubtitleDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct message'**
  String get chatRoomTypeSubtitleDirect;

  /// No description provided for @chatRoomTypeSubtitleEvent.
  ///
  /// In en, this message translates to:
  /// **'Event discussion'**
  String get chatRoomTypeSubtitleEvent;

  /// No description provided for @chatRoomTypeSubtitleEventPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private event room'**
  String get chatRoomTypeSubtitleEventPrivate;

  /// No description provided for @chatRoomTypeSubtitlePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo comments'**
  String get chatRoomTypeSubtitlePhoto;

  /// No description provided for @chatRoomTypeSubtitleSample.
  ///
  /// In en, this message translates to:
  /// **'Sample image chat'**
  String get chatRoomTypeSubtitleSample;

  /// No description provided for @chatRoomTypeSubtitleGroupMembers.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String chatRoomTypeSubtitleGroupMembers(int count);

  /// No description provided for @chatRoomTypeSubtitleGroupChat.
  ///
  /// In en, this message translates to:
  /// **'Group chat'**
  String get chatRoomTypeSubtitleGroupChat;

  /// No description provided for @chatRoomTypeSubtitleChatRoom.
  ///
  /// In en, this message translates to:
  /// **'Chat room'**
  String get chatRoomTypeSubtitleChatRoom;

  /// No description provided for @chatRoomTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get chatRoomTimeYesterday;

  /// No description provided for @groupInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Group info'**
  String get groupInfoTitle;

  /// No description provided for @groupInfoNoData.
  ///
  /// In en, this message translates to:
  /// **'No group data.'**
  String get groupInfoNoData;

  /// No description provided for @groupInfoGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get groupInfoGroupLabel;

  /// No description provided for @groupInfoParticipantCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 participant} other{{count} participants}}'**
  String groupInfoParticipantCount(int count);

  /// No description provided for @groupInfoOnlyAdminsCanSend.
  ///
  /// In en, this message translates to:
  /// **'Only admins can send messages'**
  String get groupInfoOnlyAdminsCanSend;

  /// No description provided for @groupInfoAdminOnlySubtitleOn.
  ///
  /// In en, this message translates to:
  /// **'Only admins can send messages in this group.'**
  String get groupInfoAdminOnlySubtitleOn;

  /// No description provided for @groupInfoAdminOnlySubtitleOff.
  ///
  /// In en, this message translates to:
  /// **'All members can send messages.'**
  String get groupInfoAdminOnlySubtitleOff;

  /// No description provided for @groupInfoAdminBadge.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get groupInfoAdminBadge;

  /// No description provided for @groupInfoYou.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get groupInfoYou;

  /// No description provided for @groupInfoMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make group admin'**
  String get groupInfoMakeAdmin;

  /// No description provided for @groupInfoRemoveAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove as admin'**
  String get groupInfoRemoveAdmin;

  /// No description provided for @groupInfoRemoveFromGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get groupInfoRemoveFromGroup;

  /// No description provided for @inviteToGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Add People'**
  String get inviteToGroupTitle;

  /// No description provided for @inviteToGroupInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get inviteToGroupInvite;

  /// No description provided for @inviteToGroupSearchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people...'**
  String get inviteToGroupSearchPeople;

  /// No description provided for @inviteToGroupNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get inviteToGroupNoUsersFound;

  /// No description provided for @inviteToGroupSearchForPeople.
  ///
  /// In en, this message translates to:
  /// **'Search for people to add.'**
  String get inviteToGroupSearchForPeople;

  /// No description provided for @inviteToGroupCouldNotInvite.
  ///
  /// In en, this message translates to:
  /// **'Could not invite: {names}'**
  String inviteToGroupCouldNotInvite(String names);

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get createGroupTitle;

  /// No description provided for @createGroupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createGroupCreate;

  /// No description provided for @createGroupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get createGroupNameHint;

  /// No description provided for @createGroupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Group name is required.'**
  String get createGroupNameRequired;

  /// No description provided for @createGroupSearchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search people to add...'**
  String get createGroupSearchPeople;

  /// No description provided for @createGroupNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get createGroupNoUsersFound;

  /// No description provided for @createGroupCouldNotCreate.
  ///
  /// In en, this message translates to:
  /// **'Could not create group. Please try again.'**
  String get createGroupCouldNotCreate;
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
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
