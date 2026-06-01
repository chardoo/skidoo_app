part of 'chat_room_bloc.dart';

abstract class ChatRoomEvent {
  const ChatRoomEvent();
}

/// Join a room: loads cache, connects WS, fetches history.
/// If [shareUrl] is provided the image is shown immediately as an optimistic
/// message and sent over the WS as soon as the connection is ready.
/// [room] is used to determine room type and participants for E2EE.
class ChatRoomJoined extends ChatRoomEvent {
  final String roomId;
  final String? shareUrl;
  final ChatRoom? room;
  const ChatRoomJoined(this.roomId, {this.shareUrl, this.room});
}

/// Send the current input (text and/or staged image) as one message.
/// [content] may be null/empty when sending an image-only message.
class ChatRoomMessageSent extends ChatRoomEvent {
  final String? content;
  final String? replyToId;
  const ChatRoomMessageSent(this.content, {this.replyToId});
}

/// Stage a picked image or video — does NOT upload yet; waits for the user to send.
class ChatRoomImagePicked extends ChatRoomEvent {
  final String filePath;
  final bool isVideo;
  /// Browser-reported MIME type (set on web; null on mobile where the
  /// upload path derives content-type from the file extension).
  final String? mimeType;
  const ChatRoomImagePicked(this.filePath, {this.isVideo = false, this.mimeType});
}

/// Remove the staged image without sending.
class ChatRoomImageCleared extends ChatRoomEvent {
  const ChatRoomImageCleared();
}

/// Set (or clear) the message currently being replied to.
class ChatRoomReplySet extends ChatRoomEvent {
  final ChatMessage? message;
  const ChatRoomReplySet(this.message);
}

/// Toggle like / unlike for the event associated with this room.
class ChatRoomLikeToggled extends ChatRoomEvent {
  final String eventId;
  const ChatRoomLikeToggled(this.eventId);
}

/// Toggle like / unlike for the picture in a photo room.
class ChatRoomPictureLikeToggled extends ChatRoomEvent {
  final String pictureId;
  const ChatRoomPictureLikeToggled(this.pictureId);
}

/// Stage a remote image URL to be sent automatically once the WS connects.
/// Used by the in-app share flow (gallery → DM room).
class ChatRoomUrlStaged extends ChatRoomEvent {
  final String imageUrl;
  const ChatRoomUrlStaged(this.imageUrl);
}

/// A message arrived from the WebSocket.
class ChatRoomMessageReceived extends ChatRoomEvent {
  final ChatMessage message;
  const ChatRoomMessageReceived(this.message);
}

/// Load older messages (pagination).
class ChatRoomLoadMoreRequested extends ChatRoomEvent {
  const ChatRoomLoadMoreRequested();
}

/// Leave the room and close WS.
class ChatRoomLeft extends ChatRoomEvent {
  const ChatRoomLeft();
}

/// User confirmed an edit from the edit dialog.
class ChatRoomMessageEditRequested extends ChatRoomEvent {
  final String messageId;
  final String newContent;
  const ChatRoomMessageEditRequested(this.messageId, this.newContent);
}

/// User confirmed deletion from the confirm dialog.
class ChatRoomMessageDeleteRequested extends ChatRoomEvent {
  final String messageId;
  const ChatRoomMessageDeleteRequested(this.messageId);
}

// ── Internal events (dispatched by the bloc itself) ───────────────────────────

class _WsConnected extends ChatRoomEvent {
  const _WsConnected();
}

/// WS reconnected after a drop — refetch room history to backfill any messages
/// missed while offline (the socket has no replay/backfill).
class _HistoryRefetchRequested extends ChatRoomEvent {
  const _HistoryRefetchRequested();
}

class _WsFailed extends ChatRoomEvent {
  final String error;
  const _WsFailed(this.error);
}

/// WS dropped unexpectedly (not from the user leaving).
/// [fatal] is true when the server sent a close code that means retrying
/// will never succeed (e.g. 4001 bad token, 4003 not a participant).
class _WsDropped extends ChatRoomEvent {
  final bool fatal;
  const _WsDropped({this.fatal = false});
}

/// Reconnect attempts exhausted.
class _WsGaveUp extends ChatRoomEvent {
  const _WsGaveUp();
}

/// Like update received from WebSocket.
class _LikeUpdateReceived extends ChatRoomEvent {
  final LikeUpdate update;
  const _LikeUpdateReceived(this.update);
}

/// Picture like update received from WebSocket.
class _PictureLikeUpdateReceived extends ChatRoomEvent {
  final PictureLikeUpdate update;
  const _PictureLikeUpdateReceived(this.update);
}

/// WS broadcast: a message was edited.
class _MessageEdited extends ChatRoomEvent {
  final String messageId;
  final String content;
  final DateTime updatedAt;
  const _MessageEdited(this.messageId, this.content, this.updatedAt);
}

