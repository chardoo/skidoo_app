import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';

/// Verifies the 6-digit code emailed after sign-up. On success the backend
/// returns a full session (same shape as login), so this reuses
/// [LoginUseCase.establishSession] for identical session bring-up.
class VerifyCodeUseCase implements UseCase<LoginResponseObject, VerifyCodeParams> {
  final AuthRepository _repository;
  final LoginUseCase _loginUseCase;
  VerifyCodeUseCase(this._repository, this._loginUseCase);

  @override
  Future<LoginResponseObject> call(VerifyCodeParams params) async {
    final user = await _repository.verifyCode({
      'email': params.email,
      'code': params.code,
    });
    await _loginUseCase.establishSession(user);
    return user;
  }
}

class VerifyCodeParams extends Equatable {
  final String email;
  final String code;
  const VerifyCodeParams({required this.email, required this.code});

  @override
  List<Object?> get props => [email, code];
}
