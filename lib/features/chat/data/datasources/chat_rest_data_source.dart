import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
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

  /// PUT /chat/rooms/{room_id}/messages/{message_id} — edit a message's content.
  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String content,
  });

  /// DELETE /chat/rooms/{room_id}/messages/{message_id} — delete a message.
  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  });

  /// POST /chat/rooms/group — create a group room with optional initial invitees.
  Future<ChatRoom> createGroupRoom({
    required String name,
    List<String>? inviteeIds,
  });

  /// POST /chat/rooms/{room_id}/join — accept a pending invite.
  Future<void> acceptRoomInvite(String roomId);

  /// DELETE /chat/rooms/{room_id}/invite — decline or leave a pending invite.
  Future<void> declineRoomInvite(String roomId);

  /// POST /chat/rooms/{room_id}/admins/{user_id} — grant admin to an active member.
  Future<void> grantAdmin(String roomId, String userId);

  /// DELETE /chat/rooms/{room_id}/admins/{user_id} — revoke admin (blocked if last admin).
  Future<void> revokeAdmin(String roomId, String userId);

  /// PATCH /chat/rooms/{room_id}/settings — update room-level settings.
  Future<void> updateRoomSettings(String roomId, {bool? adminOnly, String? name});

  /// DELETE /chat/rooms/{room_id}/participants/{user_id} — kick a non-admin participant.
  Future<void> kickParticipant(String roomId, String userId);

  /// DELETE /chat/rooms/{room_id}/leave — leave the room.
  /// Returns true when the room was also deleted (sole-admin case).
  Future<bool> leaveRoom(String roomId);

  /// DELETE /chat/rooms/{room_id} — permanently delete a group room (sole admin only).
  Future<void> deleteRoom(String roomId);

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

  /// GET /chat/events/reactions/batch?eventIds=id1,id2,...&userId=xxx
  /// Returns reactions for multiple events in one call.
  Future<Map<String, EventReaction>> getEventReactionsBatch(
      List<String> eventIds, String userId);

  /// GET /chat/pictures/{pictureId}/like — returns current like state.
  Future<PictureReaction> getPictureLike(String pictureId);

  /// POST /chat/pictures/{pictureId}/like — toggles like, returns updated state.
  Future<PictureReaction> togglePictureLike(String pictureId);

  // ── Privacy features ───────────────────────────────────────────────────────

  /// GET /chat/features — returns active feature names list.
  Future<Map<String, bool>> getFeatures();

  /// POST /chat/features/anonymous_comments
  Future<void> enableAnonymousMode();

  /// DELETE /chat/features/anonymous_comments
  Future<void> disableAnonymousMode();

  /// POST /chat/features/hide_profile
  Future<void> enableHideProfile();

  /// DELETE /chat/features/hide_profile
  Future<void> disableHideProfile();

  /// GET /chat/blocks — returns list of blocked user IDs
  Future<List<String>> getBlockedUsers();

  /// POST /chat/blocks/{userId}
  Future<void> blockUser(String userId);

  /// DELETE /chat/blocks/{userId}
  Future<void> unblockUser(String userId);
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
      final res = await _client.dio.get(
        '/chat/rooms',
        queryParameters: {'page': 1, 'limit': 25},
      );
      final raw = res.data;
      final List<dynamic> list;
      if (raw is Map<String, dynamic> && raw['data'] is List) {
        list = raw['data'] as List<dynamic>;
      } else if (raw is List) {
        list = raw;
      } else {
        list = [];
      }
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
  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String content,
  }) async {
    await _wrap(() => _client.dio.put(
          '/chat/rooms/$roomId/messages/$messageId',
          data: jsonEncode({'content': content}),
        ));
  }

  @override
  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    await _wrap(
        () => _client.dio.delete('/chat/rooms/$roomId/messages/$messageId'));
  }

  @override
  Future<ChatRoom> createGroupRoom({
    required String name,
    List<String>? inviteeIds,
  }) async {
    debugPrint('[ChatREST] POST /chat/rooms/group name="$name" invitees=$inviteeIds');
    return _wrap(() async {
      final res = await _client.dio.post(
        '/chat/rooms/group',
        data: jsonEncode({
          'name': name,
          if (inviteeIds != null && inviteeIds.isNotEmpty)
            'invitee_ids': inviteeIds,
        }),
      );
      final room = ChatRoom.fromJson(res.data as Map<String, dynamic>);
      debugPrint('[ChatREST] group created — id=${room.id} participants=${room.participants.length}');
      return room;
    });
  }

  @override
  Future<void> acceptRoomInvite(String roomId) async {
    debugPrint('[ChatREST] POST /chat/rooms/$roomId/join');
    await _wrap(() => _client.dio.post('/chat/rooms/$roomId/join'));
    debugPrint('[ChatREST] invite accepted — roomId=$roomId');
  }

  @override
  Future<void> declineRoomInvite(String roomId) async {
    debugPrint('[ChatREST] DELETE /chat/rooms/$roomId/invite');
    await _wrap(() => _client.dio.delete('/chat/rooms/$roomId/invite'));
    debugPrint('[ChatREST] invite declined — roomId=$roomId');
  }

  @override
  Future<void> grantAdmin(String roomId, String userId) async {
    debugPrint('[ChatREST] POST /chat/rooms/$roomId/admins/$userId');
    await _wrap(() => _client.dio.post('/chat/rooms/$roomId/admins/$userId'));
  }

  @override
  Future<void> revokeAdmin(String roomId, String userId) async {
    debugPrint('[ChatREST] DELETE /chat/rooms/$roomId/admins/$userId');
    await _wrap(() => _client.dio.delete('/chat/rooms/$roomId/admins/$userId'));
  }

  @override
  Future<void> updateRoomSettings(String roomId, {bool? adminOnly, String? name}) async {
    final payload = <String, dynamic>{
      if (adminOnly != null) 'admin_only': adminOnly,
      if (name != null) 'name': name,
    };
    debugPrint('[ChatREST] PATCH /chat/rooms/$roomId/settings $payload');
    await _wrap(() => _client.dio.patch(
          '/chat/rooms/$roomId/settings',
          data: jsonEncode(payload),
        ));
  }

  @override
  Future<void> kickParticipant(String roomId, String userId) async {
    debugPrint('[ChatREST] DELETE /chat/rooms/$roomId/participants/$userId');
    await _wrap(() => _client.dio.delete('/chat/rooms/$roomId/participants/$userId'));
  }

  @override
  Future<bool> leaveRoom(String roomId) async {
    debugPrint('[ChatREST] DELETE /chat/rooms/$roomId/leave');
    final res = await _wrap(() => _client.dio.delete('/chat/rooms/$roomId/leave'));
    final deleted = res.data?['deleted'] == true;
    debugPrint('[ChatREST] left room — roomId=$roomId deleted=$deleted');
    return deleted;
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    debugPrint('[ChatREST] DELETE /chat/rooms/$roomId');
    await _wrap(() => _client.dio.delete('/chat/rooms/$roomId'));
    debugPrint('[ChatREST] room deleted — roomId=$roomId');
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
        case 'mp4':
          contentType = 'video/mp4';
          break;
        case 'mov':
          contentType = 'video/quicktime';
          break;
        case 'avi':
          contentType = 'video/x-msvideo';
          break;
        case 'mkv':
          contentType = 'video/x-matroska';
          break;
        case 'webm':
          contentType = 'video/webm';
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

      final isVideo = contentType.startsWith('video/');
      final uploadTimeout =
          Duration(minutes: isVideo ? 3 : 1);
      final res = await _client.dio.post(
        '/chat/upload-image',
        data: formData,
        options: dio_pkg.Options(
          sendTimeout: uploadTimeout,
          receiveTimeout: uploadTimeout,
        ),
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
  Future<Map<String, EventReaction>> getEventReactionsBatch(
      List<String> eventIds, String userId) async {
    return _wrap(() async {
      debugPrint('[ChatRest] reactionsBatch → ${eventIds.length} ids userId=$userId');
      final res = await _client.dio.get(
        '/chat/events/reactions/batch',
        queryParameters: {
          'eventIds': eventIds.join(','),
          'userId': userId,
        },
      );
      debugPrint('[ChatRest] reactionsBatch ← ${res.statusCode} type=${res.data.runtimeType}');

      // Server may return { "data": { id: reaction } } or the flat map directly.
      Map<String, dynamic> raw;
      final body = res.data;
      if (body is Map<String, dynamic>) {
        final inner = body['data'];
        raw = (inner is Map<String, dynamic>) ? inner : body;
      } else {
        debugPrint('[ChatRest] reactionsBatch — unexpected body type, returning empty');
        return {};
      }

      debugPrint('[ChatRest] reactionsBatch — ${raw.length} entries: ${raw.keys.take(3).join(', ')}…');

      final result = <String, EventReaction>{};
      for (final e in raw.entries) {
        try {
          if (e.value is Map<String, dynamic>) {
            result[e.key] = EventReaction.fromJson(e.value as Map<String, dynamic>);
          }
        } catch (ex) {
          debugPrint('[ChatRest] reactionsBatch parse error key=${e.key}: $ex');
        }
      }
      debugPrint('[ChatRest] reactionsBatch — parsed ${result.length} reactions');
      return result;
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

  // ── Privacy features ──────────────────────────────────────────────────────

  @override
  Future<Map<String, bool>> getFeatures() => _wrap(() async {
        final res = await _client.dio.get('/chat/features');
        final data = res.data as Map<String, dynamic>;
        // Response: { "features": ["hide_profile", "anonymous_comments"] }
        final active = (data['features'] as List<dynamic>? ?? [])
            .map((f) => f.toString())
            .toSet();
        return {
          'anonymous_comments': active.contains('anonymous_comments'),
          'hide_profile': active.contains('hide_profile'),
        };
      });

  @override
  Future<void> enableAnonymousMode() =>
      _wrap(() => _client.dio.post('/chat/features/anonymous_comments'));

  @override
  Future<void> disableAnonymousMode() =>
      _wrap(() => _client.dio.delete('/chat/features/anonymous_comments'));

  @override
  Future<void> enableHideProfile() =>
      _wrap(() => _client.dio.post('/chat/features/hide_profile'));

  @override
  Future<void> disableHideProfile() =>
      _wrap(() => _client.dio.delete('/chat/features/hide_profile'));

  @override
  Future<List<String>> getBlockedUsers() => _wrap(() async {
        final resp = await _client.dio.get('/chat/blocks');
        final data = resp.data;
        if (data is List) {
          return data.map((e) => e['blocked_id']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        }
        return <String>[];
      });

  @override
  Future<void> blockUser(String userId) =>
      _wrap(() => _client.dio.post('/chat/blocks/$userId'));

  @override
  Future<void> unblockUser(String userId) =>
      _wrap(() => _client.dio.delete('/chat/blocks/$userId'));

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
