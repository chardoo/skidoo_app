part of 'login_bloc.dart';

class LoginState extends Equatable {
  final bool isLoading;
  final bool isPasswordHidden;
  final String? errorMessage;
  final bool isSuccess;
  final bool needsInterests;

  const LoginState({
    this.isLoading = false,
    this.isPasswordHidden = true,
    this.errorMessage,
    this.isSuccess = false,
    this.needsInterests = false,
  });

  LoginState copyWith({
    bool? isLoading,
    bool? isPasswordHidden,
    String? errorMessage,
    bool? isSuccess,
    bool? needsInterests,
    bool clearError = false,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      isPasswordHidden: isPasswordHidden ?? this.isPasswordHidden,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      needsInterests: needsInterests ?? this.needsInterests,
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, isPasswordHidden, errorMessage, isSuccess, needsInterests];
}
