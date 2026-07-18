import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:skidoo_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:skidoo_app/features/auth/domain/usecases/resend_verification_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase _loginUseCase;
  final GetPendingInterestsUseCase _getPendingInterests;
  final ResendVerificationUseCase _resendVerification;

  LoginBloc({
    required LoginUseCase loginUseCase,
    required GetPendingInterestsUseCase getPendingInterests,
    required ResendVerificationUseCase resendVerification,
  })  : _loginUseCase = loginUseCase,
        _getPendingInterests = getPendingInterests,
        _resendVerification = resendVerification,
        super(const LoginState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoginPasswordVisibilityToggled>(_onPasswordToggled);
    on<LoginErrorCleared>(_onErrorCleared);
    on<LoginEmailVerificationHandled>(_onEmailVerificationHandled);
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
    } on EmailNotVerifiedException {
      // The account exists and the password is correct — the backend just
      // won't issue a session until the email is verified. Send a fresh
      // code and let the UI drop into the same OTP -> face-capture ->
      // preference wizard a fresh sign-up goes through.
      try {
        await _resendVerification(event.email);
      } catch (_) {
        // Non-blocking — the OTP screen's own "resend" link covers this.
      }
      emit(state.copyWith(isLoading: false, needsEmailVerification: true));
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

  void _onEmailVerificationHandled(
      LoginEmailVerificationHandled event, Emitter<LoginState> emit) {
    emit(state.copyWith(needsEmailVerification: false));
  }
}
