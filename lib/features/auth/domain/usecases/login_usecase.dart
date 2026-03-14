import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';

class LoginUseCase implements UseCase<LoginResponseObject, LoginParams> {
  final AuthRepository _repository;
  LoginUseCase(this._repository);

  @override
  Future<LoginResponseObject> call(LoginParams params) async {
    final user = await _repository.login(params.email, params.password);
    await _repository.saveUserSession(user);
    return user;
  }
}

class LoginParams extends Equatable {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
