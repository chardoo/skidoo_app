import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  ChatRepositoryImpl(this._remoteDataSource);

  @override
  Future<Stream<List<MessageResponse>>> getInitialMessages() async {
    try {
      return await _remoteDataSource.getInitialMessages();
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error loading messages: $e');
    }
  }

  @override
  Future<Stream<List<MessageResponse>>> getMoreMessages(
      MessageResponse lastMessage) async {
    try {
      return await _remoteDataSource.getMoreMessages(lastMessage);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error loading more messages: $e');
    }
  }

  @override
  Future<void> addMessage(Message message) async {
    try {
      await _remoteDataSource.addMessage(message);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error sending message: $e');
    }
  }

  @override
  Future<void> updateMessage(String uid, Message message) async {
    try {
      await _remoteDataSource.updateMessage(uid, message);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Error updating message: $e');
    }
  }
}
