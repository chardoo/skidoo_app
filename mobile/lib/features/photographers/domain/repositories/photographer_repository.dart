import 'package:cross_file/cross_file.dart';
import 'package:skidoo_app/models/photographer/photographer_event.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

abstract class PhotographerRepository {
  Future<List<PhotographerModel>> getPhotographers();
  Future<List<PhotographerModel>> searchPhotographers(String query);
  Future<List<PhotographerSample>> getSamples(String photographerId);
  Future<List<PhotographerSample>> uploadSamples({
    required String photographerId,
    required List<XFile> files,
  });
  Future<void> deleteSample({
    required String sampleId,
    required String photographerId,
  });
  Future<PhotographerEventsResult> getPhotographerEvents({
    required String photographerId,
    required int page,
    required int limit,
  });

  /// Fetches the current portfolio profile fields (bio, specialties, studio
  /// name, studio image, profile photo, verified_by_admin) for
  /// [photographerId] via `GET /photographer/profile/{id}` — confirmed
  /// contract, `docs/FRONTEND_PROFILE_AND_SAMPLES.md`.
  Future<Map<String, dynamic>> getPhotographerProfile(String photographerId);

  /// Saves `bio`/`specialties`/`studio_name` via `PATCH
  /// /photographer/profile/{id}` — confirmed contract (multipart form,
  /// `specialties` as a JSON array string). Does **not** touch the profile
  /// photo or studio image — those are separate dedicated endpoints, see
  /// [uploadProfilePhoto] / [uploadStudioImage].
  Future<void> updatePhotographerProfile({
    required String photographerId,
    String? studioName,
    String? bio,
    List<String>? specialties,
  });

  /// Uploads/replaces the personal avatar via `POST
  /// /photographer/profile/{id}/photo` — confirmed contract, distinct from
  /// [uploadStudioImage] (a photographer profile now has two independent
  /// images).
  Future<String> uploadProfilePhoto({
    required String photographerId,
    required XFile photo,
  });

  /// Uploads/replaces the studio cover photo via `POST
  /// /photographer/profile/{id}/studio-image` — confirmed contract. Single
  /// image only; each call replaces the previous one.
  Future<String> uploadStudioImage({
    required String photographerId,
    required XFile image,
  });

  /// Submits Ghana Card ID verification + terms/payout-policy acceptance.
  /// **Assumed** endpoint (`POST /photographer/verification`) — no backend
  /// contract exists for this yet, flagged for confirmation.
  Future<void> submitVerification({
    required String photographerId,
    required XFile idDocument,
    required bool acceptedTerms,
    required bool confirmedUploadRights,
    required bool acceptedPayoutPolicy,
  });
}
