import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';

const _tag = '[ProfileOverviewRepository]';

/// The profile screen's own data: the header figures, the photos the user
/// liked, and the ones they bookmarked.
///
/// Kept apart from [UserProfileRepository], which owns the account record and
/// its settings — this is what the three tabs and the header read.
class ProfileOverviewRepository {
  ProfileOverviewRepository() : _dio = Api().dio;

  final Dio _dio;

  static Map<String, dynamic> _asMap(dynamic body) =>
      body is Map<String, dynamic> ? body : const {};

  static List<Map<String, dynamic>> _listUnder(dynamic body, String key) {
    final map = _asMap(body);
    final raw = map[key];
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  /// Avatar, username, and the Found / Following / Campaigns figures.
  Future<ProfileOverview> getOverview() async {
    debugPrint('$_tag getOverview →');
    final resp = await _dio.get('/client/me/profile');
    debugPrint('$_tag getOverview ← status=${resp.statusCode}');
    return ProfileOverview.fromJson(_asMap(resp.data));
  }

  /// Everything the user liked — photos and events together, newest first.
  ///
  /// Asks for both rather than just pictures: a liked event is a like, and a
  /// tab that dropped it would look like the like had failed. An event renders
  /// by its own cover.
  Future<List<ProfilePhoto>> getLikedPhotos({int limit = 30}) async {
    final resp = await _dio.get('/client/my-likes', queryParameters: {
      'type': 'all',
      'limit': limit,
    });

    final liked = <ProfilePhoto>[
      ..._listUnder(resp.data, 'pictures').map(ProfilePhoto.fromJson),
      ..._listUnder(resp.data, 'events')
          .map(ProfilePhoto.fromLikedEvent)
          .whereType<ProfilePhoto>(),
    ];
    // Each list arrives sorted, but they are two lists — one grid means one
    // order, and the only one that makes sense is when it was liked.
    liked.sort((a, b) => (b.likedAt ?? '').compareTo(a.likedAt ?? ''));
    return liked;
  }

  /// Everything bookmarked — the same list the Saved screen shows, from the
  /// same endpoint. Not filtered to pictures: people bookmark events too, and
  /// a tab that silently dropped them would look like the bookmark had failed.
  ///
  /// The endpoint carries the client id in the path and only ever serves the
  /// caller's own, so the id has to be the signed-in one.
  Future<List<ProfilePhoto>> getBookmarkedPhotos(
    String userId, {
    int page = 1,
    int limit = 30,
  }) async {
    final resp = await _dio.get('/client/$userId/saved', queryParameters: {
      'page': page,
      'limit': limit,
    });

    final photos = <ProfilePhoto>[];
    for (final row in _listUnder(resp.data, 'data')) {
      final asset = row['asset'];
      // An asset deleted since it was bookmarked comes back null, and requests
      // and campaigns live in another service and arrive without one.
      if (asset is! Map<String, dynamic>) continue;
      final photo = ProfilePhoto.fromSavedAsset(
        asset,
        assetType: row['assetType'] as String? ?? 'picture',
        savedItemId: row['id'] as String?,
      );
      if (photo != null) photos.add(photo);
    }
    return photos;
  }

  /// Un-bookmark. Takes the saved-row id, which is what the list returns.
  Future<void> removeBookmark(String userId, String savedItemId) async {
    await _dio.delete('/client/$userId/saved/$savedItemId');
  }

  /// Unlike a photo. The chat service owns likes; this is the same toggle the
  /// feed uses, so calling it on something already liked removes it.
  Future<void> unlikePhoto(String pictureId) async {
    await _dio.post('/chat/pictures/$pictureId/like');
  }

  /// Unlike an event. Sending the reaction already held clears it, so this
  /// toggles the like off the same way the photo call does.
  Future<void> unlikeEvent(String eventId) async {
    await _dio.post(
      '/chat/events/$eventId/reaction',
      queryParameters: {'reaction': 'like'},
    );
  }
}

class ProfileOverview {
  const ProfileOverview({
    required this.id,
    required this.username,
    this.name,
    this.profileUrl,
    this.found = 0,
    this.following = 0,
    this.followers = 0,
    this.campaigns = 0,
    this.requests = 0,
  });

