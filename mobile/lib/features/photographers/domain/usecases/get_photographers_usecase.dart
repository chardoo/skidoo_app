import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';

class GetPhotographersUseCase
    implements UseCase<List<PhotographerModel>, NoParams> {
  final PhotographerRepository _repository;
  GetPhotographersUseCase(this._repository);

  @override
  Future<List<PhotographerModel>> call(NoParams params) =>
      _repository.getPhotographers();
}
