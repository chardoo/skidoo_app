import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

/// Step 1 of password reset — sends a fresh 6-digit code to [email] via
/// email + SMS. Always regenerates the code; no cooldown (explicit user
/// action, unlike the login-retry auto-resend).
class RequestPasswordResetUseCase implements UseCase<void, String> {
  final AuthRepository _repository;
  RequestPasswordResetUseCase(this._repository);

  @override
  Future<void> call(String email) => _repository.requestPasswordReset(email);
}