  final String id;

  /// What sits under the avatar. Falls back to the display name server-side,
  /// so it is never empty for an account that has a name.
  final String username;
  final String? name;
  final String? profileUrl;

  /// Photos face recognition matched this person in.
  final int found;
  final int following;
  final int followers;
  final int campaigns;
  final int requests;

  static const empty = ProfileOverview(id: '', username: '');

  factory ProfileOverview.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : const <String, dynamic>{};
    int count(String key) => (stats[key] as num?)?.toInt() ?? 0;

    return ProfileOverview(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String?,
      profileUrl: json['profile_url'] as String?,
      found: count('found'),
      following: count('following'),
      followers: count('followers'),
      campaigns: count('campaigns'),
      requests: count('requests'),
    );
  }
}

/// A photo in one of the profile grids. Both tabs return the same shape, so
/// one tile widget renders either.
class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.url,
    this.width,
    this.height,
    this.mediaType = 'image',
    this.eventId,
    this.eventName,
    this.savedItemId,
    this.isEvent = false,
    this.likedAt,
  });

  final String id;
  final String url;

  /// Known for anything uploaded since the size was recorded — the grid uses
  /// it to reserve the tile instead of reflowing as each photo lands.
  final int? width;
  final int? height;
  final String mediaType;
  final String? eventId;
  final String? eventName;

  /// The bookmark row this tile came from, needed to remove it. Null on liked
  /// photos, which are unliked by picture id instead.
  final String? savedItemId;

  /// An event rather than a photo — the tile shows its cover, and removing it
  /// clears an event reaction rather than a picture like.
  final bool isEvent;

  /// When it was liked. Sorts the two liked lists into one grid.
  final String? likedAt;

  bool get isVideo => mediaType == 'video';

  factory ProfilePhoto.fromJson(Map<String, dynamic> json) {
    final event = json['event'] is Map<String, dynamic>
        ? json['event'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return ProfilePhoto(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      mediaType: json['mediaType'] as String? ?? 'image',
      eventId: event['id'] as String? ?? json['eventId'] as String?,
      eventName: event['eventName'] as String?,
      likedAt: json['likedAt'] as String?,
    );
  }

  /// A liked event. Its cover is the tile — `coverUrl` is the event's own
  /// image, which is what stands in for a photo it has none of.
  static ProfilePhoto? fromLikedEvent(Map<String, dynamic> json) {
    final url = (json['coverUrl'] ?? json['url']) as String?;
    if (url == null || url.isEmpty) return null;
    return ProfilePhoto(
      id: json['id'] as String? ?? '',
      url: url,
      width: (json['coverWidth'] as num?)?.toInt(),
      height: (json['coverHeight'] as num?)?.toInt(),
      eventId: json['id'] as String?,
      eventName: json['eventName'] as String?,
      isEvent: true,
      likedAt: json['likedAt'] as String?,
    );
  }

  /// A saved row's asset. Pictures carry `url`; events carry their cover under
  /// `url` too, so both render as a tile. Anything without one is skipped.
  static ProfilePhoto? fromSavedAsset(
    Map<String, dynamic> asset, {
    required String assetType,
    String? savedItemId,
  }) {
    final url = asset['url'] as String?;
    if (url == null || url.isEmpty) return null;
    final isEvent = assetType == 'event';
    return ProfilePhoto(
      id: asset['id'] as String? ?? '',
      url: url,
      width: (asset['width'] ?? asset['coverWidth']) as int?,
      height: (asset['height'] ?? asset['coverHeight']) as int?,
      mediaType: asset['mediaType'] as String? ?? 'image',
      eventId: isEvent ? asset['id'] as String? : asset['eventId'] as String?,
      eventName: asset['eventName'] as String?,
      savedItemId: savedItemId,
      isEvent: isEvent,
    );
  }
}
