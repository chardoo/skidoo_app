import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/pending_interests_usecases.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;
  final GetPendingInterestsUseCase _getPendingInterests;

  LoginBloc({
    required LoginUseCase loginUseCase,
    required GetPendingInterestsUseCase getPendingInterests,
  })  : _loginUseCase = loginUseCase,
        _getPendingInterests = getPendingInterests,
        super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginPasswordVisibilityToggled>(_onPasswordToggled);
    on<LoginErrorCleared>(_onErrorCleared);
  }

  Future<void> _onLoginSubmitted(
      LoginSubmitted event, Emitter<LoginState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _loginUseCase(
          LoginParams(email: event.email, password: event.password));
      final needsInterests = await _getPendingInterests();
      emit(state.copyWith(
          isLoading: false, isSuccess: true, needsInterests: needsInterests));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on UnauthorizedException {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Invalid credentials.'));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'An unexpected error occurred.'));
    }
  }

  void _onPasswordToggled(
      LoginPasswordVisibilityToggled event, Emitter<LoginState> emit) {
    emit(state.copyWith(isPasswordHidden: !state.isPasswordHidden));
  }

  void _onErrorCleared(LoginErrorCleared event, Emitter<LoginState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