/// WS broadcast: a message was deleted.
class _MessageDeleted extends ChatRoomEvent {
  final String messageId;
  const _MessageDeleted(this.messageId);
}

/// Server sent participant key bundles on DM room join.
class _KeyBundlesReceived extends ChatRoomEvent {
  final List<Map<String, dynamic>> bundles;
  const _KeyBundlesReceived(this.bundles);
}

/// A participant who had no E2EE keys has just published them.
class _ParticipantKeyAvailable extends ChatRoomEvent {
  final String userId;
  final String identityKey;
  final Map<String, dynamic> signedPreKey;
  const _ParticipantKeyAvailable(this.userId, this.identityKey, this.signedPreKey);
}

/// A participant rotated their key bundle (key_rotation WS broadcast).
class _KeyRotationReceived extends ChatRoomEvent {
  final String userId;
  final int? registrationId;
  final String identityKey;
  final Map<String, dynamic> signedPreKey;
  const _KeyRotationReceived(
      this.userId, this.identityKey, this.signedPreKey, {this.registrationId});
}

/// A new member accepted their invite and joined the room.
class _WsUserJoined extends ChatRoomEvent {
  final String userId;
  final String userName;
  final String userRole;
  const _WsUserJoined(this.userId, this.userName, {this.userRole = ''});
}

/// Internal — debounced request to re-fetch the room from the server so the
/// participant list/count converges to server truth after any membership
/// change (join/leave/removed). Covers WS frames that arrive with incomplete
/// participant data, or that were missed on the broadcast stream entirely.
class _RoomReconcileRequested extends ChatRoomEvent {
  const _RoomReconcileRequested();
}

// ── Group admin actions (dispatched by the UI) ────────────────────────────────

/// Grant admin rights to a participant.
class ChatRoomGrantAdminRequested extends ChatRoomEvent {
  final String userId;
  const ChatRoomGrantAdminRequested(this.userId);
}

/// Revoke admin rights from a participant.
class ChatRoomRevokeAdminRequested extends ChatRoomEvent {
  final String userId;
  const ChatRoomRevokeAdminRequested(this.userId);
}

/// Update group settings — pass whichever fields changed.
class ChatRoomUpdateSettingsRequested extends ChatRoomEvent {
  final bool? adminOnly;
  final String? name;
  const ChatRoomUpdateSettingsRequested({this.adminOnly, this.name});
}

/// Kick a participant from the group.
class ChatRoomKickRequested extends ChatRoomEvent {
  final String userId;
  const ChatRoomKickRequested(this.userId);
}

// ── WS admin broadcast events (dispatched by the bloc internally) ─────────────

class _AdminGranted extends ChatRoomEvent {
  final String userId;
  final String grantedBy;
  const _AdminGranted(this.userId, this.grantedBy);
}

class _AdminRevoked extends ChatRoomEvent {
  final String userId;
  final String revokedBy;
  const _AdminRevoked(this.userId, this.revokedBy);
}

class _RoomSettingsUpdated extends ChatRoomEvent {
  final bool? adminOnly;
  final String? name;
  final String updatedBy;
  const _RoomSettingsUpdated(this.updatedBy, {this.adminOnly, this.name});
}

class _ParticipantRemoved extends ChatRoomEvent {
  final String userId;
  final String removedBy;
  const _ParticipantRemoved(this.userId, this.removedBy);
}

/// Current user requested to leave the room.
class ChatRoomLeaveGroupRequested extends ChatRoomEvent {
  const ChatRoomLeaveGroupRequested();
}

/// Admin requested permanent deletion of the room.
class ChatRoomDeleteRequested extends ChatRoomEvent {
  const ChatRoomDeleteRequested();
}

/// WS broadcast: room was deleted by an admin (received by all participants).
class _RoomDeleted extends ChatRoomEvent {
  final String deletedBy;
  const _RoomDeleted(this.deletedBy);
}

/// WS push: another member distributed their group sender key directly to us.
class _GroupSenderKeyReceived extends ChatRoomEvent {
  final String senderId;
  final String encryptedKey; // 'message' blob from server
  const _GroupSenderKeyReceived(this.senderId, this.encryptedKey);
}

/// WS broadcast: a member voluntarily left the room (triggers group re-key).
class _ParticipantLeft extends ChatRoomEvent {
  final String userId;
  const _ParticipantLeft(this.userId);
}

/// WS server error frame for this room (or a general one with no room_id),
/// e.g. "Only admins can send messages in this room".
class _WsServerError extends ChatRoomEvent {
  final String message;
  const _WsServerError(this.message);
}

/// WS broadcast: another participant acknowledged reading messages.
class _ReadReceiptReceived extends ChatRoomEvent {
  final String readerId;
  final String? upToMessageId;
  final String? messageId;
  const _ReadReceiptReceived({
    required this.readerId,
    this.upToMessageId,
    this.messageId,
  });
}
