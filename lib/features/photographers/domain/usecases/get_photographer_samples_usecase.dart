import 'package:skidoo_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';

class GetPhotographerSamplesUseCase {
  final PhotographerRepository _repository;
  GetPhotographerSamplesUseCase(this._repository);

  Future<List<PhotographerSample>> call(String photographerId) =>
      _repository.getSamples(photographerId);
}
