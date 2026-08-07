import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/gallery/data/datasources/gallery_remote_data_source.dart';
import 'package:jperg_app/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:jperg_app/models/photos/Photo.dart';

class GalleryRepositoryImpl implements GalleryRepository {
  final GalleryRemoteDataSource _remoteDataSource;
  GalleryRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Photo>> getUserGallery(String clientId) async {
    try {
      return await _remoteDataSource.getUserGallery(clientId);
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error loading gallery: $e');
    }
  }
}
