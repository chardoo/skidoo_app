import 'package:skidoo_app/models/message_model.dart';

abstract class ChatRepository {
  Future<Stream<List<MessageResponse>>> getInitialMessages();
  Future<Stream<List<MessageResponse>>> getMoreMessages(
      MessageResponse lastMessage);
  Future<void> addMessage(Message message);
  Future<void> updateMessage(String uid, Message message);
}
