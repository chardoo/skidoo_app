part of 'signup_bloc.dart';

class SignUpState extends Equatable {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String email;

  /// The account already exists and was never verified — the backend has
  /// re-sent its code. The screen resumes verification rather than reporting
  /// a failure; [email] is the address to verify (which may differ in case or
  /// whitespace from what was typed, so it comes back from the server).
  final bool needsEmailVerification;

  /// The account already exists and is ready to use. Carries the message the
  /// server wrote, because it says *which* field collided — the email or the
  /// phone number — and the screen should not have to guess.
  final String? existingAccountMessage;

  const SignUpState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.email = '',
    this.needsEmailVerification = false,
    this.existingAccountMessage,
  });

  SignUpState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    String? email,
    bool? needsEmailVerification,
    String? existingAccountMessage,
    bool clearError = false,
  }) {
    return SignUpState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      email: email ?? this.email,
      needsEmailVerification:
          needsEmailVerification ?? this.needsEmailVerification,
      existingAccountMessage: clearError
          ? null
          : (existingAccountMessage ?? this.existingAccountMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        isSuccess,
        email,
        needsEmailVerification,
        existingAccountMessage,
      ];
}
