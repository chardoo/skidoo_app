import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Mirrors [SearchRemoteDataSource]. See it for what each call returns and
/// how the bearer token changes the payload.
abstract class SearchRepository {
  Future<SearchAllResults> searchAll(String query);

  Future<SearchSectionPage<SearchEventRow>> searchEvents(
    String query, {
    int page,
    int limit,
  });

  Future<SearchSectionPage<SearchPhotographerRow>> searchPhotographers(
    String query, {
    int page,
    int limit,
  });

  Future<SearchSectionPage<SearchTagRow>> searchTags(
    String query, {
    int page,
    int limit,
  });

  Future<TagEventsPage> eventsForTag(String tag, {int page, int limit});

  Future<YouMayLikePage> youMayLike({int limit, int cursor, bool refresh});

  Future<EventPhotosPage> eventPhotos(String eventId, {int page, int limit});

  Future<Photo> pictureById(String pictureId);
}
