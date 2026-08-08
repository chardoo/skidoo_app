import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/domain/repositories/search_repository.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The Search screen's reads, grouped in one use case rather than six
/// near-identical classes: they are always wired up together and share the
/// same query argument.
class SearchUseCase {
  const SearchUseCase(this._repository);

  final SearchRepository _repository;

  /// First request for a query — fills all three sections and the chip counts.
  Future<SearchAllResults> all(String query) => _repository.searchAll(query);

  /// One section, paged. Dispatches on [type] so the caller can page whichever
  /// chip is active without a switch of its own; the row lists stay typed,
  /// which is why the three sections are separate calls underneath.
  Future<SearchSectionPage<Object>> section(
    SearchResultType type,
    String query, {
    int page = 1,
    int limit = 25,
  }) =>
      switch (type) {
        SearchResultType.events =>
          _repository.searchEvents(query, page: page, limit: limit),
        SearchResultType.photographers =>
          _repository.searchPhotographers(query, page: page, limit: limit),
        SearchResultType.tags =>
          _repository.searchTags(query, page: page, limit: limit),
      };

  Future<TagEventsPage> tagEvents(String tag, {int page = 1, int limit = 25}) =>
      _repository.eventsForTag(tag, page: page, limit: limit);

  Future<YouMayLikePage> youMayLike({
    int limit = 30,
    int cursor = 0,
    bool refresh = false,
  }) =>
      _repository.youMayLike(limit: limit, cursor: cursor, refresh: refresh);

  Future<EventPhotosPage> eventPhotos(
    String eventId, {
    int page = 1,
    int limit = 30,
  }) =>
      _repository.eventPhotos(eventId, page: page, limit: limit);

  /// One photo by id, for a `/p/{id}` deep link.
  Future<Photo> picture(String pictureId) =>
      _repository.pictureById(pictureId);
}
