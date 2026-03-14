part of 'user_profile_bloc.dart';

class UserProfileState extends Equatable {
  final bool isLoading;
  final String name;
  final String email;
  final bool isLoggedOut;
  final String? errorMessage;

  const UserProfileState({
    this.isLoading = false,
    this.name = '',
    this.email = '',
    this.isLoggedOut = false,
    this.errorMessage,
  });

  UserProfileState copyWith({
    bool? isLoading,
    String? name,
    String? email,
    bool? isLoggedOut,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      name: name ?? this.name,
      email: email ?? this.email,
      isLoggedOut: isLoggedOut ?? this.isLoggedOut,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [isLoading, name, email, isLoggedOut, errorMessage];
}
