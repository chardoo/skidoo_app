import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/search/data/datasources/search_remote_data_source.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._remote);

  final SearchRemoteDataSource _remote;

  @override
  Future<SearchAllResults> searchAll(String query) =>
      _guard(() => _remote.searchAll(query));

  @override
  Future<SearchSectionPage<SearchEventRow>> searchEvents(
    String query, {
    int page = 1,
    int limit = SearchRemoteDataSourceImpl.defaultLimit,
  }) =>
      _guard(() => _remote.searchEvents(query, page: page, limit: limit));

  @override
  Future<SearchSectionPage<SearchPhotographerRow>> searchPhotographers(
    String query, {
    int page = 1,
    int limit = SearchRemoteDataSourceImpl.defaultLimit,
  }) =>
      _guard(() => _remote.searchPhotographers(query, page: page, limit: limit));

  @override
  Future<SearchSectionPage<SearchTagRow>> searchTags(
    String query, {
    int page = 1,
    int limit = SearchRemoteDataSourceImpl.defaultLimit,
  }) =>
      _guard(() => _remote.searchTags(query, page: page, limit: limit));

  @override
  Future<TagEventsPage> eventsForTag(
    String tag, {
    int page = 1,
    int limit = SearchRemoteDataSourceImpl.defaultLimit,
  }) =>
      _guard(() => _remote.eventsForTag(tag, page: page, limit: limit));

  @override
  Future<YouMayLikePage> youMayLike({
    int limit = 30,
    int cursor = 0,
    bool refresh = false,
  }) =>
      _guard(() =>
          _remote.youMayLike(limit: limit, cursor: cursor, refresh: refresh));

  @override
  Future<EventPhotosPage> eventPhotos(
    String eventId, {
    int page = 1,
    int limit = SearchRemoteDataSourceImpl.defaultPhotoLimit,
  }) =>
      _guard(() => _remote.eventPhotos(eventId, page: page, limit: limit));

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
    } on NotFoundException {
      rethrow;
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw ServerException('Unexpected error while searching: $e');
    }
  }
}
