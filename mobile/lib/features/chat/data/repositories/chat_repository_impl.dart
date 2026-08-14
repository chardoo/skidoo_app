import 'dart:io';

import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:jperg_app/features/chat/data/local/chat_database.dart';
import 'package:jperg_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRestDataSource _rest;
  final ChatDatabase _db;

  ChatRepositoryImpl(this._rest, this._db);

  // ── Rooms ──────────────────────────────────────────────────────────────────

  @override
  Future<ChatRoom> getGlobalRoom() =>
      _fetchAndCacheRoom(() => _rest.getGlobalRoom());

  @override
  Future<ChatRoom> getEventRoom(String eventId) =>
      _fetchAndCacheRoom(() => _rest.getEventRoom(eventId));

  @override
  Future<Map<String, ChatRoom>> getEventRoomsBatch(
      List<String> eventIds) async {
    if (eventIds.isEmpty) return {};
    // Clamp to the backend's limit of 20 per request.
    final ids = eventIds.take(20).toList();
    final rooms = await _rest.getEventRoomsBatch(ids);
    // Cache every room returned so single-event lookups hit local DB first.
    for (final room in rooms.values) {
      await _db.upsertRoom(room);
    }
    return rooms;
  }

  @override
  Future<ChatRoom> getPhotoRoom(String pictureId) =>
      _fetchAndCacheRoom(() => _rest.getPhotoRoom(pictureId));

  @override
  Future<ChatRoom> getSampleRoom(String sampleId) =>
      _fetchAndCacheRoom(() => _rest.getSampleRoom(sampleId));

  @override
  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
    String? localDisplayName,
  }) async {
    // 1. Check local cache first — avoids duplicate room creation entirely.
    final cached = await _db.getDirectRoomWithUser(recipientId);
    if (cached != null) {
      if ((cached.name == null || cached.name!.isEmpty) &&
          localDisplayName != null &&
          localDisplayName.isNotEmpty) {
        final named = cached.copyWith(name: localDisplayName);
        await _db.upsertRoom(named);
        return named;
      }
      return cached;
    }

    // 2. Not in cache — call the API (server-side get-or-create).
    final room = await _fetchAndCacheRoom(() => _rest.getOrCreateDirectRoom(
          recipientId: recipientId,
          recipientRole: recipientRole,
          // Forward the known recipient name so the server stores it and every
          // participant list (create/get/socket) returns it.
          recipientName: localDisplayName,
        ));
    // Apply local display name if the server returned none.
    if ((room.name == null || room.name!.isEmpty) &&
        localDisplayName != null &&
        localDisplayName.isNotEmpty) {
      final named = room.copyWith(name: localDisplayName);
      await _db.upsertRoom(named);
      return named;
    }
    return room;
  }

  @override
  Future<CanMessageResult> canMessage(String targetUserId) =>
      _rest.canMessage(targetUserId);

  @override
  Future<ChatRoom> createEventPrivateRoom({
    required String eventId,
    String? name,
  }) =>
      _fetchAndCacheRoom(() => _rest.createEventPrivateRoom(
            eventId: eventId,
            name: name,
          ));

  @override
  Future<List<ChatRoom>> getMyRooms() async {
    try {
      final serverRooms = await _rest.getMyRooms();

      // Preserve locally-saved names (e.g. photographer name on direct rooms)
      // for any room the server returns without a name.
      final cached = await _db.getAllRooms();
      final cachedNames = {
        for (final r in cached)
          if (r.name != null && r.name!.isNotEmpty) r.id: r.name!,
      };

      final merged = serverRooms.map((room) {
        if (room.name != null && room.name!.isNotEmpty) return room;
        final saved = cachedNames[room.id];
        return saved != null ? room.copyWith(name: saved) : room;
      }).toList();

      await _db.upsertRooms(merged);
      return merged;
    } on NetworkException {
      // Fallback to cache on network failure.
      return _db.getAllRooms();
    } on ServerException {
      rethrow;
    }
  }

  @override
  Future<List<ChatRoom>> getCachedRooms() => _db.getAllRooms();

  @override
  Future<ChatRoom> getRoom(String roomId) async {
    try {
      final room = await _rest.getRoom(roomId);
      await _db.upsertRoom(room);
      return room;
    } on NetworkException {
      final cached = await _db.getRoom(roomId);
      if (cached != null) return cached;
      rethrow;
    } on ServerException {
      rethrow;
    }
  }

  @override
  Future<void> editMessage({
    required String roomId,
    required String messageId,
    required String content,
  }) =>
      _rest.editMessage(roomId: roomId, messageId: messageId, content: content);

  @override
  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) =>
      _rest.deleteMessage(roomId: roomId, messageId: messageId);

  @override
  Future<void> updateCachedMessage(
          String messageId, String content, DateTime updatedAt) =>
      _db.updateMessageContent(messageId, content, updatedAt);

  @override
  Future<void> deleteCachedMessage(String messageId) =>
      _db.deleteMessage(messageId);

  @override
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
    String? inviteeName,
  }) =>
      _rest.inviteToRoom(
        roomId: roomId,
        inviteeId: inviteeId,
        inviteeRole: inviteeRole,
        inviteeName: inviteeName,
      );

  @override
  Future<ChatRoom> createGroupRoom({
    required String name,
    List<String>? inviteeIds,
    Map<String, String>? inviteeNames,
  }) =>
      _fetchAndCacheRoom(() => _rest.createGroupRoom(
            name: name,
            inviteeIds: inviteeIds,
            inviteeNames: inviteeNames,
          ));

  @override
  Future<void> acceptRoomInvite(String roomId, {required String userId}) async {
    await _rest.acceptRoomInvite(roomId);
    // Only after the server has agreed — a local row saying "active" for a join
    // that failed would survive in the cache and read as a room the user is in.
    await _db.markParticipantActive(roomId, userId);
  }

  @override
  Future<void> declineRoomInvite(String roomId) async {
    await _rest.declineRoomInvite(roomId);
    await _db.deleteRoom(roomId);
  }

  @override
  Future<void> grantAdmin(String roomId, String userId) =>
      _rest.grantAdmin(roomId, userId);

  @override
  Future<void> revokeAdmin(String roomId, String userId) =>
      _rest.revokeAdmin(roomId, userId);

  @override
  Future<void> updateRoomSettings(String roomId, {bool? adminOnly, String? name}) =>
      _rest.updateRoomSettings(roomId, adminOnly: adminOnly, name: name);

  @override
  Future<void> kickParticipant(String roomId, String userId) =>
      _rest.kickParticipant(roomId, userId);

  @override
  Future<bool> leaveRoom(String roomId) async {
    final deleted = await _rest.leaveRoom(roomId);
    await _db.deleteRoom(roomId);
    return deleted;
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    await _rest.deleteRoom(roomId);
    await _db.deleteRoom(roomId);
  }

  @override
  Future<void> clearRoomCache(String roomId) => _db.deleteRoom(roomId);

  // ── Messages ───────────────────────────────────────────────────────────────

  @override
  Future<List<ChatMessage>> getMessages(
    String roomId, {
    String? beforeId,
    int limit = ChatConfig.messagePageSize,
  }) async {
    try {
      final messages =
          await _rest.getMessages(roomId, beforeId: beforeId, limit: limit);
      await _db.upsertMessages(messages);
      return messages;
    } on NetworkException {
      return _db.getMessages(roomId, limit: limit, beforeId: beforeId);
    } on ServerException {
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getCachedMessages(
    String roomId, {
    int limit = ChatConfig.messagePageSize,
  }) =>
      _db.getMessages(roomId, limit: limit);

  @override
  Future<void> cacheMessage(ChatMessage message) =>
      _db.upsertMessages([message]);

  @override
  Future<Map<String, int>> getUnreadCounts(String currentUserId) =>
      _db.getUnreadCounts(currentUserId);

  @override
  Future<Map<String, DateTime>> getLastMessageTimes() =>
      _db.getLastMessageTimes();

  @override
  Future<void> markRoomAsRead(String roomId) => _db.markAllAsRead(roomId);

  @override
  Future<String> uploadImage(File file, {String? mimeType}) =>
      _rest.uploadImage(file, mimeType: mimeType);

  @override
  Future<EventReaction> getEventReaction(String eventId, String userId) =>
      _rest.getEventReaction(eventId, userId);

  @override
  Future<Map<String, EventReaction>> getEventReactionsBatch(
          List<String> eventIds, String userId) =>
      _rest.getEventReactionsBatch(eventIds, userId);

  @override
  Future<PictureReaction> getPictureLike(String pictureId) =>
      _rest.getPictureLike(pictureId);

  @override
  Future<PictureReaction> togglePictureLike(String pictureId) =>
      _rest.togglePictureLike(pictureId);

  // ── Privacy features ───────────────────────────────────────────────────────

  @override
  Future<Map<String, bool>> getFeatures() => _rest.getFeatures();

  @override
  Future<void> enableAnonymousMode() => _rest.enableAnonymousMode();

  @override
  Future<void> disableAnonymousMode() => _rest.disableAnonymousMode();

  @override
  Future<void> enableHideProfile() => _rest.enableHideProfile();

  @override
  Future<void> disableHideProfile() => _rest.disableHideProfile();

  @override
  Future<List<String>> getBlockedUsers() => _rest.getBlockedUsers();

  @override
  Future<void> blockUser(String userId) => _rest.blockUser(userId);

  @override
  Future<void> unblockUser(String userId) => _rest.unblockUser(userId);

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<ChatRoom> _fetchAndCacheRoom(
      Future<ChatRoom> Function() fetch) async {
    try {
      final room = await fetch();
      await _db.upsertRoom(room);
      return room;
    } on NetworkException {
      rethrow;
    } on ServerException {
      rethrow;
    }
  }
}
