import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/auth/domain/usecases/register_usecase.dart';

part 'signup_event.dart';
part 'signup_state.dart';

/// Face capture and the "what best describes you" preference are separate
/// steps later in onboarding — this bloc only creates the (unverified)
/// account. Email OTP verification after this logs the user in for real.
class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  final RegisterUseCase _registerUseCase;

  SignUpBloc({
    required RegisterUseCase registerUseCase,
  })  : _registerUseCase = registerUseCase,
        super(const SignUpState()) {
    on<SignUpSubmitted>(_onSignUpSubmitted);
    on<SignUpErrorCleared>(_onErrorCleared);
    on<SignUpEmailVerificationHandled>(_onEmailVerificationHandled);
  }

  Future<void> _onSignUpSubmitted(
      SignUpSubmitted event, Emitter<SignUpState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final fields = {
        'email': event.email,
        'password': event.password,
        'contact': event.contact,
        'name': event.userName.isNotEmpty ? event.userName : 'user',
      };
      await _registerUseCase(RegisterParams(fields: fields));
      emit(state.copyWith(
          isLoading: false, isSuccess: true, email: event.email));
    } on AccountExistsUnverifiedException catch (e) {
      // Signing up over an account that never verified is how somebody says
      // "the first code never arrived". The backend has already sent another
      // one, so this is not a failure — it is the same wizard, resumed at the
      // step it stopped at.
      emit(state.copyWith(
        isLoading: false,
        email: e.email,
        needsEmailVerification: true,
      ));
    } on AccountExistsException catch (e) {
      // Kept out of errorMessage so the screen can tell the two apart: this
      // one gets a banner with a "Log in" button, a plain error does not.
      emit(state.copyWith(
          isLoading: false, existingAccountMessage: e.message));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Registration failed. Please try again.'));
    }
  }

  void _onErrorCleared(SignUpErrorCleared event, Emitter<SignUpState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onEmailVerificationHandled(
      SignUpEmailVerificationHandled event, Emitter<SignUpState> emit) {
    emit(state.copyWith(needsEmailVerification: false));
  }
}
