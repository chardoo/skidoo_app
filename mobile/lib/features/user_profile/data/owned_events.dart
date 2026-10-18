import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// The albums this account owns — "My Events" on the profile.
///
/// Ownership is granted by **email address, not by account**: a photographer
/// names the couple on the day, and the album is theirs from that moment,
/// whether or not they had signed up yet. So this is not "albums I made" —
/// for most people here it is albums somebody else shot *for* them.
///
/// It is also not the same list as Purchased, and the two must not be
/// conflated. An owner has bought nothing: `PaidImage` is empty for them and
/// `photoIsBought()` answers no for every frame in an album that is entirely
/// theirs. The server decides this on ownership alone — see
/// `/common/events/owned` and `/common/events/{id}/owned-photos`.
class OwnedEvent {
  const OwnedEvent({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.photoCount,
    this.eventDate,
  });

  final String id;
  final String name;

  /// The album's cover, or '' when it has none — an album with no cover is
  /// drawn as a placeholder tile rather than skipped.
  final String coverUrl;

  /// How many photos are in it, counted server-side over one page of albums.
  final int photoCount;

  final DateTime? eventDate;

  static OwnedEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    if (id.isEmpty) return null;

    DateTime? date;
    final rawDate = raw['eventDate'];
    if (rawDate is String && rawDate.isNotEmpty) {
      date = DateTime.tryParse(rawDate);
    }

    return OwnedEvent(
      id: id,
      name: (raw['eventName'] ?? '').toString(),
      coverUrl: (raw['url'] ?? '').toString(),
      photoCount: (raw['photoCount'] as num?)?.toInt() ?? 0,
      eventDate: date,
    );
  }
}

/// One photo inside an owned album, with the unbadged original to save.
class OwnedPhoto {
  const OwnedPhoto({
    required this.id,
    required this.url,
    required this.originalUrl,
    required this.mediaType,
    this.filename = '',
  });

  final String id;

  /// What the grid draws — the watermarked render when one exists, which is
  /// cheaper to fetch and perfectly good for a thumbnail.
  final String url;

  /// What a download writes to the camera roll: the original, no watermark.
  ///
  /// A separate field rather than a transform of [url], because on R2 the
  /// watermarked copy is its own stored object and cannot be rewritten back
  /// to the original client-side. The server derives it, where the storage
  /// provider is known.
  final String originalUrl;

  final String mediaType;
  final String filename;

  bool get isVideo => mediaType == 'video';

  /// Prefers the original, falls back to the display copy.
  ///
  /// The fallback matters: a row whose `originalUrl` came back empty would
  /// otherwise save nothing at all, and a watermarked photo is a better
  /// outcome than a silent failure in the middle of a batch.
  String get downloadUrl => originalUrl.isNotEmpty ? originalUrl : url;

  static OwnedPhoto? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final url = (raw['url'] ?? '').toString();
    final original = (raw['originalUrl'] ?? '').toString();
    if (id.isEmpty || (url.isEmpty && original.isEmpty)) return null;

    return OwnedPhoto(
      id: id,
      url: url,
      originalUrl: original,
      mediaType: (raw['mediaType'] ?? 'image').toString(),
      filename: (raw['filename'] ?? '').toString(),
    );
  }
}

class OwnedEventsPage<T> {
  const OwnedEventsPage({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;

  static const empty = OwnedEventsPage<Never>(items: [], hasMore: false);
}

class OwnedEventsRepository {
  OwnedEventsRepository({Dio? dio}) : _dio = dio ?? sl<Api>().dio;

  final Dio _dio;

  static List _rows(Object? body) {
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return const [];
  }

  static bool _hasNext(Object? body, int received, int limit) {
    if (body is Map && body['pagination'] is Map) {
      return (body['pagination'] as Map)['hasNext'] == true;
    }
    // Counted off the rows rather than the parsed objects: a row this build
    // could not read is still a row, and a page of nothing but those is still
    // a page with more behind it.
    return received >= limit;
  }

  /// Albums this account owns. Never throws — an empty page is the failure
  /// mode, because this section sits above Purchased and a thrown error here
  /// would take the purchases down with it.
  Future<OwnedEventsPage<OwnedEvent>> getOwnedEvents({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        '/common/events/owned',
        queryParameters: {'page': page, 'limit': limit},
      );
      final rows = _rows(res.data);
      return OwnedEventsPage(
        items: [
          for (final row in rows)
            if (OwnedEvent.fromJson(row) case final e?) e,
        ],
        hasMore: _hasNext(res.data, rows.length, limit),
      );
    } catch (e) {
      debugPrint('[OwnedEvents] list ERROR: $e');
      return const OwnedEventsPage(items: [], hasMore: false);
    }
  }

  /// Every photo in one owned album, with originals.
  ///
  /// Throws, unlike [getOwnedEvents]: this one backs a screen whose entire
  /// purpose is those photos, and showing an empty album when the request
  /// failed would tell somebody their wedding has no pictures in it.
  Future<OwnedEventsPage<OwnedPhoto>> getOwnedPhotos(
    String eventId, {
    int page = 1,
    int limit = 100,
  }) async {
    final res = await _dio.get(
      '/common/events/$eventId/owned-photos',
      queryParameters: {'page': page, 'limit': limit},
    );
    final rows = _rows(res.data);
    return OwnedEventsPage(
      items: [
        for (final row in rows)
          if (OwnedPhoto.fromJson(row) case final p?) p,
      ],
      hasMore: _hasNext(res.data, rows.length, limit),
    );
  }
}
