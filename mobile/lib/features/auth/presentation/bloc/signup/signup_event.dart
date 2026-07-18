part of 'signup_bloc.dart';

abstract class SignUpEvent extends Equatable {
  const SignUpEvent();
  @override
  List<Object?> get props => [];
}

class SignUpSubmitted extends SignUpEvent {
  final String email;
  final String password;
  final String contact;
  final String userName;

  const SignUpSubmitted({
    required this.email,
    required this.password,
    required this.contact,
    required this.userName,
  });

  @override
  List<Object?> get props => [email, password, contact, userName];
}

class SignUpErrorCleared extends SignUpEvent {
  const SignUpErrorCleared();
}
