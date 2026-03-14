part of 'chat_bloc.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class ChatInitialized extends ChatEvent {
  const ChatInitialized();
}

class ChatMessageSent extends ChatEvent {
  final Message message;
  const ChatMessageSent(this.message);
  @override
  List<Object?> get props => [];
}

class ChatMessageUpdated extends ChatEvent {
  final String uid;
  final Message message;
  const ChatMessageUpdated({required this.uid, required this.message});
  @override
  List<Object?> get props => [uid];
}

class ChatMoreMessagesRequested extends ChatEvent {
  final MessageResponse lastMessage;
  const ChatMoreMessagesRequested(this.lastMessage);
  @override
  List<Object?> get props => [];
}
