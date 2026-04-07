import 'package:skidoo_app/features/gallery/data/datasources/overlay_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/overlay_repository.dart';

class GetOverlayImageUseCase {
  final OverlayRepository _repo;
  GetOverlayImageUseCase(this._repo);

  /// [imageId] — the image/video identifier.
  /// [photographerName] — included in the overlay request body.
  Future<OverlayResult> call(String imageId, String photographerName) =>
      _repo.getOverlayImage(imageId, photographerName);
}
