import 'dart:async';
import 'package:get/get.dart';
import 'package:skidoo_app/firebase_apis/firestore_apis.dart';
import 'package:skidoo_app/models/message_model.dart';

class FireStoreController extends GetxController {
  var name = ''.obs;
  FireStoreController(this.messageController) {
    initialMessages();
  }
  late FireStoreApis _apis;
  var appState = AppState.idle.obs;
  late StreamController<List<MessageResponse>> messageController;

  void addMessage(Message message) async {
    try {
      appState(AppState.loading);
      _apis = FireStoreApis();

      await _apis.addMessage(message);
      appState(AppState.success);
    } catch (e) {
      appState(AppState.failed);
    }
  }

  void initialMessages() async {
    _apis = FireStoreApis();
    var initialMessages = await _apis.getInitialMessages();
    initialMessages.listen((response) {
      messageController.sink.add(response);
      // if (response.isNotEmpty) _initializeName(response.first.message.name);
    });
  }

  _initializeName(nameOnMessage) {
    name(nameOnMessage);
  }

  void getMoreMessages(
      MessageResponse lastMessage, List<MessageResponse> oldMessages) async {
    print("more is abput to come");
    _apis = FireStoreApis();
    var messages = await _apis.getMoreMessages(lastMessage);
    messages.listen((instance) {
      messageController.sink.add(instance);
    });
  }

  void updateMessage(String uid, Message message) async {
    try {
      appState(AppState.loading);
      _apis = FireStoreApis();

      await _apis.updateMessage(uid, message);
      appState(AppState.success);
    } catch (e) {
      appState(AppState.failed);
    }
  }
}

enum AppState { loading, idle, failed, success }
