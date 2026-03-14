import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/user_profile/domain/usecases/get_profile_usecase.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UserLogoutUseCase _logoutUseCase;

  UserProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UserLogoutUseCase logoutUseCase,
  })  : _getProfileUseCase = getProfileUseCase,
        _logoutUseCase = logoutUseCase,
        super(const UserProfileState()) {
    on<UserProfileLoadRequested>(_onLoadRequested);
    on<UserLogoutRequested>(_onLogoutRequested);
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
}
