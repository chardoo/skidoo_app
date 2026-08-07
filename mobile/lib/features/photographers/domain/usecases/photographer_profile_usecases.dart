import 'package:cross_file/cross_file.dart';
import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';

class GetPhotographerProfileUseCase {
  final PhotographerRepository _repository;
  GetPhotographerProfileUseCase(this._repository);

  Future<Map<String, dynamic>> call(String photographerId) =>
      _repository.getPhotographerProfile(photographerId);
}

class UpdatePhotographerProfileUseCase {
  final PhotographerRepository _repository;
  UpdatePhotographerProfileUseCase(this._repository);

  Future<void> call({
    required String photographerId,
    String? studioName,
    String? bio,
    List<String>? specialties,
    String? location,
  }) =>
      _repository.updatePhotographerProfile(
        photographerId: photographerId,
        studioName: studioName,
        bio: bio,
        specialties: specialties,
        location: location,
      );
}

class UploadPhotographerProfilePhotoUseCase {
  final PhotographerRepository _repository;
  UploadPhotographerProfilePhotoUseCase(this._repository);

  Future<String> call({
    required String photographerId,
    required XFile photo,
  }) =>
      _repository.uploadProfilePhoto(photographerId: photographerId, photo: photo);
}

class UploadStudioImageUseCase {
  final PhotographerRepository _repository;
  UploadStudioImageUseCase(this._repository);

  Future<String> call({
    required String photographerId,
    required XFile image,
  }) =>
      _repository.uploadStudioImage(photographerId: photographerId, image: image);
}

class SubmitVerificationUseCase {
  final PhotographerRepository _repository;
  SubmitVerificationUseCase(this._repository);

  Future<void> call({
    required String photographerId,
    required XFile idDocument,
    required bool acceptedTerms,
    required bool confirmedUploadRights,
    required bool acceptedPayoutPolicy,
  }) =>
      _repository.submitVerification(
        photographerId: photographerId,
        idDocument: idDocument,
        acceptedTerms: acceptedTerms,
        confirmedUploadRights: confirmedUploadRights,
        acceptedPayoutPolicy: acceptedPayoutPolicy,
      );
}
