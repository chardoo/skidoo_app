import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/models/photo_comment/photo_comment.dart';

abstract class PhotoCommentRemoteDataSource {
  Future<List<PhotoComment>> getComments(String pictureId,
      {int page = 1, int limit = 20});
  Future<PhotoComment> postComment(String pictureId, String content,
      {String? parentId});
  Future<List<PhotoComment>> getReplies(String commentId,
      {int page = 1, int limit = 20});
  Future<PhotoComment> editComment(String commentId, String content);
  Future<void> deleteComment(String commentId);
  Future<({bool liked, int likes})> toggleLike(String pictureId);
  Future<({bool liked, int likes})> getLikeStatus(
      String pictureId, String userId);
}

class PhotoCommentRemoteDataSourceImpl implements PhotoCommentRemoteDataSource {
  PhotoCommentRemoteDataSourceImpl(Api api) : _dio = api.dio;

  final Dio _dio;

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<PhotoComment> _parseCommentList(dynamic data) {
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

  PhotoComment _parseComment(dynamic data) {
    if (data is Map<String, dynamic>) {
      // Unwrap common server envelope keys.
      final inner = data['comment'] ?? data['data'] ?? data;
      return PhotoComment.fromJson(inner as Map<String, dynamic>);
    }
    throw Exception('Unexpected comment response type: ${data.runtimeType}');
  }

  // ── API calls ──────────────────────────────────────────────────────────────

  @override
  Future<List<PhotoComment>> getComments(String pictureId,
      {int page = 1, int limit = 20}) async {
    final url = '/chat/comments/photo/$pictureId';
    debugPrint('[PhotoComment] GET $url  page=$page limit=$limit  pictureId=$pictureId');
    try {
      final response = await _dio.get(
        url,
        queryParameters: {'page': page, 'limit': limit},
      );
      debugPrint('[PhotoComment] getComments status=${response.statusCode}  body=${response.data}');
      return _parseCommentList(response.data);
    } on DioException catch (e) {
      debugPrint('[PhotoComment] getComments ERROR  status=${e.response?.statusCode}  body=${e.response?.data}  msg=${e.message}');
      throw Exception(
          'Failed to load comments: ${e.response?.data ?? e.message}');
    } catch (e) {
      debugPrint('[PhotoComment] getComments PARSE ERROR: $e');
      rethrow;
    }
  }

  @override
  Future<PhotoComment> postComment(String pictureId, String content,
      {String? parentId}) async {
    final url = '/chat/comments/photo/$pictureId';
    final body = <String, dynamic>{'content': content};
    if (parentId != null) body['parent_id'] = parentId;
    debugPrint('[PhotoComment] POST $url  body=$body  pictureId=$pictureId');
    try {
      final response = await _dio.post(url, data: body);
      debugPrint('[PhotoComment] postComment status=${response.statusCode}  body=${response.data}');
      return _parseComment(response.data);
    } on DioException catch (e) {
      debugPrint('[PhotoComment] postComment ERROR  status=${e.response?.statusCode}  body=${e.response?.data}  msg=${e.message}');
      throw Exception(
          'Failed to post comment: ${e.response?.data ?? e.message}');
    } catch (e) {
      debugPrint('[PhotoComment] postComment PARSE ERROR: $e');
      rethrow;
    }
  }

  @override
  Future<List<PhotoComment>> getReplies(String commentId,
      {int page = 1, int limit = 20}) async {
    final url = '/chat/comments/$commentId/replies';
    debugPrint('[PhotoComment] GET $url  commentId=$commentId');
    try {
      final response = await _dio.get(
        url,
        queryParameters: {'page': page, 'limit': limit},
      );
      debugPrint('[PhotoComment] getReplies status=${response.statusCode}  body=${response.data}');
      return _parseCommentList(response.data);
    } on DioException catch (e) {
      debugPrint('[PhotoComment] getReplies ERROR  status=${e.response?.statusCode}  body=${e.response?.data}');
      throw Exception(
          'Failed to load replies: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<PhotoComment> editComment(String commentId, String content) async {
    final url = '/chat/comments/$commentId';
    debugPrint('[PhotoComment] PUT $url  commentId=$commentId');
    try {
      final response = await _dio.put(url, data: {'content': content});
      debugPrint('[PhotoComment] editComment status=${response.statusCode}  body=${response.data}');
      return _parseComment(response.data);
    } on DioException catch (e) {
      debugPrint('[PhotoComment] editComment ERROR  status=${e.response?.statusCode}  body=${e.response?.data}');
      throw Exception(
          'Failed to edit comment: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final url = '/chat/comments/$commentId';
    debugPrint('[PhotoComment] DELETE $url  commentId=$commentId');
    try {
      final response = await _dio.delete(url);
      debugPrint('[PhotoComment] deleteComment status=${response.statusCode}');
    } on DioException catch (e) {
      debugPrint('[PhotoComment] deleteComment ERROR  status=${e.response?.statusCode}  body=${e.response?.data}');
      throw Exception(
          'Failed to delete comment: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<({bool liked, int likes})> toggleLike(String pictureId) async {
    final url = '/chat/pictures/$pictureId/like';
    debugPrint('[PhotoComment] POST $url  (toggleLike)  pictureId=$pictureId');
    try {
      final response = await _dio.post(url);
      debugPrint('[PhotoComment] toggleLike status=${response.statusCode}  body=${response.data}');
      final data = response.data as Map<String, dynamic>;
      return (
        liked: data['liked'] as bool? ?? false,
        likes: (data['likes'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      debugPrint('[PhotoComment] toggleLike ERROR  status=${e.response?.statusCode}  body=${e.response?.data}');
      throw Exception(
          'Failed to toggle like: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<({bool liked, int likes})> getLikeStatus(
      String pictureId, String userId) async {
    final url = '/chat/pictures/$pictureId/like';
    debugPrint('[PhotoComment] GET $url  userId=$userId  pictureId=$pictureId');
    try {
      final response = await _dio.get(
        url,
        queryParameters: {'userId': userId},
      );
      debugPrint('[PhotoComment] getLikeStatus status=${response.statusCode}  body=${response.data}');
      final data = response.data as Map<String, dynamic>;
      return (
        liked: data['liked'] as bool? ?? false,
        likes: (data['likes'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      debugPrint('[PhotoComment] getLikeStatus ERROR  status=${e.response?.statusCode}  body=${e.response?.data}');
      throw Exception(
          'Failed to get like status: ${e.response?.data ?? e.message}');
    }
  }
}
