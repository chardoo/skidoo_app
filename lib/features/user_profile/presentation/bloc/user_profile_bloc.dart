import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/user_profile/domain/usecases/get_profile_usecase.dart';
import 'package:skidoo_app/services/notification_prefs_service.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UserLogoutUseCase _logoutUseCase;
  final NotificationPrefsService _notifPrefs;

  UserProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UserLogoutUseCase logoutUseCase,
    required NotificationPrefsService notificationPrefsService,
  })  : _getProfileUseCase = getProfileUseCase,
        _logoutUseCase = logoutUseCase,
        _notifPrefs = notificationPrefsService,
        super(const UserProfileState()) {
    on<UserProfileLoadRequested>(_onLoadRequested);
    on<UserLogoutRequested>(_onLogoutRequested);
    on<NotificationsMuteToggled>(_onMuteToggled);
    on<PublicImagesToggled>(_onPublicImagesToggled);
  }

  Future<void> _onLoadRequested(
      UserProfileLoadRequested event, Emitter<UserProfileState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final profile = await _getProfileUseCase(const NoParams());
      emit(state.copyWith(
        isLoading: false,
        name: profile['name'] ?? '',
        email: profile['email'] ?? '',
        isMuted: _notifPrefs.isMuted,
        alwaysPublicImages: _notifPrefs.alwaysPublicImages,
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
    await _notifPrefs.setMuted(event.isMuted);
    emit(state.copyWith(isMuted: event.isMuted));
  }

  Future<void> _onPublicImagesToggled(
      PublicImagesToggled event, Emitter<UserProfileState> emit) async {
    await _notifPrefs.setAlwaysPublicImages(event.alwaysPublic);
    emit(state.copyWith(alwaysPublicImages: event.alwaysPublic));
  }
}
