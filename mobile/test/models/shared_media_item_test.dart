import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/models/chat/shared_media.dart';

void main() {
  Map<String, dynamic> body({String? url, Object? isVideo = _absent}) => {
        'message_id': 'm1',
        'image_url': url ?? 'https://res.cloudinary.com/x/image/upload/v1/a.jpg',
        'sender_id': 's1',
        'created_at': '2026-08-18T10:00:00Z',
        if (isVideo != _absent) 'is_video': isVideo,
      };

  group('SharedMediaItem.isVideo', () {
    test("the sender's flag decides, whatever the url looks like", () {
      // A video stored under a key with a still-image extension: the URL says
      // photo, the sender said video. The sender is right.
      final item = SharedMediaItem.fromJson(
        body(url: 'https://cdn.example.com/chat_videos/abc.jpg', isVideo: true),
      );
      expect(item.isVideo, isTrue);

      final photo = SharedMediaItem.fromJson(
        body(url: 'https://cdn.example.com/chat_images/abc.mp4', isVideo: false),
      );
      expect(photo.isVideo, isFalse);
    });

    test('history written before the flag existed falls back to the url', () {
      expect(
        SharedMediaItem.fromJson(
          body(url: 'https://res.cloudinary.com/x/video/upload/v1/a.mp4'),
        ).isVideo,
        isTrue,
      );
      expect(SharedMediaItem.fromJson(body()).isVideo, isFalse);
    });

    test('an explicit null flag is treated as absent, not as false', () {
      expect(
        SharedMediaItem.fromJson(
          body(url: 'https://cdn.example.com/c/a.mp4', isVideo: null),
        ).isVideo,
        isTrue,
      );
    });
  });
}

const _absent = Object();
