import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

class SetPendingInterestsUseCase {
  final AuthRepository _repository;
  SetPendingInterestsUseCase(this._repository);
  Future<void> call() => _repository.setPendingInterests();
}

class GetPendingInterestsUseCase {
  final AuthRepository _repository;
  GetPendingInterestsUseCase(this._repository);
  Future<bool> call() => _repository.isPendingInterests();
}

class ClearPendingInterestsUseCase {
  final AuthRepository _repository;
  ClearPendingInterestsUseCase(this._repository);
  Future<void> call() => _repository.clearPendingInterests();
}
