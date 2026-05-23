part of 'signup_bloc.dart';

class SignUpState extends Equatable {
  final bool isLoading;
  final String imagePath;
  final String? errorMessage;
  final bool isSuccess;

  const SignUpState({
    this.isLoading = false,
    this.imagePath = '',
    this.errorMessage,
    this.isSuccess = false,
  });

  SignUpState copyWith({
    bool? isLoading,
    String? imagePath,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return SignUpState(
      isLoading: isLoading ?? this.isLoading,
      imagePath: imagePath ?? this.imagePath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [isLoading, imagePath, errorMessage, isSuccess];
}
