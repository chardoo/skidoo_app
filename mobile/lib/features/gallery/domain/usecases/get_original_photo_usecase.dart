import 'package:jperg_app/features/gallery/data/datasources/original_photo_remote_data_source.dart';
import 'package:jperg_app/features/gallery/domain/repositories/original_photo_repository.dart';

/// The bytes a download writes to the device: the original, with no jperg
/// lockup burned into it.
///
/// No `photographerName` any more. It was only ever there for the badge, and
/// the badge took no name in the end — see `app/utils/watermark.py`, which
/// accepts the field and ignores it. A parameter that reaches a server which
/// discards it is worse than no parameter: every call site had to find a name
/// to pass, and the one that could not passed an empty string.
class GetOriginalPhotoUseCase {
  final OriginalPhotoRepository _repo;
  GetOriginalPhotoUseCase(this._repo);

  /// [imageId] — the image/video identifier.
  Future<OriginalPhotoFile> call(String imageId) =>
      _repo.getOriginalPhoto(imageId);
}
