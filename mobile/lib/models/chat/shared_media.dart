import 'package:jperg_app/core/utils/cloudinary_transform.dart';

/// One cell of the Shared Media grid.
class SharedMediaItem {
  /// The message this media came from, so tapping a cell can jump to it.
  final String messageId;
  final String url;
  final String senderId;
  final DateTime createdAt;

  const SharedMediaItem({
    required this.messageId,
    required this.url,
    required this.senderId,
    required this.createdAt,
  });

  /// Videos and photos live in the same grid; videos get a play badge.
  bool get isVideo => CloudinaryTransform.isVideoUrl(url);

  factory SharedMediaItem.fromJson(Map<String, dynamic> json) => SharedMediaItem(
        messageId: (json['message_id'] as String?) ?? '',
        url: (json['image_url'] as String?) ?? '',
        senderId: (json['sender_id'] as String?) ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SharedMediaPage {
  final List<SharedMediaItem> items;
  final bool hasMore;

  const SharedMediaPage({required this.items, required this.hasMore});

  static const empty = SharedMediaPage(items: [], hasMore: false);
}
