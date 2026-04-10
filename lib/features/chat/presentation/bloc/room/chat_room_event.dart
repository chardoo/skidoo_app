part of 'chat_room_bloc.dart';

abstract class ChatRoomEvent {
  const ChatRoomEvent();
}

/// Join a room: loads cache, connects WS, fetches history.
class ChatRoomJoined extends ChatRoomEvent {
  final String roomId;
  const ChatRoomJoined(this.roomId);
}

/// Send the current input (text and/or staged image) as one message.
/// [content] may be null/empty when sending an image-only message.
class ChatRoomMessageSent extends ChatRoomEvent {
  final String? content;
  final String? replyToId;
  const ChatRoomMessageSent(this.content, {this.replyToId});
}

/// Stage a picked image — does NOT upload yet; waits for the user to send.
class ChatRoomImagePicked extends ChatRoomEvent {
  final String filePath;
  const ChatRoomImagePicked(this.filePath);
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

// ── Internal events (dispatched by the bloc itself) ───────────────────────────

class _WsConnected extends ChatRoomEvent {
  const _WsConnected();
}

class _WsFailed extends ChatRoomEvent {
  final String error;
  const _WsFailed(this.error);
}

/// WS dropped unexpectedly (not from the user leaving) — triggers reconnect.
class _WsDropped extends ChatRoomEvent {
  const _WsDropped();
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
