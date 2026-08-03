import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';

const _tag = '[FoundReviewRepository]';

/// Photos face recognition found of you that you have not answered for.
///
/// They stay pending until you do — the banner keeps offering them, and
/// closing the review screen decides nothing.
class FoundReviewRepository {
  FoundReviewRepository() : _dio = Api().dio;

  final Dio _dio;

  Future<PendingFound> getPending() async {
    debugPrint('$_tag getPending →');
    final resp = await _dio.get('/client/found/new');
    return PendingFound.fromJson(
      resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : const {},
    );
  }

  /// Answer for a batch. Confirmed and rejected go together because the screen
  /// decides everything at once — sending them separately would leave a
  /// half-answered review if the second call failed.
  Future<int> review({
    required List<String> confirmed,
    required List<String> rejected,
  }) async {
    debugPrint('$_tag review → ${confirmed.length} yes, ${rejected.length} no');
    final resp = await _dio.post('/client/found/review', data: {
      'confirmed': confirmed,
      'rejected': rejected,
    });
    final body = resp.data;
    return body is Map<String, dynamic>
        ? (body['remaining'] as num?)?.toInt() ?? 0
        : 0;
  }
}

class PendingFound {
  const PendingFound({
    this.total = 0,
    this.eventCount = 0,
    this.coverUrl,
    this.events = const [],
  });

  final int total;
  final int eventCount;

  /// The face on the banner.
  final String? coverUrl;
  final List<PendingFoundEvent> events;

  static const none = PendingFound();

  bool get isEmpty => total == 0;

  /// "2 new photos at Praise Reloaded 2026" for one event, "You were found in
  /// 3 events" for several — the design words them differently.
  String get title =>
      eventCount > 1 ? 'You were found in $eventCount events' : 'You were found';

  String get subtitle {
    if (events.isEmpty) return '';
    if (eventCount > 1) return events.map((e) => e.eventName).join(', ');
    final photos = total == 1 ? '1 new photo' : '$total new photos';
    return '$photos at ${events.first.eventName}';
  }

  factory PendingFound.fromJson(Map<String, dynamic> json) => PendingFound(
        total: (json['total'] as num?)?.toInt() ?? 0,
        eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
        coverUrl: json['coverUrl'] as String?,
        events: (json['events'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(PendingFoundEvent.fromJson)
            .toList(),
      );
}

class PendingFoundEvent {
  const PendingFoundEvent({
    required this.id,
    required this.eventName,
    this.photos = const [],
  });

  final String id;
  final String eventName;
  final List<PendingFoundPhoto> photos;

  factory PendingFoundEvent.fromJson(Map<String, dynamic> json) {
    final event = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return PendingFoundEvent(
      id: event['id'] as String? ?? '',
      eventName: event['eventName'] as String? ?? '',
      photos: (json['photos'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PendingFoundPhoto.fromJson)
          .toList(),
    );
  }
}

class PendingFoundPhoto {
  const PendingFoundPhoto({
    required this.id,
    required this.url,
    this.width,
    this.height,
  });

  final String id;
  final String url;
  final int? width;
  final int? height;

  factory PendingFoundPhoto.fromJson(Map<String, dynamic> json) =>
      PendingFoundPhoto(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
      );
}
