import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:skidoo_app/features/auth/domain/usecases/register_usecase.dart';

part 'signup_event.dart';
part 'signup_state.dart';

class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  final RegisterUseCase _registerUseCase;
  final SetPendingInterestsUseCase _setPendingInterests;

  // Held outside state — only needed when submitting, not for UI diffing.
  XFile? _capturedXFile;

  SignUpBloc({
    required RegisterUseCase registerUseCase,
    required SetPendingInterestsUseCase setPendingInterests,
  })  : _registerUseCase = registerUseCase,
        _setPendingInterests = setPendingInterests,
        super(const SignUpState()) {
    on<SignUpSubmitted>(_onSignUpSubmitted);
    on<SignUpFaceImageCaptured>(_onFaceImageCaptured);
    on<SignUpErrorCleared>(_onErrorCleared);
  }

  Future<void> _onSignUpSubmitted(
      SignUpSubmitted event, Emitter<SignUpState> emit) async {
    if (event.imagePath.isEmpty || _capturedXFile == null) {
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
      final imageBytes = await _capturedXFile!.readAsBytes();
      final filename = _capturedXFile!.name.isNotEmpty
          ? _capturedXFile!.name
          : 'selfie.jpg';
      await _registerUseCase(RegisterParams(
        fields: fields,
        imageBytes: imageBytes,
        imageFilename: filename,
      ));
      await _setPendingInterests();
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
    _capturedXFile = event.xFile;
    emit(state.copyWith(imagePath: event.imagePath));
  }

  void _onErrorCleared(SignUpErrorCleared event, Emitter<SignUpState> emit) {
    emit(state.copyWith(clearError: true));
  }
}
