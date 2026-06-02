import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

const _tag = '[FollowRepository]';

class FollowStats {
  final int followers;
  final int following;
  const FollowStats({required this.followers, required this.following});

  factory FollowStats.fromJson(Map<String, dynamic> json) => FollowStats(
        followers: (json['followers'] as num?)?.toInt() ?? 0,
        following: (json['following'] as num?)?.toInt() ?? 0,
      );
}

/// A single account in a following/followers list.
/// [notify] is only present in the *following* list (the follower's own
/// per-account push setting); it is null for followers entries.
class FollowEntry {
  final String id;
  final String type; // "photographer" | "client"
  final String name;
  final String? profileUrl;
  final bool? notify;
  final DateTime? followedAt;

  const FollowEntry({
    required this.id,
    required this.type,
    required this.name,
    this.profileUrl,
    this.notify,
    this.followedAt,
  });

  bool get isPhotographer => type == 'photographer';

  FollowEntry copyWith({bool? notify}) => FollowEntry(
        id: id,
        type: type,
        name: name,
        profileUrl: profileUrl,
        notify: notify ?? this.notify,
        followedAt: followedAt,
      );

  factory FollowEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parsedAt;
    final rawAt = json['followedAt'] ?? json['followed_at'];
    if (rawAt is String && rawAt.isNotEmpty) {
      parsedAt = DateTime.tryParse(rawAt)?.toLocal();
    }
    return FollowEntry(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      profileUrl: (json['profile_url'] as String?)?.isNotEmpty == true
          ? json['profile_url'] as String
          : null,
      notify: json['notify'] is bool ? json['notify'] as bool : null,
      followedAt: parsedAt,
    );
  }
}

