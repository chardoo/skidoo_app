import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';

class UpdateProfileUseCase implements UseCase<void, UpdateProfileParams> {
  final AuthRepository _repository;
  UpdateProfileUseCase(this._repository);

  @override
  Future<void> call(UpdateProfileParams params) async {
    await _repository.updateProfile(params.clientId, params.data);
  }
}

class UpdateProfileParams extends Equatable {
  final String clientId;
  final Map<String, dynamic> data;
  const UpdateProfileParams({required this.clientId, required this.data});

  @override
  List<Object?> get props => [clientId, data];
}
