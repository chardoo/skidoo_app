import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/API/dio_client_service.dart';
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
