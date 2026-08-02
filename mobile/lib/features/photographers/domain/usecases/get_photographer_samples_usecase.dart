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

  /// Files per upload.
  ///
  /// `PUT /photographer/samples` uploads to Cloudinary concurrently, eight at a
  /// time, so a batch of eight costs about what its slowest photo costs. Past
  /// that the ninth photo waits for a free slot and the request grows by a
  /// whole round of uploads.
  ///
  /// Eight is also where it stops being a fair thing to ask of that endpoint:
  /// unlike the image upload, samples have no background-job path — however
  /// many are sent, they are processed inline while the photographer waits on
  /// the response. Capping the picker is what keeps that wait bounded.
  static const maxPerUpload = 8;

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