/// One page of a follow list plus its pagination metadata.
class FollowPage {
  final List<FollowEntry> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const FollowPage({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  static const empty =
      FollowPage(data: [], page: 1, limit: 20, total: 0, totalPages: 0);
}

/// Wraps all /follow/photographer/* endpoints.
///
/// Maintains a session-local in-memory set of followed photographer IDs so
/// the main feed can pass [followedIds] to the recommender for boosting.
class FollowRepository {
  FollowRepository() {
    _dio = Api().dio;
  }

  late final Dio _dio;

  // In-memory cache for the session — updated optimistically on follow/unfollow.
  static final Set<String> _followedIds = {};

  /// Read-only snapshot of the currently followed photographer IDs.
  static Set<String> get followedIds => Set.unmodifiable(_followedIds);

  /// Seed the cache from feed responses that include is_followed.
  /// Safe to call multiple times — merges into the existing set.
  static void seedFollowed(Iterable<String> photographerIds) {
    _followedIds.addAll(photographerIds);
  }

  // ── Follow / Unfollow ─────────────────────────────────────────────────────

  /// POST /follow/photographer/{id} — also auto-subscribes to notifications.
  Future<void> follow(String photographerId) async {
    if (photographerId.isEmpty) return;
    debugPrint('$_tag follow → photographerId=$photographerId');
    _followedIds.add(photographerId); // optimistic
    try {
      final resp = await _dio.post('/follow/photographer/$photographerId');
      debugPrint('$_tag follow ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag follow ERROR: $e\n$st');
      _followedIds.remove(photographerId); // revert
      rethrow;
    }
  }

  /// DELETE /follow/photographer/{id}
  Future<void> unfollow(String photographerId) async {
    if (photographerId.isEmpty) return;
    debugPrint('$_tag unfollow → photographerId=$photographerId');
    _followedIds.remove(photographerId); // optimistic
    try {
      final resp = await _dio.delete('/follow/photographer/$photographerId');
      debugPrint('$_tag unfollow ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag unfollow ERROR: $e\n$st');
      _followedIds.add(photographerId); // revert
      rethrow;
    }
  }

  // ── Notification preference ───────────────────────────────────────────────

  /// PATCH /follow/photographer/{id}/notify?notify={value}
  Future<void> setNotify(String photographerId, {required bool notify}) async {
    if (photographerId.isEmpty) return;
    debugPrint('$_tag setNotify → photographerId=$photographerId notify=$notify');
    try {
      final resp = await _dio.patch(
        '/follow/photographer/$photographerId/notify',
        queryParameters: {'notify': notify},
      );
      debugPrint('$_tag setNotify ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag setNotify ERROR: $e\n$st');
    }
  }

  // ── Profile stats ─────────────────────────────────────────────────────────

  /// GET /follow/photographer/{id}/stats → { followers, following }
  Future<FollowStats> getStats(String photographerId) async {
    if (photographerId.isEmpty) {
      return const FollowStats(followers: 0, following: 0);
    }
    debugPrint('$_tag getStats → photographerId=$photographerId');
    try {
      final resp = await _dio.get('/follow/photographer/$photographerId/stats');
      debugPrint('$_tag getStats ← status=${resp.statusCode}');
      final raw = resp.data;
      final Map<String, dynamic> data;
      if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
        data = raw['data'] as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        data = {};
      }
      return FollowStats.fromJson(data);
    } catch (e, st) {
      debugPrint('$_tag getStats ERROR: $e\n$st');
      return const FollowStats(followers: 0, following: 0);
    }
  }

  // ── Following / followers lists (current user) ────────────────────────────

  /// GET /follow/following — accounts the current user follows (newest first).
  Future<FollowPage> getFollowing({int page = 1, int limit = 20}) =>
      _getList('/follow/following', page: page, limit: limit);

  /// GET /follow/followers — accounts following the current user (newest first).
  Future<FollowPage> getFollowers({int page = 1, int limit = 20}) =>
      _getList('/follow/followers', page: page, limit: limit);

  Future<FollowPage> _getList(String path,
      {required int page, required int limit}) async {
    debugPrint('$_tag getList $path → page=$page limit=$limit');
    try {
      final resp = await _dio.get(path, queryParameters: {
        'page': page,
        'limit': limit,
      });
      debugPrint('$_tag getList $path ← status=${resp.statusCode}');
      final raw = resp.data;
      Map<String, dynamic> body;
      if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
        // Some gateways double-wrap in { success, data: { data, pagination } }.
        body = raw['data'] as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        body = raw;
      } else {
        body = {};
      }

      final list = body['data'] is List ? body['data'] as List<dynamic> : const [];
      final entries = <FollowEntry>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            entries.add(FollowEntry.fromJson(item));
          } catch (e) {
            debugPrint('$_tag getList parse error: $e');
          }
        }
      }

      final pag = body['pagination'] is Map<String, dynamic>
          ? body['pagination'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final total = (pag['total'] as num?)?.toInt() ?? entries.length;
      final totalPages = (pag['totalPages'] as num?)?.toInt() ??
          (limit > 0 ? ((total + limit - 1) ~/ limit) : 1);

      return FollowPage(
        data: entries,
        page: (pag['page'] as num?)?.toInt() ?? page,
        limit: (pag['limit'] as num?)?.toInt() ?? limit,
        total: total,
        totalPages: totalPages,
      );
    } catch (e, st) {
      debugPrint('$_tag getList $path ERROR: $e\n$st');
      rethrow;
    }
  }

  /// PATCH /follow/{type}/{id}/notify — toggle per-account push for any type.
  Future<void> setNotifyFor(String type, String id,
      {required bool notify}) async {
    if (id.isEmpty) return;
    debugPrint('$_tag setNotifyFor → $type/$id notify=$notify');
    try {
      await _dio.patch('/follow/$type/$id/notify',
          queryParameters: {'notify': notify});
    } catch (e, st) {
      debugPrint('$_tag setNotifyFor ERROR: $e\n$st');
      rethrow;
    }
  }

  // ── Following feed ────────────────────────────────────────────────────────

  /// GET /follow/feed — chronological events from followed creators.
  ///
  /// Returns the parsed event list and a [hasMore] flag. The flag is derived
  /// from the server's own metadata when available (`hasMore`, `has_more`,
  /// or a `total` count), otherwise falls back to `events.length == limit`.
  Future<({List<EventDiscovery> events, bool hasMore})> getFollowFeed({
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint('$_tag getFollowFeed → page=$page limit=$limit');
    try {
      final resp = await _dio.get('/follow/feed', queryParameters: {
        'page': page,
        'limit': limit,
      });
      debugPrint('$_tag getFollowFeed ← status=${resp.statusCode}');
      final raw = resp.data;

      // ── Extract the list ──────────────────────────────────────────────────
      final List<dynamic> list;
      Map<String, dynamic>? meta;
      if (raw is Map<String, dynamic>) {
        meta = raw;
        if (raw['data'] is List) {
          list = raw['data'] as List<dynamic>;
        } else {
          // Try other common wrapper keys.
          List<dynamic>? found;
          for (final key in ['events', 'results', 'items']) {
            if (raw[key] is List) {
              found = raw[key] as List<dynamic>;
              break;
            }
          }
          list = found ?? [];
        }
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }

      // ── Parse events ──────────────────────────────────────────────────────
      final events = <EventDiscovery>[];
      for (final item in list) {
        try {
          events.add(EventDiscovery.fromMap(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('$_tag getFollowFeed parse error: $e');
        }
      }

      // ── Resolve hasMore ───────────────────────────────────────────────────
      bool hasMore;
      if (meta != null) {
        // Prefer explicit boolean flags from the server.
        final serverFlag = meta['hasMore'] ?? meta['has_more'];
        if (serverFlag is bool) {
          hasMore = serverFlag;
        } else {
          // Fall back to total count when present.
          final total = (meta['total'] as num?)?.toInt() ??
              (meta['pagination'] is Map
                  ? (meta['pagination']['total'] as num?)?.toInt()
                  : null);
          if (total != null) {
            hasMore = (page * limit) < total;
          } else {
            hasMore = events.length == limit;
          }
        }
      } else {
        hasMore = events.length == limit;
      }

      debugPrint(
          '$_tag getFollowFeed — ${events.length} events, hasMore=$hasMore');
      return (events: events, hasMore: hasMore);
    } catch (e, st) {
      debugPrint('$_tag getFollowFeed ERROR: $e\n$st');
      rethrow;
    }
  }
}
