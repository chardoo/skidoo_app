import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

/// Step 3 of password reset — re-checks email+code, hashes the new
/// password, and clears the code server-side (one-time use). Does not sign
/// the user in; they log in fresh afterward with the new password.
class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  final AuthRepository _repository;
  ResetPasswordUseCase(this._repository);

  @override
  Future<void> call(ResetPasswordParams params) => _repository.resetPassword(
        params.email,
        params.code,
        params.password,
      );
}

class ResetPasswordParams extends Equatable {
  final String email;
  final String code;
  final String password;
  const ResetPasswordParams({
    required this.email,
    required this.code,
    required this.password,
  });

  @override
  List<Object?> get props => [email, code, password];
}
