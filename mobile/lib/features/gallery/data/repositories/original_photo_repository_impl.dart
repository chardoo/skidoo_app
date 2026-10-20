import 'package:jperg_app/features/gallery/data/datasources/original_photo_remote_data_source.dart';
import 'package:jperg_app/features/gallery/domain/repositories/original_photo_repository.dart';

class OriginalPhotoRepositoryImpl implements OriginalPhotoRepository {
  final OriginalPhotoRemoteDataSource _ds;
  OriginalPhotoRepositoryImpl(this._ds);

  @override
  Future<OriginalPhotoFile> getOriginalPhoto(String imageId) =>
      _ds.fetchOriginal(imageId);
}
