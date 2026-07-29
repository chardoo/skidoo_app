part of 'user_profile_bloc.dart';

class UserProfileState extends Equatable {
  final bool isLoading;
  final bool isUpdateLoading;
  final bool isUpdateSuccess;
  final String name;
  final String email;
  final String uniqueName;
  final String contact;
  final String countryCode;
  final String locale;
  final String preferredLanguage;
  final String timezone;
  final List<String> interestTags;
  final bool isLoggedOut;
  final bool isMuted;
  final bool alwaysPublicImages;
  final bool anonymousMode;
  final bool hideProfile;
  final bool isAnonymousModeUpdating;
  final bool isHideProfileUpdating;
  final String? errorMessage;
  final String? updateErrorMessage;

  const UserProfileState({
    this.isLoading = false,
    this.isUpdateLoading = false,
    this.isUpdateSuccess = false,
    this.name = '',
    this.email = '',
    this.uniqueName = '',
    this.contact = '',
    this.countryCode = '',
    this.locale = '',
    this.preferredLanguage = '',
    this.timezone = '',
    this.interestTags = const [],
    this.isLoggedOut = false,
    this.isMuted = false,
    this.alwaysPublicImages = false,
    this.anonymousMode = false,
    this.hideProfile = false,
    this.isAnonymousModeUpdating = false,
    this.isHideProfileUpdating = false,
    this.errorMessage,
    this.updateErrorMessage,
  });

  UserProfileState copyWith({
    bool? isLoading,
    bool? isUpdateLoading,
    bool? isUpdateSuccess,
    String? name,
    String? email,
    String? uniqueName,
    String? contact,
    String? countryCode,
    String? locale,
    String? preferredLanguage,
    String? timezone,
    List<String>? interestTags,
    bool? isLoggedOut,
    bool? isMuted,
    bool? alwaysPublicImages,
    bool? anonymousMode,
    bool? hideProfile,
    bool? isAnonymousModeUpdating,
    bool? isHideProfileUpdating,
    String? errorMessage,
    String? updateErrorMessage,
    bool clearError = false,
    bool clearUpdateError = false,
    bool clearUpdateSuccess = false,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      isUpdateLoading: isUpdateLoading ?? this.isUpdateLoading,
      isUpdateSuccess: clearUpdateSuccess
          ? false
          : (isUpdateSuccess ?? this.isUpdateSuccess),
      name: name ?? this.name,
      email: email ?? this.email,
      uniqueName: uniqueName ?? this.uniqueName,
      contact: contact ?? this.contact,
      countryCode: countryCode ?? this.countryCode,
      locale: locale ?? this.locale,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      timezone: timezone ?? this.timezone,
      interestTags: interestTags ?? this.interestTags,
      isLoggedOut: isLoggedOut ?? this.isLoggedOut,
      isMuted: isMuted ?? this.isMuted,
      alwaysPublicImages: alwaysPublicImages ?? this.alwaysPublicImages,
      anonymousMode: anonymousMode ?? this.anonymousMode,
      hideProfile: hideProfile ?? this.hideProfile,
      isAnonymousModeUpdating:
          isAnonymousModeUpdating ?? this.isAnonymousModeUpdating,
      isHideProfileUpdating:
          isHideProfileUpdating ?? this.isHideProfileUpdating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      updateErrorMessage: clearUpdateError
          ? null
          : (updateErrorMessage ?? this.updateErrorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isUpdateLoading,
        isUpdateSuccess,
        name,
        email,
        uniqueName,
        contact,
        countryCode,
        locale,
        preferredLanguage,
        timezone,
        interestTags,
        isLoggedOut,
        isMuted,
        alwaysPublicImages,
        anonymousMode,
        hideProfile,
        isAnonymousModeUpdating,
        isHideProfileUpdating,
        errorMessage,
        updateErrorMessage,
      ];
}
