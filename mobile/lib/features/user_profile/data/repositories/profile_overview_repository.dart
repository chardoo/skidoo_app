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

  /// Photos the user liked, newest like first.
  Future<List<ProfilePhoto>> getLikedPhotos({int page = 1, int limit = 30}) async {
    final resp = await _dio.get('/client/my-likes', queryParameters: {
      'type': 'pictures',
      'page': page,
      'limit': limit,
    });
    return _listUnder(resp.data, 'data').map(ProfilePhoto.fromJson).toList();
  }

  /// Bookmarked photos. The endpoint carries the client id in the path and
  /// only ever serves the caller's own, so the id has to be the signed-in one.
  Future<List<ProfilePhoto>> getBookmarkedPhotos(
    String userId, {
    int page = 1,
    int limit = 30,
  }) async {
    final resp = await _dio.get('/client/$userId/saved', queryParameters: {
      'assetType': 'picture',
      'page': page,
      'limit': limit,
    });
    // A saved row wraps the picture it points at; a picture deleted since it
    // was bookmarked comes back with no asset at all, so those are dropped.
    return _listUnder(resp.data, 'data')
        .map((row) => row['asset'])
        .whereType<Map<String, dynamic>>()
        .map(ProfilePhoto.fromJson)
        .toList();
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
    );
  }
}
