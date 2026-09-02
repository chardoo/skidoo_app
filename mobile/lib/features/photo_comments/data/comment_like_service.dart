import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:jperg_app/api/dio_client_service.dart';

/// The heart on a comment row.
///
/// A toggle rather than two verbs, for the reason the campaign heart is one:
/// the control is a single button in two states, and a client should not have
/// to choose between like and unlike from a count it may have loaded minutes
/// ago. The server owns the decision and reports where it landed.
///
/// Comment likes are rows in `chat_asset_likes` alongside campaign likes —
/// same table, `target_type = 'comment'` — so this is the same endpoint the ads
/// card already calls with a different noun in the path.
class CommentLikeService {
  CommentLikeService({Dio? dio}) : _dio = dio ?? Api().dio;

  final Dio _dio;

  static const _tag = '[CommentLike]';

  /// Returns where the like landed, or null when the call did not land at all.
  ///
  /// Null is not "unliked" — the caller has an optimistic state on screen and
  /// needs to tell "the server disagreed" from "the server never answered", so
  /// it can put the heart back rather than invent a number.
  Future<({bool liked, int likes})?> toggle(String commentId) async {
    if (commentId.isEmpty) return null;
    try {
      final resp = await _dio.post('/chat/likes/comment/$commentId');
      final body = resp.data;
      final data = (body is Map && body['data'] is Map)
          ? Map<String, dynamic>.from(body['data'] as Map)
          : <String, dynamic>{};
      return (
        liked: data['liked'] as bool? ?? false,
        likes: (data['likes'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('$_tag toggle ERROR commentId=$commentId: $e');
      return null;
    }
  }
}
