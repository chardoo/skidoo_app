import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';

class GetTokenUseCase implements UseCase<String, NoParams> {
  final AuthRepository _repository;
  GetTokenUseCase(this._repository);

  @override
  Future<String> call(NoParams params) => _repository.getToken();
}

class LogoutUseCase implements UseCase<void, NoParams> {
  final AuthRepository _repository;
  LogoutUseCase(this._repository);

  @override
  Future<void> call(NoParams params) => _repository.logout();
}
