import 'dart:io';

import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_rest_data_source.dart';
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

class GetEventRoomsBatchUseCase {
  final ChatRepository _repo;
  GetEventRoomsBatchUseCase(this._repo);
  /// Returns a map of eventId → ChatRoom. Handles up to 20 IDs per call.
  Future<Map<String, ChatRoom>> call(List<String> eventIds) =>
      _repo.getEventRoomsBatch(eventIds);
}

class GetPhotoRoomUseCase {
  final ChatRepository _repo;
  GetPhotoRoomUseCase(this._repo);
  Future<ChatRoom> call(String pictureId) => _repo.getPhotoRoom(pictureId);
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

class EditMessageUseCase {
  final ChatRepository _repo;
  EditMessageUseCase(this._repo);

  Future<void> call({
    required String roomId,
    required String messageId,
    required String content,
  }) =>
      _repo.editMessage(roomId: roomId, messageId: messageId, content: content);
}

class DeleteMessageUseCase {
  final ChatRepository _repo;
  DeleteMessageUseCase(this._repo);

  Future<void> call({
    required String roomId,
    required String messageId,
  }) =>
      _repo.deleteMessage(roomId: roomId, messageId: messageId);
}

class UpdateCachedMessageUseCase {
  final ChatRepository _repo;
  UpdateCachedMessageUseCase(this._repo);

  Future<void> call(String messageId, String content, DateTime updatedAt) =>
      _repo.updateCachedMessage(messageId, content, updatedAt);
}

class DeleteCachedMessageUseCase {
  final ChatRepository _repo;
  DeleteCachedMessageUseCase(this._repo);

  Future<void> call(String messageId) => _repo.deleteCachedMessage(messageId);
}

class CreateGroupRoomUseCase {
  final ChatRepository _repo;
  CreateGroupRoomUseCase(this._repo);

  Future<ChatRoom> call({
    required String name,
    List<String>? inviteeIds,
  }) =>
      _repo.createGroupRoom(name: name, inviteeIds: inviteeIds);
}

class AcceptRoomInviteUseCase {
  final ChatRepository _repo;
  AcceptRoomInviteUseCase(this._repo);
  Future<void> call(String roomId) => _repo.acceptRoomInvite(roomId);
}

class DeclineRoomInviteUseCase {
  final ChatRepository _repo;
  DeclineRoomInviteUseCase(this._repo);
  Future<void> call(String roomId) => _repo.declineRoomInvite(roomId);
}

class GrantAdminUseCase {
  final ChatRepository _repo;
  GrantAdminUseCase(this._repo);
  Future<void> call(String roomId, String userId) =>
      _repo.grantAdmin(roomId, userId);
}

class RevokeAdminUseCase {
  final ChatRepository _repo;
  RevokeAdminUseCase(this._repo);
  Future<void> call(String roomId, String userId) =>
      _repo.revokeAdmin(roomId, userId);
}

class UpdateRoomSettingsUseCase {
  final ChatRepository _repo;
  UpdateRoomSettingsUseCase(this._repo);
  Future<void> call(String roomId, {bool? adminOnly, String? name}) =>
      _repo.updateRoomSettings(roomId, adminOnly: adminOnly, name: name);
}

class KickParticipantUseCase {
  final ChatRepository _repo;
  KickParticipantUseCase(this._repo);
  Future<void> call(String roomId, String userId) =>
      _repo.kickParticipant(roomId, userId);
}

class LeaveRoomUseCase {
  final ChatRepository _repo;
  LeaveRoomUseCase(this._repo);
  Future<bool> call(String roomId) => _repo.leaveRoom(roomId);
}

class ClearRoomCacheUseCase {
  final ChatRepository _repo;
  ClearRoomCacheUseCase(this._repo);
  Future<void> call(String roomId) => _repo.clearRoomCache(roomId);
}

class DeleteRoomUseCase {
  final ChatRepository _repo;
  DeleteRoomUseCase(this._repo);
  Future<void> call(String roomId) => _repo.deleteRoom(roomId);
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

class GetLastMessageTimesUseCase {
  final ChatRepository _repo;
  GetLastMessageTimesUseCase(this._repo);
  Future<Map<String, DateTime>> call() => _repo.getLastMessageTimes();
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

class GetEventReactionUseCase {
  final ChatRepository _repo;
  GetEventReactionUseCase(this._repo);

  Future<EventReaction> call(String eventId, String userId) =>
      _repo.getEventReaction(eventId, userId);
}

class GetEventReactionsBatchUseCase {
  final ChatRepository _repo;
  GetEventReactionsBatchUseCase(this._repo);

  Future<Map<String, EventReaction>> call(
          List<String> eventIds, String userId) =>
      _repo.getEventReactionsBatch(eventIds, userId);
}

// ── Privacy features ──────────────────────────────────────────────────────────

class GetFeaturesUseCase {
  final ChatRepository _repo;
  GetFeaturesUseCase(this._repo);
  Future<Map<String, bool>> call() => _repo.getFeatures();
}

class SetAnonymousModeUseCase {
  final ChatRepository _repo;
  SetAnonymousModeUseCase(this._repo);
  Future<void> call(bool enable) =>
      enable ? _repo.enableAnonymousMode() : _repo.disableAnonymousMode();
}

class SetHideProfileUseCase {
  final ChatRepository _repo;
  SetHideProfileUseCase(this._repo);
  Future<void> call(bool enable) =>
      enable ? _repo.enableHideProfile() : _repo.disableHideProfile();
}

class GetBlockedUsersUseCase {
  final ChatRepository _repo;
  GetBlockedUsersUseCase(this._repo);
  Future<List<String>> call() => _repo.getBlockedUsers();
}

class BlockUserUseCase {
  final ChatRepository _repo;
  BlockUserUseCase(this._repo);
  Future<void> call(String userId) => _repo.blockUser(userId);
}

class UnblockUserUseCase {
  final ChatRepository _repo;
  UnblockUserUseCase(this._repo);
  Future<void> call(String userId) => _repo.unblockUser(userId);
}
