import 'package:jperg_app/core/utils/cloudinary_transform.dart';
import 'package:jperg_app/core/utils/server_time.dart';

/// One cell of the Shared Media grid.
class SharedMediaItem {
  /// The message this media came from, so tapping a cell can jump to it.
  final String messageId;
  final String url;
  final String senderId;
  final DateTime createdAt;

  /// What the sender said it was uploading. Null on messages written before the
  /// server recorded it — see [isVideo].
  final bool? isVideoFlag;

  const SharedMediaItem({
    required this.messageId,
    required this.url,
    required this.senderId,
    required this.createdAt,
    this.isVideoFlag,
  });

  /// Videos and photos live in the same grid; videos get a play badge.
  ///
  /// The sender's own flag wins wherever it exists — the URL is only ever a
  /// guess, and it guesses wrong for storage backends whose keys don't carry a
  /// meaningful extension. The heuristic stays as the fallback for the history
  /// that predates the flag, which is the same order [ChatMessage] uses.
  bool get isVideo => isVideoFlag ?? CloudinaryTransform.isVideoUrl(url);

  factory SharedMediaItem.fromJson(Map<String, dynamic> json) => SharedMediaItem(
        messageId: (json['message_id'] as String?) ?? '',
        url: (json['image_url'] as String?) ?? '',
        senderId: (json['sender_id'] as String?) ?? '',
        createdAt: parseServerTime(json['created_at'] as String),
        isVideoFlag: json['is_video'] as bool?,
      );
}

class SharedMediaPage {
  final List<SharedMediaItem> items;
  final bool hasMore;

  const SharedMediaPage({required this.items, required this.hasMore});

  static const empty = SharedMediaPage(items: [], hasMore: false);
}
