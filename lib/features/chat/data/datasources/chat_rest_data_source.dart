import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/network/chat_api_client.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

abstract class ChatRestDataSource {
  /// GET /chat/rooms/global
  Future<ChatRoom> getGlobalRoom();

  /// GET /chat/rooms/event/{event_id}
  Future<ChatRoom> getEventRoom(String eventId);

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
}

class ChatRestDataSourceImpl implements ChatRestDataSource {
  final ChatApiClient _client;

  ChatRestDataSourceImpl(this._client);

  dio_pkg.Dio get _dio => _client.dio;

  @override
  Future<ChatRoom> getGlobalRoom() =>
      _getRoom('/chat/rooms/global');

  @override
  Future<ChatRoom> getEventRoom(String eventId) =>
      _getRoom('/chat/rooms/event/$eventId');

  @override
  Future<ChatRoom> getSampleRoom(String sampleId) =>
      _getRoom('/chat/rooms/sample/$sampleId');

  @override
  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
  }) async {
    return _wrap(() async {
      final res = await _dio.post(
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
      final res = await _dio.post(
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
      final res = await _dio.get('/chat/rooms');
      final list = res.data as List<dynamic>;
      return list
          .map((r) => ChatRoom.fromJson(r as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<ChatRoom> getRoom(String roomId) =>
      _getRoom('/chat/rooms/$roomId');

  @override
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  }) async {
    await _wrap(() async {
      await _dio.post(
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
      final res = await _dio.get(
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
      final formData = dio_pkg.FormData.fromMap({
        'file': await dio_pkg.MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      });
      final res = await _dio.post(
        '/chat/upload-image',
        data: formData,
        options: dio_pkg.Options(
          contentType: 'multipart/form-data',
        ),
      );
      final data = res.data as Map<String, dynamic>;
      return data['image_url'] as String;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<ChatRoom> _getRoom(String path) {
    return _wrap(() async {
      final res = await _dio.get(path);
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
