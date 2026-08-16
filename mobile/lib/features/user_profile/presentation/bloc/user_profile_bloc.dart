import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/error/exceptions.dart'
    show CacheException, ServerException;
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart'
    show GetFeaturesUseCase, SetAnonymousModeUseCase, SetHideProfileUseCase;
import 'package:jperg_app/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:jperg_app/features/user_profile/domain/usecases/get_profile_usecase.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/notification_prefs_service.dart';
import 'package:jperg_app/services/push_notification_service.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UserLogoutUseCase _logoutUseCase;
  final NotificationPrefsService _notifPrefs;
  final UpdateProfileUseCase _updateProfileUseCase;
  final UserProfileRepository _profileRepository;
  final AuthService _authService;
  final GetFeaturesUseCase _getFeatures;
  final SetAnonymousModeUseCase _setAnonymousMode;
  final SetHideProfileUseCase _setHideProfile;

  UserProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UserLogoutUseCase logoutUseCase,
    required NotificationPrefsService notificationPrefsService,
    required UpdateProfileUseCase updateProfileUseCase,
    required UserProfileRepository profileRepository,
    required AuthService authService,
    required GetFeaturesUseCase getFeatures,
    required SetAnonymousModeUseCase setAnonymousMode,
    required SetHideProfileUseCase setHideProfile,
  })  : _getProfileUseCase = getProfileUseCase,
        _logoutUseCase = logoutUseCase,
        _notifPrefs = notificationPrefsService,
        _updateProfileUseCase = updateProfileUseCase,
        _profileRepository = profileRepository,
        _authService = authService,
        _getFeatures = getFeatures,
        _setAnonymousMode = setAnonymousMode,
        _setHideProfile = setHideProfile,
        super(const UserProfileState()) {
    on<UserProfileLoadRequested>(_onLoadRequested);
    on<UserLogoutRequested>(_onLogoutRequested);
    on<NotificationsMuteToggled>(_onMuteToggled);
    on<PublicImagesToggled>(_onPublicImagesToggled);
    on<AnonymousModeToggled>(_onAnonymousModeToggled, transformer: droppable());
    on<HideProfileToggled>(_onHideProfileToggled, transformer: droppable());
    on<ProfileUpdateSubmitted>(_onProfileUpdateSubmitted);
  }

  Future<void> _onLoadRequested(
      UserProfileLoadRequested event, Emitter<UserProfileState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _getProfileUseCase(const NoParams()),
        _getFeatures().catchError((_) => <String, bool>{}),
      ]);
      final profile = results[0] as Map<dynamic, dynamic>;
      final features = results[1] as Map<String, bool>;
      emit(state.copyWith(
        isLoading: false,
        name: profile['name'] as String? ?? '',
        email: profile['email'] as String? ?? '',
        uniqueName: profile['uniqueName'] as String? ?? '',
        contact: profile['contact'] as String? ?? '',
        countryCode: profile['countryCode'] as String? ?? '',
        locale: profile['locale'] as String? ?? '',
        preferredLanguage: profile['preferredLanguage'] as String? ?? '',
        timezone: profile['timezone'] as String? ?? '',
        interestTags:
            List<String>.from((profile['interestTags'] as List?) ?? []),
        isMuted: _notifPrefs.isMuted,
        alwaysPublicImages: _notifPrefs.alwaysPublicImages,
        anonymousMode: features['anonymous_comments'] ?? state.anonymousMode,
        hideProfile: features['hide_profile'] ?? state.hideProfile,
      ));
    } on CacheException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Failed to load profile.'));
    }
  }

  Future<void> _onLogoutRequested(
      UserLogoutRequested event, Emitter<UserProfileState> emit) async {
    try {
      await _logoutUseCase(const NoParams());
      emit(state.copyWith(isLoggedOut: true));
    } on CacheException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Logout failed. Please try again.'));
    }
  }

  Future<void> _onMuteToggled(
      NotificationsMuteToggled event, Emitter<UserProfileState> emit) async {
    // Un-muting is someone asking for notifications, so the OS has to be asked
    // too — storing the preference alone left the switch reading "on" for an
    // app the system would not let post anything. Muting needs no permission.
    if (!event.isMuted) {
      final allowed = await PushNotificationService.instance.ensurePermission();
      if (!allowed) {
        // Left muted, because the system says so. The dialog has either just
        // been declined or was already spent, in which case requestPermission
        // opened system settings instead.
        emit(state.copyWith(
          isMuted: true,
          errorMessage: 'Notifications are turned off for Jperg in your device '
              'settings. Allow them there to switch this on.',
        ));
        return;
      }
    }
    await _notifPrefs.setMuted(event.isMuted);
    emit(state.copyWith(isMuted: event.isMuted));
  }

  Future<void> _onPublicImagesToggled(
      PublicImagesToggled event, Emitter<UserProfileState> emit) async {
    await _notifPrefs.setAlwaysPublicImages(event.alwaysPublic);
    emit(state.copyWith(alwaysPublicImages: event.alwaysPublic));
  }

  Future<void> _onAnonymousModeToggled(
      AnonymousModeToggled event, Emitter<UserProfileState> emit) async {
    emit(state.copyWith(
      anonymousMode: event.value,
      isAnonymousModeUpdating: true,
      clearError: true,
    ));
    try {
      await _setAnonymousMode(event.value);
      emit(state.copyWith(isAnonymousModeUpdating: false));
    } catch (_) {
      emit(state.copyWith(
        anonymousMode: !event.value,
        isAnonymousModeUpdating: false,
        errorMessage: 'accountAnonymousModeUpdateFailed',
      ));
    }
  }

  Future<void> _onHideProfileToggled(
      HideProfileToggled event, Emitter<UserProfileState> emit) async {
    emit(state.copyWith(
      hideProfile: event.value,
      isHideProfileUpdating: true,
      clearError: true,
    ));
    try {
      await _setHideProfile(event.value);
      emit(state.copyWith(isHideProfileUpdating: false));
    } catch (_) {
      emit(state.copyWith(
        hideProfile: !event.value,
        isHideProfileUpdating: false,
        errorMessage: 'accountHideProfileUpdateFailed',
      ));
    }
  }

  Future<void> _onProfileUpdateSubmitted(
      ProfileUpdateSubmitted event, Emitter<UserProfileState> emit) async {
    emit(state.copyWith(
        isUpdateLoading: true,
        clearUpdateError: true,
        clearUpdateSuccess: true));
    try {
      final clientId = await _authService.getUserId();

      // Build server payload using backend field names
      final serverData = <String, dynamic>{};
      if (event.name.isNotEmpty) serverData['name'] = event.name;
      if (event.uniqueName.isNotEmpty)
        serverData['uiqueName'] = event.uniqueName;
      if (event.contact.isNotEmpty) serverData['contact'] = event.contact;
      if (event.countryCode.isNotEmpty)
        serverData['country_code'] = event.countryCode;
      if (event.locale.isNotEmpty) serverData['locale'] = event.locale;
      if (event.preferredLanguage.isNotEmpty)
        serverData['preferred_language'] = event.preferredLanguage;
      if (event.timezone.isNotEmpty) serverData['timezone'] = event.timezone;
      if (event.interestTags.isNotEmpty)
        serverData['interest_tags'] = event.interestTags;

      await _updateProfileUseCase(
          UpdateProfileParams(clientId: clientId, data: serverData));

      // Persist the updated values locally
      await _profileRepository.updateLocalProfile({
        'name': event.name,
        'uniqueName': event.uniqueName,
        'contact': event.contact,
        'countryCode': event.countryCode,
        'locale': event.locale,
        'preferredLanguage': event.preferredLanguage,
        'timezone': event.timezone,
        'interestTags': event.interestTags,
      });

      emit(state.copyWith(
        isUpdateLoading: false,
        isUpdateSuccess: true,
        name: event.name.isNotEmpty ? event.name : state.name,
        uniqueName: event.uniqueName,
        contact: event.contact,
        countryCode: event.countryCode,
        locale: event.locale,
        preferredLanguage: event.preferredLanguage,
        timezone: event.timezone,
        interestTags: event.interestTags,
      ));
    } on ServerException catch (e) {
      emit(state.copyWith(
          isUpdateLoading: false, updateErrorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isUpdateLoading: false,
          updateErrorMessage: 'Profile update failed. Please try again.'));
    }
  }
}
