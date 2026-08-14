import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';

/// Manages picture likes via REST  (POST/GET /chat/pictures/{id}/like).
///
/// The backend stores likes in Redis and flushes to the DB every 60 s,
/// mirroring the event-reaction pattern exactly.
class PictureLikeService {
  PictureLikeService(this._rest);

  final ChatRestDataSource _rest;

  /// Toggle like for [pictureId]. Returns the updated [PictureReaction].
  /// Swallows errors so callers can treat it as fire-and-forget.
  Future<PictureReaction> toggleLike(String pictureId) async {
    try {
      final reaction = await _rest.togglePictureLike(pictureId);
      // The profile's Liked tab keeps its grid between visits, so a like made
      // out here is only visible there because of this.
      AppCacheSignals.likes.bump();
      return reaction;
    } catch (e) {
      debugPrint('[PictureLike] toggleLike error: $e');
      return PictureReaction.empty();
    }
  }

  /// Fetch the current like state for [pictureId].
  Future<PictureReaction> getLike(String pictureId) async {
    try {
      return await _rest.getPictureLike(pictureId);
    } catch (e) {
      debugPrint('[PictureLike] getLike error: $e');
      return PictureReaction.empty();
    }
  }
}
