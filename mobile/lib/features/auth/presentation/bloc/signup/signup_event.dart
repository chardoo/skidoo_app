part of 'signup_bloc.dart';

abstract class SignUpEvent extends Equatable {
  const SignUpEvent();
  @override
  List<Object?> get props => [];
}

/// Signing up carries no phone number.
///
/// It used to, as a required field. App Store review refused the app under
/// guideline 5.1.1(v) — an app may not require personal information its core
/// function does not need — and nothing in this one needs it: sign-in is by
/// email, every verification code goes to the email address, and the single
/// SMS an account can trigger already checks whether a number exists first.
///
/// Dropped from the event rather than left here as an optional field, so there
/// is nothing for a later screen to start filling in again by accident. The
/// number is collected in Settings ▸ Edit Profile, where it is a real choice.
class SignUpSubmitted extends SignUpEvent {
  final String email;
  final String password;
  final String name;

  const SignUpSubmitted({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object?> get props => [email, password, name];
}

class SignUpErrorCleared extends SignUpEvent {
  const SignUpErrorCleared();
}

/// The screen has navigated to the verification step, so the flag that sent it
/// there must come down before a later, unrelated rebuild acts on it again.
class SignUpEmailVerificationHandled extends SignUpEvent {
  const SignUpEmailVerificationHandled();
}
