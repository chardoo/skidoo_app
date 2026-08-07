import 'dart:io';

import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

abstract class ChatRepository {
  // ── Rooms ──────────────────────────────────────────────────────────────────

  Future<ChatRoom> getGlobalRoom();
  Future<ChatRoom> getEventRoom(String eventId);
  Future<Map<String, ChatRoom>> getEventRoomsBatch(List<String> eventIds);
  Future<ChatRoom> getPhotoRoom(String pictureId);
  Future<ChatRoom> getSampleRoom(String sampleId);

  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
    String? localDisplayName,
  });

  /// Whether the current user may start a DM with [targetUserId] (block /
  /// existing-conversation / hide_profile checks, mirrored from the server).
  Future<CanMessageResult> canMessage(String targetUserId);

  Future<ChatRoom> createEventPrivateRoom({
    required String eventId,
    String? name,
  });

  Future<List<ChatRoom>> getMyRooms();
  Future<List<ChatRoom>> getCachedRooms();
  Future<ChatRoom> getRoom(String roomId);

  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String content,
  });

  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  });

  /// Local-only: update content + updatedAt for an edited message.
  Future<void> updateCachedMessage(
      String messageId, String content, DateTime updatedAt);

  /// Local-only: remove a deleted message from cache.
  Future<void> deleteCachedMessage(String messageId);

  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
    String? inviteeName,
  });

  Future<ChatRoom> createGroupRoom({
    required String name,
    List<String>? inviteeIds,
    Map<String, String>? inviteeNames,
  });

  Future<void> acceptRoomInvite(String roomId);

  Future<void> declineRoomInvite(String roomId);

  Future<void> grantAdmin(String roomId, String userId);

  Future<void> revokeAdmin(String roomId, String userId);

  Future<void> updateRoomSettings(String roomId, {bool? adminOnly, String? name});

  Future<void> kickParticipant(String roomId, String userId);

  /// DELETE /chat/rooms/{room_id}/leave — leave the room.
  /// Returns true when the room was also deleted (sole-admin case).
  Future<bool> leaveRoom(String roomId);

  /// DELETE /chat/rooms/{room_id} — permanently delete a group room.
  Future<void> deleteRoom(String roomId);

  /// Local-only: remove a room and all its cached messages from the DB.
  /// Called when a WS event signals the room is gone for the current user
  /// (room_deleted broadcast, participant_removed for self).
  Future<void> clearRoomCache(String roomId);

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

  /// Local-only: timestamp of the most recent message per room.
  Future<Map<String, DateTime>> getLastMessageTimes();

  /// Local-only: mark all messages in [roomId] as read.
  Future<void> markRoomAsRead(String roomId);

  /// Upload an image file and return the hosted URL.
  /// [mimeType] is the MIME type; on web it comes from the browser File API.
  Future<String> uploadImage(File file, {String? mimeType});

  /// GET /chat/events/{eventId}/reaction — user's reaction + aggregate counts.
  Future<EventReaction> getEventReaction(String eventId, String userId);

  /// GET /chat/events/reactions/batch — reactions for many events in one call.
  Future<Map<String, EventReaction>> getEventReactionsBatch(
      List<String> eventIds, String userId);

  /// GET /chat/pictures/{pictureId}/like — current like state.
  Future<PictureReaction> getPictureLike(String pictureId);

  /// POST /chat/pictures/{pictureId}/like — toggle like, returns updated state.
  Future<PictureReaction> togglePictureLike(String pictureId);

  // ── Privacy features ───────────────────────────────────────────────────────

  Future<Map<String, bool>> getFeatures();
  Future<void> enableAnonymousMode();
  Future<void> disableAnonymousMode();
  Future<void> enableHideProfile();
  Future<void> disableHideProfile();
  Future<List<String>> getBlockedUsers();
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
}
