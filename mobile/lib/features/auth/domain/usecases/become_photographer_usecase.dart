import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';

/// Upgrades the signed-in account to a photographer — `POST
/// /photographer/become` (authenticated, no body per backend notes).
/// Endpoint/response shape unconfirmed against the real backend; any 2xx is
/// treated as success and the caller persists the new role locally via
/// `AuthService.setRole('photographer')`.
class BecomePhotographerUseCase implements UseCase<void, NoParams> {
  final AuthRepository _repository;
  BecomePhotographerUseCase(this._repository);

  @override
  Future<void> call(NoParams params) => _repository.becomePhotographer();
}
