import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/domain/usecases/register_usecase.dart';

part 'signup_event.dart';
part 'signup_state.dart';

class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  final RegisterUseCase _registerUseCase;

  SignUpBloc({required RegisterUseCase registerUseCase})
      : _registerUseCase = registerUseCase,
        super(const SignUpState()) {
    on<SignUpSubmitted>(_onSignUpSubmitted);
    on<SignUpFaceImageCaptured>(_onFaceImageCaptured);
    on<SignUpErrorCleared>(_onErrorCleared);
  }

  Future<void> _onSignUpSubmitted(
      SignUpSubmitted event, Emitter<SignUpState> emit) async {
    if (event.imagePath.isEmpty) {
      emit(state.copyWith(
          errorMessage: 'Please capture your face photo first.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final fields = {
        'email': event.email,
        'password': event.password,
        'contact': event.contact,
        'name': event.userName.isNotEmpty ? event.userName : 'user',
      };
      await _registerUseCase(
          RegisterParams(fields: fields, image: File(event.imagePath)));
      emit(state.copyWith(isLoading: false, isSuccess: true));
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

  void _onFaceImageCaptured(
      SignUpFaceImageCaptured event, Emitter<SignUpState> emit) {
    emit(state.copyWith(imagePath: event.imagePath));
  }

  void _onErrorCleared(SignUpErrorCleared event, Emitter<SignUpState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
