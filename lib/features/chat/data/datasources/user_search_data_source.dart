import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/models/chat/shareable_user.dart';

/// Searches app users (clients + photographers) by name/email query.
///
/// Endpoints used:
///   POST /client/photographers   body: {"queryString": "<query>"}
///   POST /client/clients         body: {"queryString": "<query>"}
///
/// Both are called in parallel; results are merged and sorted by name.
class UserSearchDataSource {
  final Api _api;

  UserSearchDataSource(this._api);

  Future<List<ShareableUser>> search(String query) async {
    final body = jsonEncode({'queryString': query});

    final results = await Future.wait([
      _searchRole('/client/photographers', ChatConfig.rolePhotographer, body),
      _searchRole('/client/clients', ChatConfig.roleClient, body),
    ]);

    final merged = [...results[0], ...results[1]];
    merged.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  Future<List<ShareableUser>> _searchRole(
    String path,
    String role,
    String body,
  ) async {
    try {
      final res = await _api.dio.post(path, data: body);
      final list = res.data as List<dynamic>;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return ShareableUser(
          id: (m['id'] ?? m['_id'] ?? '') as String,
          name: (m['name'] ?? '') as String,
          email: (m['email'] ?? '') as String,
          imageUrl: m['imageUrl'] as String?,
          role: role,
        );
      }).where((u) => u.id.isNotEmpty).toList();
    } on dio.DioException {
      // If one role endpoint fails, still return results from the other.
      return [];
    } catch (_) {
      return [];
    }
  }
}
