part of 'login_bloc.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;
  const LoginSubmitted({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled();
}

class LoginErrorCleared extends LoginEvent {
  const LoginErrorCleared();
}

/// Dispatched by the page right after it navigates to EmailVerificationPage,
/// so a later state change can't re-trigger that navigation.
class LoginEmailVerificationHandled extends LoginEvent {
  const LoginEmailVerificationHandled();
}
