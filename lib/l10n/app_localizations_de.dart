// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Skidoo';

  @override
  String get securityWarningTitle => 'Sicherheitswarnung';

  @override
  String get securityWarningBody =>
      'Dieses Gerät scheint gejailbreakt oder gerootet zu sein.\n\nDie Nutzung von Skidoo auf einem kompromittierten Gerät setzt Ihr Konto, Nachrichten und Zahlungsdaten einem erhöhten Risiko aus. Wir empfehlen dringend, ein sicheres, unmodifiziertes Gerät zu verwenden.';

  @override
  String get securityWarningContinue => 'Ich verstehe, trotzdem fortfahren';

  @override
  String get loginWelcomeBack => 'Willkommen zurück';

  @override
  String get loginSignInToAccount => 'Bei Ihrem Konto anmelden';

  @override
  String get loginEmailAddress => 'E-Mail-Adresse';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginForgotPassword => 'Passwort vergessen?';

  @override
  String get loginSignIn => 'Anmelden';

  @override
  String get loginNoAccount => 'Noch kein Konto?  ';

  @override
  String get loginSignUp => 'Registrieren';

  @override
  String get signupCreateAccount => 'Konto erstellen';

  @override
  String get signupSubtitle => 'Entdecken Sie besondere Momente';

  @override
  String get signupEmailAddress => 'E-Mail-Adresse';

  @override
  String get signupUsername => 'Benutzername';

  @override
  String get signupPhoneNumber => 'Telefonnummer';

  @override
  String get signupPassword => 'Passwort';

  @override
  String get signupConfirmPassword => 'Passwort bestätigen';

  @override
  String get signupPasswordsDoNotMatch => 'Passwörter stimmen nicht überein';

  @override
  String get signupCreateAccountButton => 'Konto erstellen';

  @override
  String get signupAlreadyHaveAccount => 'Bereits ein Konto?  ';

  @override
  String get signupSignIn => 'Anmelden';

  @override
  String get signupAccountCreated =>
      'Konto erstellt! Bitte melden Sie sich an.';

  @override
  String get signupFaceCaptured => 'Gesicht erfasst';

  @override
  String get signupRegisterFace => 'Gesicht registrieren';

  @override
  String get signupTapToRetake => 'Zum Neuaufnehmen tippen';

  @override
  String get signupTapToOpenCamera => 'Zum Öffnen der Kamera tippen';

  @override
  String get signupFaceRequired => 'Gesichtsfoto ist erforderlich';

  @override
  String get signupNoCameraAvailable => 'Keine Kamera verfügbar.';

  @override
  String get forgotPasswordTitle => 'Passwort vergessen';

  @override
  String get forgotPasswordResetTitle => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordSubtitle =>
      'E-Mail-Adresse eingeben, um einen Reset-Link zu erhalten';

  @override
  String get forgotPasswordEmail => 'E-Mail';

  @override
  String get forgotPasswordSendLink => 'Reset-Link senden';

  @override
  String get forgotPasswordLinkSent =>
      'Reset-Link wurde an Ihre E-Mail gesendet.';

  @override
  String get interestsTitle => 'Was interessiert Sie?';

  @override
  String get interestsSubtitle =>
      'Themen auswählen, um Ihren Feed zu personalisieren';

  @override
  String get interestsContinue => 'Weiter';

  @override
  String get interestsSkip => 'Jetzt überspringen';

  @override
  String get navHome => 'Startseite';

  @override
  String get navMessages => 'Nachrichten';

  @override
  String get navGallery => 'Galerie';

  @override
  String get navCreators => 'Fotografen';

  @override
  String get homeSearchEvents => 'Events suchen...';

  @override
  String get homeNoEventsFound => 'Keine Events gefunden';

  @override
  String get homeNoEventsYet => 'Noch keine Events';

  @override
  String get searchResultsTitle => 'Suchergebnisse';

  @override
  String get searchResultsSelectAll => 'Alle auswählen';

  @override
  String get searchResultsSelect => 'Auswählen';

  @override
  String searchResultsSelected(int count) {
    return '$count ausgewählt';
  }

  @override
  String searchResultsSaveSelected(int count) {
    return 'Auswahl speichern ($count)';
  }

  @override
  String searchResultsSaveAll(int count) {
    return 'Alle speichern ($count)';
  }

  @override
  String searchResultsSaveAllPhotos(int count) {
    return 'Alle Fotos speichern ($count)';
  }

  @override
  String get searchResultsPick => 'Auswählen';

  @override
  String get searchResultsScanningPhotos => 'Fotos werden durchsucht…';

  @override
  String get searchResultsMayTakeAMoment => 'Dies kann einen Moment dauern';

  @override
  String get searchResultsFindingMore => 'Weitere werden gesucht…';

  @override
  String get searchResultsNoPhotos => 'Keine Fotos gefunden';

  @override
  String searchResultsPhotosSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos in Ihrer Galerie gespeichert!',
      one: '1 Foto in Ihrer Galerie gespeichert!',
    );
    return '$_temp0';
  }

  @override
  String get discoveryContentHidden => 'Inhalt ausgeblendet';

  @override
  String get discoveryUndo => 'Rückgängig';

  @override
  String get discoveryNoEventsYet => 'Noch keine Events';

  @override
  String get savedItemsTitle => 'Gespeichert';

  @override
  String get savedItemsNoItems => 'Noch keine gespeicherten Elemente';

  @override
  String get savedItemsBookmarkHint =>
      'Lesezeichen für Events setzen, um sie hier zu finden.';

  @override
  String get savedItemsRetry => 'Erneut versuchen';

  @override
  String get savedItemsCouldNotLoad =>
      'Gespeicherte Elemente konnten nicht geladen werden.';

  @override
  String get savedItemsCouldNotLoadEvent =>
      'Event-Details konnten nicht geladen werden.';

  @override
  String get savedItemsFailedToRemove =>
      'Element konnte nicht entfernt werden.';

  @override
  String get savedItemsUnsave => 'Lesezeichen entfernen';

  @override
  String get savedItemsEventSubtitle => 'Event';

  @override
  String get savedItemsDefaultName => 'Gespeichertes Event';

  @override
  String get galleryTitle => 'Meine Galerie';

  @override
  String galleryPhotoCount(int count) {
    return '$count Fotos';
  }

  @override
  String get galleryEmpty =>
      'Ihre Galerie ist leer\nFotos aus Ihren Events erscheinen hier';

  @override
  String get shareSheetTitle => 'Senden an…';

  @override
  String get shareSheetSearchByName => 'Nach Name suchen…';

  @override
  String get shareSheetTypeToSearch => 'Namen eingeben, um zu suchen';

  @override
  String get shareSheetNoUsersFound => 'Keine Nutzer gefunden.';

  @override
  String get shareSheetCreator => 'Fotograf';

  @override
  String get shareSheetUser => 'Nutzer';

  @override
  String get shareSheetNotAcceptingMessages =>
      'Dieser Nutzer akzeptiert keine Nachrichten.';

  @override
  String shareSheetCouldNotOpenChat(String error) {
    return 'Chat konnte nicht geöffnet werden: $error';
  }

  @override
  String get cartTitle => 'Mein Warenkorb';

  @override
  String get cartEmpty => 'Warenkorb leer';

  @override
  String cartPay(Object amount) {
    return 'Bezahlen $amount';
  }

  @override
  String get cartPaymentSuccess => 'Zahlung erfolgreich!';

  @override
  String get cartImageDownloaded => 'Bild erfolgreich heruntergeladen.';

  @override
  String get checkoutTitle => 'Für Ihre Bilder bezahlen';

  @override
  String checkoutWebError(String description) {
    return 'Web-Fehler: $description';
  }

  @override
  String get photographersNoCreators => 'Keine Fotografen gefunden.';

  @override
  String get photographerProfileSampleWork => 'Beispielarbeiten';

  @override
  String get photographerProfileEvents => 'Events';

  @override
  String photographerProfileChatWith(String name) {
    return 'Chat mit $name';
  }

  @override
  String get photographerProfileCouldNotLoadSamples =>
      'Beispiele konnten nicht geladen werden.';

  @override
  String get photographerProfileNoSamples => 'Noch keine Beispielbilder.';

  @override
  String get photographerProfileNoEvents => 'Noch keine Events.';

  @override
  String get photographerProfileRetry => 'Erneut versuchen';

  @override
  String get photographerProfileNotAcceptingConversations =>
      'Dieser Nutzer akzeptiert keine neuen Gespräche.';

  @override
  String photographerProfileCouldNotOpenChat(String error) {
    return 'Chat konnte nicht geöffnet werden: $error';
  }

  @override
  String get accountTitle => 'Konto';

  @override
  String get accountLogout => 'Abmelden';

  @override
  String get accountProfileUpdated => 'Profil erfolgreich aktualisiert';

  @override
  String get accountEditProfile => 'Profil bearbeiten';

  @override
  String get accountSaveChanges => 'Änderungen speichern';

  @override
  String get accountBasicInfo => 'Grundlegende Informationen';

  @override
  String get accountDisplayName => 'Anzeigename';

  @override
  String get accountUsername => 'Benutzername';

  @override
  String get accountPhoneNumber => 'Telefonnummer';

  @override
  String get accountLocaleRegion => 'Sprache & Region';

  @override
  String get accountCountryCode => 'Ländercode (z.B. DE)';

  @override
  String get accountLocale => 'Gebietsschema (z.B. de-DE)';

  @override
  String get accountPreferredLanguage => 'Bevorzugte Sprache (z.B. de)';

  @override
  String get accountTimezone => 'Zeitzone (z.B. Europe/Berlin)';

  @override
  String get accountPhotographyInterests => 'Fotografie-Interessen';

  @override
  String get accountAppearance => 'Darstellung';

  @override
  String get accountDarkMode => 'Dunkler Modus';

  @override
  String get accountDarkThemeOn => 'Dunkles Design aktiviert';

  @override
  String get accountLightThemeOn => 'Helles Design aktiviert';

  @override
  String get accountPublication => 'Veröffentlichung';

  @override
  String get accountAlwaysPublicImages => 'Bilder immer öffentlich hinzufügen';

  @override
  String get accountUploadsPublicByDefault =>
      'Neue Uploads sind standardmäßig öffentlich';

  @override
  String get accountUploadsPrivateByDefault =>
      'Neue Uploads sind standardmäßig privat';

  @override
  String get accountSavedItems => 'Gespeicherte Elemente';

  @override
  String get accountViewBookmarkedEvents => 'Gespeicherte Events anzeigen';

  @override
  String get accountPrivacy => 'Datenschutz';

  @override
  String get accountAnonymousComments => 'Anonyme Kommentare';

  @override
  String get accountAnonymousModeOn => 'Ihr Name erscheint als \"Anonym\"';

  @override
  String get accountAnonymousModeOff =>
      'Ihr Name wird bei Kommentaren angezeigt';

  @override
  String get accountHideProfile => 'Profil verbergen';

  @override
  String get accountHideProfileOn =>
      'Andere können keine neuen Gespräche mit Ihnen starten';

  @override
  String get accountHideProfileOff =>
      'Jeder kann ein Gespräch mit Ihnen starten';

  @override
  String get accountNotifications => 'Benachrichtigungen';

  @override
  String get accountMuteNotifications =>
      'Nachrichtenklänge & Vibration stummschalten';

  @override
  String get accountMutedOn => 'Nachrichten kommen lautlos an';

  @override
  String get accountMutedOff =>
      'Sie spüren eine Vibration bei neuen Nachrichten';

  @override
  String get chatRoomsTitle => 'Nachrichten';

  @override
  String get chatRoomsGlobalChat => 'Globaler Chat';

  @override
  String get chatRoomsNewGroup => 'Neue Gruppe';

  @override
  String get chatRoomsNoConversations => 'Noch keine Gespräche.';

  @override
  String get chatRoomsJoinGlobalChat => 'Globalem Chat beitreten';

  @override
  String get chatRoomsPendingInvites => 'Ausstehende Einladungen';

  @override
  String get chatRoomsChats => 'Chats';

  @override
  String get chatRoomsYouWereInvited => 'Sie wurden eingeladen beizutreten';

  @override
  String get chatRoomsJoin => 'Beitreten';

  @override
  String get chatRoomsDecline => 'Ablehnen';

  @override
  String get chatRoomConnecting => 'Verbinden…';

  @override
  String get chatRoomDisconnected => 'Getrennt';

  @override
  String get chatRoomEndToEndEncrypted => 'Ende-zu-Ende-verschlüsselt';

  @override
  String get chatRoomNoMessages => 'Noch keine Nachrichten.\nSagen Sie Hallo!';

  @override
  String get chatRoomOnlyAdminsCanSend =>
      'Nur Admins können Nachrichten senden';

  @override
  String get chatRoomAddPeople => 'Personen hinzufügen';

  @override
  String get chatRoomEditMessage => 'Nachricht bearbeiten';

  @override
  String get chatRoomEditYourMessage => 'Nachricht bearbeiten…';

  @override
  String get chatRoomCancel => 'Abbrechen';

  @override
  String get chatRoomSave => 'Speichern';

  @override
  String get chatRoomDeleteMessage => 'Nachricht löschen';

  @override
  String get chatRoomDeleteForEveryone =>
      'Diese Nachricht wird für alle gelöscht.';

  @override
  String get chatRoomDelete => 'Löschen';

  @override
  String get chatRoomReply => 'Antworten';

  @override
  String get chatRoomEdit => 'Bearbeiten';

  @override
  String get chatRoomMessageDirectly => 'Direkt anschreiben';

  @override
  String get chatRoomNotAcceptingMessages =>
      'Dieser Nutzer akzeptiert keine Nachrichten.';

  @override
  String chatRoomCouldNotOpenChat(String error) {
    return 'Chat konnte nicht geöffnet werden: $error';
  }

  @override
  String chatRoomInvitedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Personen eingeladen',
      one: '1 Person eingeladen',
    );
    return '$_temp0';
  }

  @override
  String get chatRoomEncryptedMessage => 'Verschlüsselte Nachricht';

  @override
  String get chatRoomEdited => 'bearbeitet';

  @override
  String get chatRoomTypeSubtitleGlobal => 'Alle';

  @override
  String get chatRoomTypeSubtitleDirect => 'Direktnachricht';

  @override
  String get chatRoomTypeSubtitleEvent => 'Event-Diskussion';

  @override
  String get chatRoomTypeSubtitleEventPrivate => 'Privater Event-Raum';

  @override
  String get chatRoomTypeSubtitlePhoto => 'Fotokommentare';

  @override
  String get chatRoomTypeSubtitleSample => 'Beispielbild-Chat';

  @override
  String chatRoomTypeSubtitleGroupMembers(int count) {
    return '$count Mitglieder';
  }

  @override
  String get chatRoomTypeSubtitleGroupChat => 'Gruppenchat';

  @override
  String get chatRoomTypeSubtitleChatRoom => 'Chatroom';

  @override
  String get chatRoomTimeYesterday => 'Gestern';

  @override
  String get groupInfoTitle => 'Gruppeninfo';

  @override
  String get groupInfoNoData => 'Keine Gruppendaten.';

  @override
  String get groupInfoGroupLabel => 'Gruppe';

  @override
  String groupInfoParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Teilnehmer',
      one: '1 Teilnehmer',
    );
    return '$_temp0';
  }

  @override
  String get groupInfoOnlyAdminsCanSend =>
      'Nur Admins können Nachrichten senden';

  @override
  String get groupInfoAdminOnlySubtitleOn =>
      'Nur Admins können in dieser Gruppe Nachrichten senden.';

  @override
  String get groupInfoAdminOnlySubtitleOff =>
      'Alle Mitglieder können Nachrichten senden.';

  @override
  String get groupInfoAdminBadge => 'Admin';

  @override
  String get groupInfoYou => '(Sie)';

  @override
  String get groupInfoMakeAdmin => 'Zum Gruppenadmin machen';

  @override
  String get groupInfoRemoveAdmin => 'Als Admin entfernen';

  @override
  String get groupInfoRemoveFromGroup => 'Aus Gruppe entfernen';

  @override
  String get inviteToGroupTitle => 'Personen hinzufügen';

  @override
  String get inviteToGroupInvite => 'Einladen';

  @override
  String get inviteToGroupSearchPeople => 'Personen suchen...';

  @override
  String get inviteToGroupNoUsersFound => 'Keine Nutzer gefunden.';

  @override
  String get inviteToGroupSearchForPeople =>
      'Nach Personen suchen, die hinzugefügt werden sollen.';

  @override
  String inviteToGroupCouldNotInvite(String names) {
    return 'Einladung fehlgeschlagen: $names';
  }

  @override
  String get createGroupTitle => 'Neue Gruppe';

  @override
  String get createGroupCreate => 'Erstellen';

  @override
  String get createGroupNameHint => 'Gruppenname';

  @override
  String get createGroupNameRequired => 'Gruppenname ist erforderlich.';

  @override
  String get createGroupSearchPeople => 'Personen zum Hinzufügen suchen...';

  @override
  String get createGroupNoUsersFound => 'Keine Nutzer gefunden.';

  @override
  String get createGroupCouldNotCreate =>
      'Gruppe konnte nicht erstellt werden. Bitte erneut versuchen.';
}
