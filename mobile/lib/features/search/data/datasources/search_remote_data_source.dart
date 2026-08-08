import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The Search screen's four reads.
///
/// All of them work signed-out — the bearer token only changes *what* comes
/// back (`owner` on events, `isFollowedByMe` on photographers, private photos
/// the viewer is recognised in, a personalised "You may like"), never whether
/// the call succeeds. Recent searches are deliberately absent: they live on
/// the device and never reach the server.
abstract class SearchRemoteDataSource {
  /// `type=all` — all three sections plus the counts behind the chip labels.
  Future<SearchAllResults> searchAll(String query);

  /// One section, paged. Used once a chip owns the screen.
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

  /// The events behind a tag row. Accepts the tag with or without `#`.
  Future<TagEventsPage> eventsForTag(String tag, {int page, int limit});

  /// The "You may like" grid. [refresh] (the ↻ button) rebuilds the snapshot.
  Future<YouMayLikePage> youMayLike({int limit, int cursor, bool refresh});

  /// An event's photos. Accepts the event id **or** its access code.
  Future<EventPhotosPage> eventPhotos(String eventId, {int page, int limit});

  /// One photo and the event it belongs to, for a `/p/{id}` deep link.
  ///
  /// Throws [app_ex.NotFoundException] when the photo is gone *or* when this
  /// viewer has no claim on it — the server does not distinguish the two, and
  /// neither should anything downstream.
  Future<Photo> pictureById(String pictureId);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  SearchRemoteDataSourceImpl(this._api);

  final Api _api;

  static const _resultsPath = '/client/search/results';
  static const _tagsPath = '/client/search/tags';
  static const _youMayLikePath = '/client/search/you-may-like';

  /// The server caps this at 100; the design only ever needs a screenful more.
  static const defaultLimit = 25;
  static const defaultPhotoLimit = 30;

  // ── Results ────────────────────────────────────────────────────────────────

  @override
  Future<SearchAllResults> searchAll(String query) async {
    final raw = await _get(_resultsPath, {'q': query, 'type': 'all'});
    final body = _envelope(raw);
    return SearchAllResults.fromJson(body);
  }

  @override
  Future<SearchSectionPage<SearchEventRow>> searchEvents(
    String query, {
    int page = 1,
    int limit = defaultLimit,
  }) =>
      _section(SearchResultType.events, query, SearchEventRow.fromJson,
          page: page, limit: limit);

  @override
  Future<SearchSectionPage<SearchPhotographerRow>> searchPhotographers(
    String query, {
    int page = 1,
    int limit = defaultLimit,
  }) =>
      _section(SearchResultType.photographers, query,
          SearchPhotographerRow.fromJson,
          page: page, limit: limit);

  @override
  Future<SearchSectionPage<SearchTagRow>> searchTags(
    String query, {
    int page = 1,
    int limit = defaultLimit,
  }) =>
      _section(SearchResultType.tags, query, SearchTagRow.fromJson,
          page: page, limit: limit);

  /// The three section reads differ only in `type` and the row parser, so they
  /// share one implementation rather than three near-identical copies.
  Future<SearchSectionPage<T>> _section<T>(
    SearchResultType type,
    String query,
    T Function(Map<String, dynamic>) parse, {
    required int page,
    required int limit,
  }) async {
    final raw = await _get(_resultsPath, {
      'q': query,
      'type': type.wire,
      'page': page,
      'limit': limit,
    });
    return SearchSectionPage<T>(
      items: _rows(raw, parse),
      pagination: _pagination(raw),
    );
  }

  // ── Tag drill-down ─────────────────────────────────────────────────────────

  @override
  Future<TagEventsPage> eventsForTag(
    String tag, {
    int page = 1,
    int limit = defaultLimit,
  }) async {
    // The path segment is the tag itself; strip the display `#` and encode so
    // tags with spaces or slashes survive the round trip.
    final key = tag.startsWith('#') ? tag.substring(1) : tag;
    final raw = await _get(
      '$_tagsPath/${Uri.encodeComponent(key)}',
      {'page': page, 'limit': limit},
    );
    final body = _envelope(raw);
    // Reuse the row's own normalisation so the drill-down header and the row
    // it was opened from can't disagree about the `#`.
    final header = SearchTagRow.fromJson({
      'tag': SearchJson.str(body, ['tag']).isEmpty ? key : body['tag'],
      'label': body['label'],
      'postCount': body['postCount'],
      'eventCount': body['eventCount'],
    });
    return TagEventsPage(
      tag: header.tag,
      label: header.label,
      postCount: header.postCount,
      eventCount: header.eventCount,
      events: _rows(raw, SearchEventRow.fromJson),
      pagination: _pagination(raw),
    );
  }

  // ── You may like ───────────────────────────────────────────────────────────

