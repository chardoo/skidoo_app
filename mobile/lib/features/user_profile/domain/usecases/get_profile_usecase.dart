import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetProfileUseCase implements UseCase<Map<String, dynamic>, NoParams> {
  final UserProfileRepository _repository;
  GetProfileUseCase(this._repository);

  @override
  Future<Map<String, dynamic>> call(NoParams params) =>
      _repository.getFullProfile();
}

class UserLogoutUseCase implements UseCase<void, NoParams> {
  final UserProfileRepository _repository;
  UserLogoutUseCase(this._repository);

  @override
  Future<void> call(NoParams params) => _repository.logout();
}
