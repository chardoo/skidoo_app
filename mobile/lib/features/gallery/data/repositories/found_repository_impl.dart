import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/gallery/data/datasources/found_remote_data_source.dart';
import 'package:skidoo_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';

class FoundRepositoryImpl implements FoundRepository {
  FoundRepositoryImpl(this._remoteDataSource);

  final FoundRemoteDataSource _remoteDataSource;

  @override
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) =>
      _guard(() => _remoteDataSource.getAlbums(
            filters: filters,
            page: page,
            limit: limit,
            previewLimit: previewLimit,
          ));

  @override
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
  }) =>
      _guard(() => _remoteDataSource.getPhotos(
            filters: filters,
            page: page,
            limit: limit,
          ));

  @override
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters) =>
      _guard(() => _remoteDataSource.getFilterOptions(filters));

  /// Lets the typed exceptions through untouched and wraps anything else, so
  /// callers only ever have to handle the app's own exception vocabulary.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    } on BadRequestException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error loading found photos: $e');
    }
  }
}