  @override
  Future<YouMayLikePage> youMayLike({
    int limit = 30,
    int cursor = 0,
    bool refresh = false,
  }) async {
    final raw = await _get(_youMayLikePath, {
      'limit': limit,
      'cursor': cursor,
      if (refresh) 'refresh': true,
    });
    final body = _envelope(raw);
    return YouMayLikePage(
      photos: _photos(_dataList(raw)),
      // Null is the end of the set, so it must survive as null rather than
      // collapsing to 0 — 0 is a valid cursor meaning "start over".
      nextCursor: SearchJson.intOrNull(body['nextCursor']),
    );
  }

  // ── Event photos ───────────────────────────────────────────────────────────

  @override
  Future<EventPhotosPage> eventPhotos(
    String eventId, {
    int page = 1,
    int limit = defaultPhotoLimit,
  }) async {
    final raw = await _get(
      '/client/events/${Uri.encodeComponent(eventId)}/photos',
      {'page': page, 'limit': limit},
    );
    final body = _envelope(raw);
    final eventJson = SearchJson.map(body['event']);
    return EventPhotosPage(
      event: eventJson == null
          ? SearchEventRow.empty
          : SearchEventRow.fromJson(eventJson),
      // The rows carry no event of their own here — the envelope hoists it out
      // so it isn't repeated 100 times. Folding it back in is what lets these
      // photos share [Photo] (and therefore the viewer) with every other list.
      photos: _photos(_dataList(raw), event: eventJson),
      pagination: _pagination(raw),
    );
  }

  // ── One picture ────────────────────────────────────────────────────────────

  @override
  Future<Photo> pictureById(String pictureId) async {
    final raw = await _get(
      '/client/pictures/${Uri.encodeComponent(pictureId)}',
      const {},
    );
    final body = _envelope(raw);
    final photoJson = SearchJson.map(body['photo']);
    if (photoJson == null) {
      throw const app_ex.NotFoundException('Photo not found.');
    }
    // Same fold as the grid above: the event is hoisted out of the row in the
    // envelope, and putting it back is what lets this Photo open in the same
    // viewer every other list uses.
    final photo = Photo.fromMap({
      if (SearchJson.map(body['event']) != null) 'event': body['event'],
      ...photoJson,
    });
    if (photo.url.isEmpty) {
      throw const app_ex.NotFoundException('Photo not found.');
    }
    return photo;
  }

  // ── Transport ──────────────────────────────────────────────────────────────

  Future<dynamic> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _api.dio.get(path, queryParameters: query);
      return res.data;
    } on dio.DioException catch (err) {
      final response = err.response;
      if (response == null) throw const app_ex.NetworkException();
      // Standard error envelope: { success: false, error: { code, message } }.
      final message = _errorMessage(response.data);
      switch (response.statusCode) {
        // The router raises 400 for an unknown `type`; FastAPI returns 422 for
        // out-of-range paging or a `q` outside 1–200 chars. Both are the
        // request being wrong rather than the server failing.
        case 400:
        case 422:
          throw app_ex.BadRequestException(message ?? 'Invalid search request.');
        case 404:
          throw app_ex.NotFoundException(message ?? 'Not found.');
        case 401:
        case 403:
          throw const app_ex.UnauthorizedException();
        default:
          throw app_ex.ServerException(
              message ?? 'Search failed: ${response.statusCode}');
      }
    }
  }

  static String? _errorMessage(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is Map) {
      final message = error['message'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }
    return null;
  }

  // ── Parsing (static so it is unit-testable without a Dio client) ───────────

  /// The object the fields live on. Tolerates a `data`-wrapped envelope for
  /// endpoints whose *body* — not whose list — is nested.
  static Map<String, dynamic> _envelope(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const {};
    final data = raw['data'];
    // A `data` **list** means the rows are nested, not the body — keep `raw`.
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  static List<dynamic> _dataList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['data'] is List) return raw['data'] as List;
    return const [];
  }

  static List<T> _rows<T>(dynamic raw, T Function(Map<String, dynamic>) parse) =>
      _dataList(raw)
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);

  static SearchPagination _pagination(dynamic raw) {
    final block = raw is Map ? raw['pagination'] : null;
    return block is Map<String, dynamic>
        ? SearchPagination.fromJson(block)
        : const SearchPagination();
  }

  /// [Photo.fromMap] already understands both shapes the search endpoints
  /// send — the picture's fields at the top level with an `event` alongside.
  /// [event] is folded in for the endpoints that hoist it into the envelope.
  static List<Photo> _photos(
    List<dynamic> rows, {
    Map<String, dynamic>? event,
  }) =>
      rows
          .whereType<Map<String, dynamic>>()
          .map((row) => Photo.fromMap(
                event == null ? row : {'event': event, ...row},
              ))
          .where((photo) => photo.url.isNotEmpty)
          .toList(growable: false);
}
