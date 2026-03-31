part of 'chat_room_bloc.dart';

abstract class ChatRoomEvent {
  const ChatRoomEvent();
}

/// Join a room: loads cache, connects WS, fetches history.
class ChatRoomJoined extends ChatRoomEvent {
  final String roomId;
  const ChatRoomJoined(this.roomId);
}

/// Send a message (optimistic).
class ChatRoomMessageSent extends ChatRoomEvent {
  final String content;
  const ChatRoomMessageSent(this.content);
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
