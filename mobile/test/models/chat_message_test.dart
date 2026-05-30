import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';

Map<String, dynamic> _base(Map<String, dynamic> extra) => {
      'id': 'm1',
      'room_id': 'r1',
      'sender_id': 's1',
      'created_at': '2026-01-01T00:00:00Z',
      ...extra,
    };

void main() {
  group('ChatMessage getters', () {
    ChatMessage make({
      String role = 'user',
      DateTime? updatedAt,
      int? w,
      int? h,
      String name = 'Ama',
    }) =>
        ChatMessage(
          id: 'm1',
          roomId: 'r1',
          senderId: 's1',
          senderName: name,
          senderRole: role,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: updatedAt,
          mediaWidth: w,
          mediaHeight: h,
        );

    test('isEdited reflects updatedAt presence', () {
      expect(make().isEdited, isFalse);
      expect(make(updatedAt: DateTime(2026, 1, 2)).isEdited, isTrue);
    });

    test('isAdminMessage for admin and superAdmin roles', () {
      expect(make(role: 'admin').isAdminMessage, isTrue);
      expect(make(role: 'superAdmin').isAdminMessage, isTrue);
      expect(make(role: 'user').isAdminMessage, isFalse);
    });

    test('displayName masks admin sender name', () {
      expect(make(role: 'admin', name: 'Bob').displayName, 'Skidoo Admin');
      expect(make(role: 'user', name: 'Bob').displayName, 'Bob');
    });

    test('mediaAspectRatio computes only with valid dimensions', () {
      expect(make(w: 1280, h: 720).mediaAspectRatio, closeTo(1280 / 720, 1e-9));
      expect(make(w: null, h: 720).mediaAspectRatio, isNull);
      expect(make(w: 100, h: 0).mediaAspectRatio, isNull);
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses required fields with sensible defaults', () {
      final m = ChatMessage.fromJson(_base({}));
      expect(m.id, 'm1');
      expect(m.roomId, 'r1');
      expect(m.senderId, 's1');
      expect(m.senderName, '');
      expect(m.senderRole, ''); // tolerant default, not a throw
      expect(m.isRead, isFalse);
      expect(m.isVideo, isFalse);
    });

    test('treats is_video as bool true or int 1', () {
      expect(ChatMessage.fromJson(_base({'is_video': true})).isVideo, isTrue);
      expect(ChatMessage.fromJson(_base({'is_video': 1})).isVideo, isTrue);
      expect(ChatMessage.fromJson(_base({'is_video': 0})).isVideo, isFalse);
    });

    test('detects video by Cloudinary path even when flag is absent', () {
      final m = ChatMessage.fromJson(_base({
        'image_url': 'https://res.cloudinary.com/x/video/upload/v1/clip.mp4',
      }));
      expect(m.isVideo, isTrue);
    });

    test('detects video by file extension, ignoring query strings', () {
      final m = ChatMessage.fromJson(_base({
        'image_url': 'https://x/file.MOV?token=abc',
      }));
      expect(m.isVideo, isTrue);
    });

    test('filters read_by to strings only', () {
      final m = ChatMessage.fromJson(_base({
        'read_by': ['u1', 2, null, 'u2'],
      }));
      expect(m.readBy, ['u1', 'u2']);
    });

    test('parses reply_preview when present', () {
      final m = ChatMessage.fromJson(_base({
        'reply_preview': {'id': 'p1', 'sender_name': 'Kojo', 'content': 'hi'},
      }));
      expect(m.replyPreview, isNotNull);
      expect(m.replyPreview!.senderName, 'Kojo');
    });
  });

  group('ChatMessage.copyWith', () {
    test('clearUpdatedAt removes the edited timestamp', () {
      final edited = ChatMessage(
        id: 'm1',
        roomId: 'r1',
        senderId: 's1',
        senderRole: 'user',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );
      expect(edited.copyWith(clearUpdatedAt: true).updatedAt, isNull);
      expect(edited.copyWith(isRead: true).updatedAt, isNotNull);
    });
  });
}
