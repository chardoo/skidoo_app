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
