import 'package:skidoo_app/features/gallery/data/datasources/found_remote_data_source.dart'
    show FoundAlbumsPage, FoundPhotosPage;
import 'package:skidoo_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';

/// The Found tab's three reads. Grouped in one use case rather than three
/// near-identical classes: they share the same filter argument and are always
/// wired up together.
class GetFoundPhotosUseCase {
  GetFoundPhotosUseCase(this._repository);

  final FoundRepository _repository;

  Future<FoundAlbumsPage> albums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) =>
      _repository.getAlbums(
        filters: filters,
        page: page,
        limit: limit,
        previewLimit: previewLimit,
      );

  Future<FoundPhotosPage> photos({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
  }) =>
      _repository.getPhotos(filters: filters, page: page, limit: limit);

  Future<FoundFilterOptions> filterOptions(FoundFilters filters) =>
      _repository.getFilterOptions(filters);
}
