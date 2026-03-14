import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/models/message_model.dart';

abstract class ChatRemoteDataSource {
  Future<Stream<List<MessageResponse>>> getInitialMessages();
  Future<Stream<List<MessageResponse>>> getMoreMessages(
      MessageResponse lastMessage);
  Future<void> addMessage(Message message);
  Future<void> updateMessage(String uid, Message message);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  static const int _initialLimit = 7;
  static const int _pageLimit = 50;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<Stream<List<MessageResponse>>> getInitialMessages() async {
    try {
      final snapshots = _firestore
          .collection('messages')
          .orderBy('date', descending: false)
          .limitToLast(_initialLimit)
          .snapshots();
      return snapshots
          .map((e) => e.docs.map((doc) => MessageResponse(doc)).toList());
    } catch (e) {
      throw ServerException('Failed to get messages: $e');
    }
  }

  @override
  Future<Stream<List<MessageResponse>>> getMoreMessages(
      MessageResponse lastMessage) async {
    try {
      final snapshots = _firestore
          .collection('messages')
          .orderBy('date', descending: false)
          .startAfterDocument(lastMessage.doc)
          .limit(_pageLimit)
          .snapshots();
      return snapshots
          .map((e) => e.docs.map((doc) => MessageResponse(doc)).toList());
    } catch (e) {
      throw ServerException('Failed to get more messages: $e');
    }
  }

  @override
  Future<void> addMessage(Message message) async {
    try {
      await _firestore.collection('messages').add(message.toJson());
    } catch (e) {
      throw ServerException('Failed to send message: $e');
    }
  }

  @override
  Future<void> updateMessage(String uid, Message message) async {
    try {
      await _firestore
          .collection('messages')
          .doc(uid)
          .update(message.toJson());
    } catch (e) {
      throw ServerException('Failed to update message: $e');
    }
  }
}
