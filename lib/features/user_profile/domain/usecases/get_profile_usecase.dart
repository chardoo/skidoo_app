import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetProfileUseCase implements UseCase<Map<String, String>, NoParams> {
  final UserProfileRepository _repository;
  GetProfileUseCase(this._repository);

  @override
  Future<Map<String, String>> call(NoParams params) async {
    final name = await _repository.getName();
    final email = await _repository.getEmail();
    return {'name': name, 'email': email};
  }
}

class UserLogoutUseCase implements UseCase<void, NoParams> {
  final UserProfileRepository _repository;
  UserLogoutUseCase(this._repository);

  @override
  Future<void> call(NoParams params) => _repository.logout();
}
