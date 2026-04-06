import 'dart:io';

import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

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
  Future<ChatRoom> getSampleRoom(String sampleId) =>
      _fetchAndCacheRoom(() => _rest.getSampleRoom(sampleId));

  @override
  Future<ChatRoom> getOrCreateDirectRoom({
    required String recipientId,
    required String recipientRole,
    String? localDisplayName,
  }) async {
    final room = await _fetchAndCacheRoom(() => _rest.getOrCreateDirectRoom(
          recipientId: recipientId,
          recipientRole: recipientRole,
        ));
    // If the API returned no name and we have a local display name, save it.
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
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  }) =>
      _rest.inviteToRoom(
        roomId: roomId,
        inviteeId: inviteeId,
        inviteeRole: inviteeRole,
      );

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
      _db.insertMessage(message);

  @override
  Future<Map<String, int>> getUnreadCounts(String currentUserId) =>
      _db.getUnreadCounts(currentUserId);

  @override
  Future<void> markRoomAsRead(String roomId) => _db.markAllAsRead(roomId);

  @override
  Future<String> uploadImage(File file) => _rest.uploadImage(file);

  @override
  Future<EventReaction> getEventReaction(String eventId, String userId) =>
      _rest.getEventReaction(eventId, userId);

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
