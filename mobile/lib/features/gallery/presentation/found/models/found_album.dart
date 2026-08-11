import 'package:flutter/foundation.dart' show immutable;
import 'package:jperg_app/models/photos/Photo.dart';

/// One event's worth of face-matched photos, as returned by
/// `GET /client/my-photos?groupBy=event` and rendered as one section of the
/// Found feed.
///
/// Grouping is the server's job, not the client's: the response carries the
/// true [photoCount] and [moreCount] for the whole event, while [photos] holds
/// only the newest `previewLimit` (6 by default). Deriving those numbers from
/// the loaded page would under-count everything past the preview.
@immutable
class FoundAlbum {
  const FoundAlbum({
    required this.id,
    required this.title,
    required this.photos,
    required this.photoCount,
    required this.moreCount,
    this.mineCount = 0,
    this.eventDate = '',
    this.photographerId = '',
    this.photographerName = '',
    this.photographerAvatarUrl = '',
  });

  final String id;
  final String title;

  /// The preview slice — newest `previewLimit` photos, not the whole event.
  final List<Photo> photos;

  /// Every match in this event, including the ones outside [photos].
  final int photoCount;

  /// What the "+N" tile stands for: matches beyond the preview slice.
  final int moreCount;

  /// How many of [photoCount] the viewer is actually in.
  ///
  /// Lower than [photoCount] wherever the list also carries the event's public
  /// photos — and it is this number, never the row count, that may be spoken
  /// aloud as "we found N photos of you". Saying 54 when 24 are theirs is a
  /// claim about a stranger's photographs.
  final int mineCount;

  final String eventDate;
  final String photographerId;
  final String photographerName;
  final String photographerAvatarUrl;

  bool get hasMore => moreCount > 0;

  /// The tile the "+N" wash sits on — the last of the preview, so the overlay
  /// still reads as part of the album.
  Photo? get overflowCover => photos.isEmpty ? null : photos.last;

  factory FoundAlbum.fromJson(Map<String, dynamic> json) {
    final event = _map(json['event']) ?? const <String, dynamic>{};
    final photographer = _map(event['photographer']) ?? const <String, dynamic>{};

    final photos = (json['photos'] is List ? json['photos'] as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(Photo.fromMap)
        .where((p) => p.url.isNotEmpty)
        .toList(growable: false);

    final count = _int(json['photoCount']) ?? photos.length;

    return FoundAlbum(
      id: event['id']?.toString() ?? '',
      title: event['eventName']?.toString() ?? 'Found photos',
      photos: photos,
      photoCount: count,
      // Absent from an older server, where every row was the viewer's own.
      mineCount: _int(json['mineCount']) ?? count,
      // Trust the server's moreCount; fall back to the arithmetic it implies
      // so a missing field degrades to a sane "+N" rather than none at all.
      moreCount: _int(json['moreCount']) ?? (count - photos.length).clamp(0, count),
      eventDate: event['eventDate']?.toString() ?? '',
      photographerId: photographer['id']?.toString() ?? '',
      photographerName: photographer['name']?.toString() ?? '',
      photographerAvatarUrl: photographer['profile_url']?.toString() ?? '',
    );
  }

  static Map<String, dynamic>? _map(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
