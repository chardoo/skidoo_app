import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/models/photo_comment/photo_comment.dart';

/// REST comment data source for ads and requests.
/// targetType is 'ad' or 'request'.
abstract class FeedCommentDataSource {
  Future<List<PhotoComment>> getComments(
    String targetType,
    String targetId, {
    int page = 1,
    int limit = 20,
  });

  Future<PhotoComment> postComment(
    String targetType,
    String targetId,
    String content, {
    String? parentId,
  });

  Future<List<PhotoComment>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 20,
  });

  Future<PhotoComment> editComment(String commentId, String content);

  Future<void> deleteComment(String commentId);
}

class FeedCommentDataSourceImpl implements FeedCommentDataSource {
  FeedCommentDataSourceImpl(Api api) : _dio = api.dio;

  final Dio _dio;

  List<PhotoComment> _parseList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => PhotoComment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic>) {
      final list = data['comments'] as List? ??
          data['data'] as List? ??
          data['replies'] as List? ??
          [];
      return list
          .map((e) => PhotoComment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  PhotoComment _parseOne(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['comment'] ?? data['data'] ?? data;
      return PhotoComment.fromJson(inner as Map<String, dynamic>);
    }
    throw Exception('Unexpected comment response: ${data.runtimeType}');
  }

  @override
  Future<List<PhotoComment>> getComments(
    String targetType,
    String targetId, {
    int page = 1,
    int limit = 20,
  }) async {
    final url = '/chat/comments/$targetType/$targetId';
    debugPrint('[FeedComment] GET $url page=$page');
    try {
      final res =
          await _dio.get(url, queryParameters: {'page': page, 'limit': limit});
      return _parseList(res.data);
    } on DioException catch (e) {
      debugPrint(
          '[FeedComment] getComments ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception(
          'Failed to load comments: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<PhotoComment> postComment(
    String targetType,
    String targetId,
    String content, {
    String? parentId,
  }) async {
    final url = '/chat/comments/$targetType/$targetId';
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent_id'] = parentId;
    debugPrint('[FeedComment] POST $url body=$body');
    try {
      final res = await _dio.post(url, data: body);
      return _parseOne(res.data);
    } on DioException catch (e) {
      debugPrint(
          '[FeedComment] postComment ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception(
          'Failed to post comment: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<List<PhotoComment>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 20,
  }) async {
    final url = '/chat/comments/$commentId/replies';
    debugPrint('[FeedComment] GET $url');
    try {
      final res =
          await _dio.get(url, queryParameters: {'page': page, 'limit': limit});
      return _parseList(res.data);
    } on DioException catch (e) {
      debugPrint(
          '[FeedComment] getReplies ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception(
          'Failed to load replies: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<PhotoComment> editComment(String commentId, String content) async {
    final url = '/chat/comments/$commentId';
    debugPrint('[FeedComment] PUT $url');
    try {
      final res = await _dio.put(url, data: {'content': content});
      return _parseOne(res.data);
    } on DioException catch (e) {
      debugPrint(
          '[FeedComment] editComment ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception(
          'Failed to edit comment: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final url = '/chat/comments/$commentId';
    debugPrint('[FeedComment] DELETE $url');
    try {
      await _dio.delete(url);
    } on DioException catch (e) {
      debugPrint(
          '[FeedComment] deleteComment ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception(
          'Failed to delete comment: ${e.response?.data ?? e.message}');
    }
  }
}
