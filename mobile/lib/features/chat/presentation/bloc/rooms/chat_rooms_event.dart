part of 'chat_rooms_bloc.dart';

abstract class ChatRoomsEvent {
  const ChatRoomsEvent();
}

class ChatRoomsLoadRequested extends ChatRoomsEvent {
  const ChatRoomsLoadRequested();
}

/// Quickly refreshes only the unread counts (no server call needed).
class ChatRoomsRefreshUnread extends ChatRoomsEvent {
  const ChatRoomsRefreshUnread();
}

class ChatRoomsAcceptInvite extends ChatRoomsEvent {
  const ChatRoomsAcceptInvite(this.roomId);
  final String roomId;
}

class ChatRoomsDeclineInvite extends ChatRoomsEvent {
  const ChatRoomsDeclineInvite(this.roomId);
  final String roomId;
}

/// Server pushed a new group invite to the current user via WS.
class ChatRoomsGroupInviteReceived extends ChatRoomsEvent {
  const ChatRoomsGroupInviteReceived(this.room);
  final ChatRoom room;
}

// ── Internal events (not dispatched from outside the bloc) ────────────────────

/// A message landed in a background room — update badge and sort-order
/// in-memory without a DB round-trip (essential on web where SQLite is absent).
class _ChatRoomsMessageArrived extends ChatRoomsEvent {
  const _ChatRoomsMessageArrived(this.roomId, this.arrivedAt);
  final String roomId;
  final DateTime arrivedAt;
}

/// ChatRoomBloc opened a room and marked all messages as read — zero the badge.
class _ChatRoomsRoomRead extends ChatRoomsEvent {
  const _ChatRoomsRoomRead(this.roomId);
  final String roomId;
}

/// The current user should drop this room from their list — it was deleted, or
/// they were removed/kicked from it.
class _ChatRoomsRoomRemoved extends ChatRoomsEvent {
  const _ChatRoomsRoomRemoved(this.roomId);
  final String roomId;
}
