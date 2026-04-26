part of 'user_profile_bloc.dart';

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();
  @override
  List<Object?> get props => [];
}

class UserProfileLoadRequested extends UserProfileEvent {
  const UserProfileLoadRequested();
}

class UserLogoutRequested extends UserProfileEvent {
  const UserLogoutRequested();
}

class NotificationsMuteToggled extends UserProfileEvent {
  final bool isMuted;
  const NotificationsMuteToggled(this.isMuted);
  @override
  List<Object?> get props => [isMuted];
}

class PublicImagesToggled extends UserProfileEvent {
  final bool alwaysPublic;
  const PublicImagesToggled(this.alwaysPublic);
  @override
  List<Object?> get props => [alwaysPublic];
}

class ProfileUpdateSubmitted extends UserProfileEvent {
  final String name;
  final String uniqueName;
  final String contact;
  final String countryCode;
  final String locale;
  final String preferredLanguage;
  final String timezone;
  final List<String> interestTags;

  const ProfileUpdateSubmitted({
    required this.name,
    required this.uniqueName,
    required this.contact,
    required this.countryCode,
    required this.locale,
    required this.preferredLanguage,
    required this.timezone,
    required this.interestTags,
  });

  @override
  List<Object?> get props => [
        name, uniqueName, contact, countryCode,
        locale, preferredLanguage, timezone, interestTags,
      ];
}
