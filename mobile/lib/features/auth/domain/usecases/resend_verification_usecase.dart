import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

class ResendVerificationUseCase implements UseCase<void, String> {
  final AuthRepository _repository;
  ResendVerificationUseCase(this._repository);

  @override
  Future<void> call(String email) => _repository.resendVerification(email);
}
