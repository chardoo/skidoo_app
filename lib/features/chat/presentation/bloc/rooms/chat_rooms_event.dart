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
