import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/domain/usecases/register_usecase.dart';

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
}
