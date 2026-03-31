import 'dart:io';

import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

abstract class ChatRepository {
  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<ChatRoom> getGlobalRoom();
  Future<ChatRoom> getEventRoom(String eventId);
  Future<ChatRoom> getSampleRoom(String sampleId);

  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
    String? localDisplayName,
  });

  Future<ChatRoom> createEventPrivateRoom({
    required String eventId,
    String? name,
  });

  Future<List<ChatRoom>> getMyRooms();
  Future<List<ChatRoom>> getCachedRooms();
  Future<ChatRoom> getRoom(String roomId);

  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  });

  // ── Messages (REST / cache) ────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(
    String roomId, {
    String? beforeId,
    int limit,
  });

  Future<List<ChatMessage>> getCachedMessages(
    String roomId, {
    int limit,
  });

  /// Local-only: persist a single confirmed message to the cache.
  Future<void> cacheMessage(ChatMessage message);

  /// Local-only: count of unread messages per room (excludes own messages).
  Future<Map<String, int>> getUnreadCounts(String currentUserId);

  /// Local-only: mark all messages in [roomId] as read.
  Future<void> markRoomAsRead(String roomId);

  /// Upload an image file and return the hosted URL.
  Future<String> uploadImage(File file);
}
