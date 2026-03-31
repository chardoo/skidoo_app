import 'dart:io';

import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/auth_service.dart';

class GetGlobalRoomUseCase {
  final ChatRepository _repo;
  GetGlobalRoomUseCase(this._repo);
  Future<ChatRoom> call() => _repo.getGlobalRoom();
}

class GetEventRoomUseCase {
  final ChatRepository _repo;
  GetEventRoomUseCase(this._repo);
  Future<ChatRoom> call(String eventId) => _repo.getEventRoom(eventId);
}

class GetSampleRoomUseCase {
  final ChatRepository _repo;
  GetSampleRoomUseCase(this._repo);
  Future<ChatRoom> call(String sampleId) => _repo.getSampleRoom(sampleId);
}

class GetOrCreateDirectRoomUseCase {
  final ChatRepository _repo;
  GetOrCreateDirectRoomUseCase(this._repo);

  Future<ChatRoom> call({
    required String recipientId,
    required String recipientRole,
    String? localDisplayName,
  }) =>
      _repo.getOrCreateDirectRoom(
        recipientId: recipientId,
        recipientRole: recipientRole,
        localDisplayName: localDisplayName,
      );
}

class CreateEventPrivateRoomUseCase {
  final ChatRepository _repo;
  CreateEventPrivateRoomUseCase(this._repo);

  Future<ChatRoom> call({required String eventId, String? name}) =>
      _repo.createEventPrivateRoom(eventId: eventId, name: name);
}

class GetMyRoomsUseCase {
  final ChatRepository _repo;
  GetMyRoomsUseCase(this._repo);
  Future<List<ChatRoom>> call() => _repo.getMyRooms();
}

class GetCachedRoomsUseCase {
  final ChatRepository _repo;
  GetCachedRoomsUseCase(this._repo);
  Future<List<ChatRoom>> call() => _repo.getCachedRooms();
}

class GetRoomUseCase {
  final ChatRepository _repo;
  GetRoomUseCase(this._repo);
  Future<ChatRoom> call(String roomId) => _repo.getRoom(roomId);
}

class InviteToRoomUseCase {
  final ChatRepository _repo;
  InviteToRoomUseCase(this._repo);

  Future<void> call({
    required String roomId,
    required String inviteeId,
    required String inviteeRole,
  }) =>
      _repo.inviteToRoom(
        roomId: roomId,
        inviteeId: inviteeId,
        inviteeRole: inviteeRole,
      );
}

class GetRoomMessagesUseCase {
  final ChatRepository _repo;
  GetRoomMessagesUseCase(this._repo);

  Future<List<ChatMessage>> call(
    String roomId, {
    String? beforeId,
    int limit = ChatConfig.messagePageSize,
  }) =>
      _repo.getMessages(roomId, beforeId: beforeId, limit: limit);
}

class GetCachedMessagesUseCase {
  final ChatRepository _repo;
  GetCachedMessagesUseCase(this._repo);

  Future<List<ChatMessage>> call(
    String roomId, {
    int limit = ChatConfig.messagePageSize,
  }) =>
      _repo.getCachedMessages(roomId, limit: limit);
}

class CacheMessageUseCase {
  final ChatRepository _repo;
  CacheMessageUseCase(this._repo);
  Future<void> call(ChatMessage message) => _repo.cacheMessage(message);
}

class GetUnreadCountsUseCase {
  final ChatRepository _repo;
  final AuthService _authService;
  GetUnreadCountsUseCase(this._repo, this._authService);

  Future<Map<String, int>> call() async {
    final userId = await _authService.getUserId();
    return _repo.getUnreadCounts(userId);
  }
}

class MarkRoomAsReadUseCase {
  final ChatRepository _repo;
  MarkRoomAsReadUseCase(this._repo);

  Future<void> call(String roomId) => _repo.markRoomAsRead(roomId);
}

class UploadChatImageUseCase {
  final ChatRepository _repo;
  UploadChatImageUseCase(this._repo);

  Future<String> call(File file) => _repo.uploadImage(file);
}
