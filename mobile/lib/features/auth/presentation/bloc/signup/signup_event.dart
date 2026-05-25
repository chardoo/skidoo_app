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
  final String imagePath;

  const SignUpSubmitted({
    required this.email,
    required this.password,
    required this.contact,
    required this.userName,
    required this.imagePath,
  });

  @override
  List<Object?> get props => [email, password, contact, userName, imagePath];
}

class SignUpFaceImageCaptured extends SignUpEvent {
  final String imagePath;
  final XFile xFile;
  const SignUpFaceImageCaptured(this.imagePath, this.xFile);
  @override
  List<Object?> get props => [imagePath];
}

class SignUpErrorCleared extends SignUpEvent {
  const SignUpErrorCleared();
}
