import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';

/// Step 2 (optional) of password reset — validates the code without
/// consuming it, so the UI can confirm it before showing the new-password
/// screen. Skippable server-side (change-password re-checks it anyway), but
/// kept as a real step here to catch a mistyped code early.
class VerifyResetCodeUseCase implements UseCase<void, VerifyResetCodeParams> {
  final AuthRepository _repository;
  VerifyResetCodeUseCase(this._repository);

  @override
  Future<void> call(VerifyResetCodeParams params) =>
      _repository.verifyResetCode(params.email, params.code);
}

class VerifyResetCodeParams extends Equatable {
  final String email;
  final String code;
  const VerifyResetCodeParams({required this.email, required this.code});

  @override
  List<Object?> get props => [email, code];
}
