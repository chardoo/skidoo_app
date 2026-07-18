part of 'signup_bloc.dart';

class SignUpState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String email;

  const SignUpState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.email = '',
  });

  SignUpState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? email,
    bool clearError = false,
  }) {
    return SignUpState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [isLoading, errorMessage, isSuccess, email];
}
