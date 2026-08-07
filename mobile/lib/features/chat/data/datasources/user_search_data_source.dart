import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

const int _kDefaultLimit = 25;

/// Result page returned by [UserSearchDataSource.search].
class UserSearchPage {
  final List<ShareableUser> users;

  /// Whether more pages are available.
  final bool hasMore;

  const UserSearchPage({required this.users, required this.hasMore});
}

/// Searches all app users (clients + photographers) via
///   GET /client/search?q=<query>&page=<page>&limit=<limit>
class UserSearchDataSource {
  final Api _api;

  UserSearchDataSource(this._api);

  Future<UserSearchPage> search(
    String query, {
    int page = 1,
    int limit = _kDefaultLimit,
  }) async {
    try {
      final res = await _api.dio.get<dynamic>(
        '/client/search',
        queryParameters: {'q': query, 'page': page, 'limit': limit},
      );

      final body = res.data;

      // Support both a wrapped envelope { data: [...], total: N }
      // and a bare list [...].
      final List<dynamic> list;
      int? total;

      if (body is List) {
        list = body;
      } else if (body is Map<String, dynamic>) {
        list = (body['data'] ?? body['users'] ?? body['results'] ?? []) as List<dynamic>;
        total = (body['total'] as num?)?.toInt();
      } else {
        list = [];
      }

      final users = list
          .whereType<Map<String, dynamic>>()
          .map(_parse)
          .where((u) => u.id.isNotEmpty)
          .toList();

      // hasMore: use total when available, otherwise assume more if the
      // page was full.
      final hasMore = total != null
          ? page * limit < total
          : users.length >= limit;

      return UserSearchPage(users: users, hasMore: hasMore);
    } on dio.DioException {
      return const UserSearchPage(users: [], hasMore: false);
    } catch (_) {
      return const UserSearchPage(users: [], hasMore: false);
    }
  }

  ShareableUser _parse(Map<String, dynamic> m) {
    final rawRole = (m['role'] ?? m['userType'] ?? m['type'] ?? '') as String;
    final role = rawRole == ChatConfig.rolePhotographer
        ? ChatConfig.rolePhotographer
        : ChatConfig.roleClient;

    return ShareableUser(
      id: (m['id'] ?? m['_id'] ?? '').toString(),
      name: (m['name'] ?? m['fullName'] ?? '').toString(),
      imageUrl: m['imageUrl'] as String? ?? m['avatarUrl'] as String?,
      role: role,
    );
  }
}
