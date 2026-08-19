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

/// The session ended — drop every room, invite, unread count and preview.
///
/// This bloc is the one created at the root of the app, above the Navigator,
/// so that the unread badge stays live even on pages that have never opened a
/// chat. Nothing tears it down: signing out replaces the whole navigation
/// stack, and this survives it. Whoever signed in next inherited the previous
/// account's inbox — their conversations listed, their unread count on the tab
/// bar — until a reload happened to replace it.
class ChatRoomsSessionCleared extends ChatRoomsEvent {
  const ChatRoomsSessionCleared();
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
  const _ChatRoomsMessageArrived(this.roomId, this.arrivedAt,
      {this.senderId,
      this.senderName,
      this.preview,
      this.countsAsUnread = true});

  final String roomId;
  final DateTime arrivedAt;
  final String? senderId;
  final String? senderName;

  /// The arriving message as an inbox preview, or null when there is nothing
  /// showable for it (ciphertext this device cannot read).
  final LastMessage? preview;

  /// False for system notices, which change the room's order and preview but
  /// are not unread messages.
  final bool countsAsUnread;
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
