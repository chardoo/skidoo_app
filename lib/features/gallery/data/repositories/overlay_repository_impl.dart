import 'package:skidoo_app/features/gallery/data/datasources/overlay_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/overlay_repository.dart';

class OverlayRepositoryImpl implements OverlayRepository {
  final OverlayRemoteDataSource _ds;
  OverlayRepositoryImpl(this._ds);

  @override
  Future<OverlayResult> getOverlayImage(
          String imageId, String photographerName) =>
      _ds.getOverlayImage(imageId, photographerName);
}
