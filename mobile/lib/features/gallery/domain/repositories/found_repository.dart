import 'package:jperg_app/features/gallery/data/datasources/found_remote_data_source.dart'
    show FoundAlbumsPage, FoundPhotosPage;
import 'package:jperg_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';

abstract class FoundRepository {
  /// Albums (events) the caller's face was recognized in.
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters,
    int page,
    int limit,
    int previewLimit,
  });

  /// Flat photo list — the "+N" drill-down into a single event.
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters,
    int page,
    int limit,
  });

  /// Chip options + "Show N photos" count for the filter sheet.
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters);
}
