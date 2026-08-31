import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'dart:async';
import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The `pagination` block both list shapes carry.
class FoundPagination {
  const FoundPagination({
    this.page = 1,
    this.limit = 25,
    this.total = 0,
    this.totalPages = 0,
    this.hasNext = false,
  });

  final int page;
  final int limit;

  /// Counts **events** under `groupBy=event`, photos under `groupBy=none`.
  final int total;
  final int totalPages;
  final bool hasNext;

  factory FoundPagination.fromJson(Map<String, dynamic> json) {
    return FoundPagination(
      page: _int(json['page']) ?? 1,
      limit: _int(json['limit']) ?? 25,
      total: _int(json['total']) ?? 0,
      totalPages: _int(json['totalPages']) ?? 0,
      hasNext: json['hasNext'] as bool? ??
          // Older/partial envelopes: derive it rather than stalling paging.
          ((_int(json['page']) ?? 1) < (_int(json['totalPages']) ?? 0)),
    );
  }

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// One page of `groupBy=event`: albums plus the headline totals.
class FoundAlbumsPage {
  const FoundAlbumsPage({
    required this.albums,
    required this.pagination,
    required this.totalPhotos,
    required this.totalEvents,
  });

  final List<FoundAlbum> albums;
  final FoundPagination pagination;

  /// `totals.photos` — the "48 found" headline, across every page and honouring
  /// the filter set (the server counts it over the same predicate it selects
  /// rows with).
  ///
  /// Null when the envelope carried no usable `totals`. It is deliberately not
  /// defaulted to a number: the only value derivable here is a sum over *this
  /// page's* albums, which would undercount every event past the page and then
  /// lurch as the user scrolls. A missing headline beats a wrong one.
  final int? totalPhotos;
  final int totalEvents;
}

/// One page of `groupBy=none`: a flat photo list.
class FoundPhotosPage {
  const FoundPhotosPage({required this.photos, required this.pagination});

  final List<Photo> photos;
  final FoundPagination pagination;
}

abstract class FoundRemoteDataSource {
  /// Albums (events) the caller's face was recognized in, newest match first.
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters,
    int page,
    int limit,
    int previewLimit,
  });

  /// Flat photo list — used for the "+N" drill-down into a single event.
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters,
    int page,
    int limit,
  });

  /// Chip options + the "Show N photos" count for the filter sheet.
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters);
}

class FoundRemoteDataSourceImpl implements FoundRemoteDataSource {
  FoundRemoteDataSourceImpl(this._api);

  final Api _api;

  /// Recognitions — the ImageIdentification table, NOT the purchased gallery
  /// (`/client/dashboard`, a different list entirely). Auth'd: the server
  /// resolves the caller from the bearer token, so no client id is sent.
  static const _path = '/client/my-photos';
  static const _filtersPath = '/client/my-photos/filters';

  @override
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) async {
    final raw = await _get(_path, {
      ...filters.toQueryParameters(),
      'groupBy': 'event',
      'previewLimit': previewLimit,
      'page': page,
      'limit': limit,
    });

    final parsed = parseAlbumsPage(raw);

    // Record unfiltered pages so the tab opens to the albums it last showed,
    // as far as the reader had scrolled, with or without a connection.
    // Filtered results are somebody mid-search — restoring those on a cold
    // launch would open the tab to a narrowed list with no visible reason.
    if (filters == FoundFilters.none) {
      unawaited(sl<DiskCache>(instanceName: kFoundAlbumsCache).save(
        _dataList(raw),
        page: page,
        hasMore: parsed.pagination.hasNext,
      ));
    }
    return parsed;
  }

  @override
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
  }) async {
    final raw = await _get(_path, {
      ...filters.toQueryParameters(),
      'groupBy': 'none',
      'page': page,
      'limit': limit,
    });
    return parsePhotosPage(raw);
  }

  @override
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters) async {
    final raw = await _get(_filtersPath, filters.toQueryParameters());
    final body = raw is Map<String, dynamic>
        ? (raw['data'] is Map<String, dynamic>
            ? raw['data'] as Map<String, dynamic>
            : raw)
        : const <String, dynamic>{};
    return FoundFilterOptions.fromJson(body);
  }

  Future<dynamic> _get(String path, Map<String, dynamic> query) async {
    try {
      final res = await _api.dio.get(
        path,
        queryParameters: query,
        // `photographerId` and `eventId` are repeatable. Pinned explicitly so
        // they always go out as `?photographerId=a&photographerId=b` rather
        // than depending on Dio's global default staying `multi`.
        options: dio.Options(listFormat: dio.ListFormat.multi),
      );
      return res.data;
    } on dio.DioException catch (err) {
      final response = err.response;
      if (response == null) throw const app_ex.NetworkException();
      // Standard error envelope: { success: false, error: { code, message } }.
      final message = _errorMessage(response.data);
      // The router raises 400 for the filter rules it checks itself (unknown
      // dateRange/visibility, custom with no dates, startDate > endDate);
      // FastAPI's own validation returns 422 for out-of-range paging or a
      // malformed date. Both arrive in the same envelope, so both are the
      // user's selection being wrong rather than the server failing.
      if (response.statusCode == 400 || response.statusCode == 422) {
        throw app_ex.BadRequestException(message ?? 'Invalid filter selection.');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const app_ex.UnauthorizedException();
      }
      throw app_ex.ServerException(
          message ?? 'Found photos load failed: ${response.statusCode}');
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

  // ── Parsing (split out so it's unit-testable without a Dio client) ────────

  static FoundAlbumsPage parseAlbumsPage(dynamic raw) {
    final envelope = raw is Map<String, dynamic> ? raw : const {};
    final totals = envelope['totals'];

    final albums = _dataList(raw)
        .whereType<Map<String, dynamic>>()
        .map(FoundAlbum.fromJson)
        .where((a) => a.photos.isNotEmpty)
        .toList(growable: false);

    final pagination = _pagination(envelope);

    return FoundAlbumsPage(
      albums: albums,
      pagination: pagination,
      // `pagination.total` counts events here, so the photo headline has to
      // come from `totals.photos` — or from nowhere. See [totalPhotos].
      totalPhotos: totals is Map ? FoundPagination._int(totals['photos']) : null,
      // Events are the paged unit, so `pagination.total` is an exact stand-in
      // when `totals` is missing.
      totalEvents: totals is Map
          ? (FoundPagination._int(totals['events']) ?? pagination.total)
          : pagination.total,
    );
  }

  static FoundPhotosPage parsePhotosPage(dynamic raw) {
    final envelope = raw is Map<String, dynamic> ? raw : const {};
    return FoundPhotosPage(
      photos: _dataList(raw)
          .whereType<Map<String, dynamic>>()
          .map(Photo.fromMap)
          .where((p) => p.url.isNotEmpty)
          .toList(growable: false),
      pagination: _pagination(envelope),
    );
  }

  static FoundPagination _pagination(Map envelope) {
    final raw = envelope['pagination'];
    return raw is Map<String, dynamic>
        ? FoundPagination.fromJson(raw)
        : const FoundPagination();
  }

  static List<dynamic> _dataList(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map && raw['data'] is List) return raw['data'] as List;
    return const [];
  }
}
