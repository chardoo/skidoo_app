import 'package:cross_file/cross_file.dart';
import 'package:skidoo_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';

class GetPhotographerSamplesUseCase {
  final PhotographerRepository _repository;
  GetPhotographerSamplesUseCase(this._repository);

  Future<List<PhotographerSample>> call(String photographerId) =>
      _repository.getSamples(photographerId);
}

class UploadSamplesUseCase {
  final PhotographerRepository _repository;
  UploadSamplesUseCase(this._repository);

  Future<List<PhotographerSample>> call({
    required String photographerId,
    required List<XFile> files,
  }) =>
      _repository.uploadSamples(photographerId: photographerId, files: files);
}

class DeleteSampleUseCase {
  final PhotographerRepository _repository;
  DeleteSampleUseCase(this._repository);

  Future<void> call({
    required String sampleId,
    required String photographerId,
  }) =>
      _repository.deleteSample(sampleId: sampleId, photographerId: photographerId);
}
