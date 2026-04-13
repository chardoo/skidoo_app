import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/network/chat_api_client.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:http_parser/http_parser.dart';
/// Reaction state for an event (from GET /chat/events/{id}/reaction).
class EventReaction {
  final String? userReaction; // 'like', 'dislike', or null
  final int likes;
  final int dislikes;

  const EventReaction({
    this.userReaction,
    required this.likes,
    required this.dislikes,
  });

  factory EventReaction.empty() =>
      const EventReaction(likes: 0, dislikes: 0);

  factory EventReaction.fromJson(Map<String, dynamic> json) {
    final reaction = json['reaction'] as String?;
    return EventReaction(
      userReaction: (reaction == null || reaction == 'none') ? null : reaction,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      dislikes: (json['dislikes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Like state for a picture (from GET/POST /chat/pictures/{id}/like).
class PictureReaction {
  final bool isLiked;
  final int likes;

  const PictureReaction({required this.isLiked, required this.likes});

  factory PictureReaction.empty() =>
      const PictureReaction(isLiked: false, likes: 0);

  factory PictureReaction.fromJson(Map<String, dynamic> json) {
    // Supports { liked: bool, likes: N } and { reaction: 'like'|'none', likes: N }
    final reaction = json['reaction'] as String? ?? json['userReaction'] as String?;
    final liked = json['liked'] as bool? ?? (reaction == 'like');
    return PictureReaction(
      isLiked: liked,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class ChatRestDataSource {
  /// GET /chat/rooms/global
  Future<ChatRoom> getGlobalRoom();

  /// GET /chat/rooms/event/{event_id}
  Future<ChatRoom> getEventRoom(String eventId);
  Future<ChatRoom> getPhotoRoom(String pictureId);

  /// GET /chat/rooms/sample/{sample_id}
  Future<ChatRoom> getSampleRoom(String sampleId);

  /// POST /chat/rooms/direct
  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
  });

  /// POST /chat/rooms/event-private
  Future<ChatRoom> createEventPrivateRoom({
    required String eventId,
    String? name,
  });

  /// GET /chat/rooms
  Future<List<ChatRoom>> getMyRooms();

  /// GET /chat/rooms/{room_id}
  Future<ChatRoom> getRoom(String roomId);

  /// POST /chat/rooms/{room_id}/invite
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  });

  /// GET /chat/rooms/{room_id}/messages?before_id=&limit=
  Future<List<ChatMessage>> getMessages(
    String roomId, {
    String? beforeId,
    int limit = ChatConfig.messagePageSize,
  });

  /// POST /chat/upload-image — uploads [file] and returns the Cloudinary URL.
  Future<String> uploadImage(File file);

  /// GET /chat/events/{eventId}/reaction?userId=<userId>
  /// Returns the user's current reaction and aggregate counts.
  Future<EventReaction> getEventReaction(String eventId, String userId);

  /// GET /chat/pictures/{pictureId}/like — returns current like state.
  Future<PictureReaction> getPictureLike(String pictureId);

  /// POST /chat/pictures/{pictureId}/like — toggles like, returns updated state.
  Future<PictureReaction> togglePictureLike(String pictureId);
}

class ChatRestDataSourceImpl implements ChatRestDataSource {
  final ChatApiClient _client;

  ChatRestDataSourceImpl(this._client);

  @override
  Future<ChatRoom> getGlobalRoom() => _getRoom('/chat/rooms/global');

  @override
  Future<ChatRoom> getEventRoom(String eventId) =>
      _getRoom('/chat/rooms/event/$eventId');

  @override
  Future<ChatRoom> getPhotoRoom(String pictureId) =>
      _getRoom('/chat/rooms/photo/$pictureId');

  @override
  Future<ChatRoom> getSampleRoom(String sampleId) =>
      _getRoom('/chat/rooms/sample/$sampleId');

  @override
  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
  }) async {
    return _wrap(() async {
      final res = await _client.dio.post(
        '/chat/rooms/direct',
        data: jsonEncode({
          'recipient_id': recipientId,
          'recipient_role': recipientRole,
        }),
      );
      return ChatRoom.fromJson(res.data as Map<String, dynamic>);
    });
  }

  @override
  Future<ChatRoom> createEventPrivateRoom({
    required String eventId,
    String? name,
  }) async {
    return _wrap(() async {
      final res = await _client.dio.post(
        '/chat/rooms/event-private',
        data: jsonEncode({
          'event_id': eventId,
          if (name != null) 'name': name,
        }),
      );
      return ChatRoom.fromJson(res.data as Map<String, dynamic>);
    });
  }

  @override
  Future<List<ChatRoom>> getMyRooms() async {
    return _wrap(() async {
      final res = await _client.dio.get('/chat/rooms');
      final list = res.data as List<dynamic>;
      return list
          .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<ChatRoom> getRoom(String roomId) => _getRoom('/chat/rooms/$roomId');

  @override
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  }) async {
    await _wrap(() async {
      await _client.dio.post(
        '/chat/rooms/$roomId/invite',
        queryParameters: {
          'invitee_id': inviteeId,
          'invitee_role': inviteeRole,
        },
      );
    });
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String roomId, {
    String? beforeId,
    int limit = ChatConfig.messagePageSize,
  }) async {
    return _wrap(() async {
      final res = await _client.dio.get(
        '/chat/rooms/$roomId/messages',
        queryParameters: {
          'limit': limit,
          if (beforeId != null) 'before_id': beforeId,
        },
      );
      final list = res.data as List<dynamic>;
      return list
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<String> uploadImage(File file) async {
    return _wrap(() async {
      // Get file extension and determine content type
      final extension = file.path.split('.').last.toLowerCase();
      String contentType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        case 'webp':
          contentType = 'image/webp';
          break;
        case 'gif':
          contentType = 'image/gif';
          break;
        default:
          throw Exception('Unsupported file type: $extension');
      }

      final multipartFile = await dio_pkg.MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
         contentType: MediaType.parse(contentType)
      );

      final formData = dio_pkg.FormData.fromMap({
        'file': multipartFile,
      });

      // Don't manually set contentType - let Dio handle it
      final res = await _client.dio.post(
        '/chat/upload-image',
        data: formData,
      );

      final data = res.data as Map<String, dynamic>;
      return data['url'] as String; // Changed from 'image_url' to 'url'
    });
  }
  @override
  Future<EventReaction> getEventReaction(String eventId, String userId) async {
    return _wrap(() async {
      final res = await _client.dio.get(
        '/chat/events/$eventId/reaction',
        queryParameters: {'userId': userId},
      );
      return EventReaction.fromJson(res.data as Map<String, dynamic>);
    });
  }

  @override
  Future<PictureReaction> getPictureLike(String pictureId) async {
    return _wrap(() async {
      final res = await _client.dio.get('/chat/pictures/$pictureId/like');
      return PictureReaction.fromJson(res.data as Map<String, dynamic>);
    });
  }

  @override
  Future<PictureReaction> togglePictureLike(String pictureId) async {
    return _wrap(() async {
      final res = await _client.dio.post('/chat/pictures/$pictureId/like');
      return PictureReaction.fromJson(res.data as Map<String, dynamic>);
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<ChatRoom> _getRoom(String path) {
    return _wrap(() async {
      final res = await _client.dio.get(path);
      return ChatRoom.fromJson(res.data as Map<String, dynamic>);
    });
  }

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on dio_pkg.DioException catch (e) {
      if (e.response == null) throw const NetworkException();
      throw ServerException(
          'Chat API error ${e.response?.statusCode}: ${e.response?.data}');
    } catch (e) {
      if (e is NetworkException || e is ServerException) rethrow;
      throw ServerException('Unexpected chat error: $e');
    }
  }
}
