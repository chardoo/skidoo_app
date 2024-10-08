import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skidoo_app/models/message_model.dart';

class FireStoreApis {
  static const int _offSet = 7;
  FirebaseFirestore? _firestore;
  Future addMessage(Message message) async {
    _firestore = FirebaseFirestore.instance;
    print("mes to firebase");
    print(message.toJson());
    _firestore!.collection("messages").add(message.toJson());
  }

  Future updateMessage(uuid, Message message) async {
    _firestore = FirebaseFirestore.instance;
    _firestore!.collection("messages").doc(uuid).update(message.toJson());
  }

  Future<Stream<List<MessageResponse>>> getInitialMessages() async {
    _firestore = FirebaseFirestore.instance;
    var snapshots = _firestore!
        .collection("messages")
        .orderBy("date", descending: false)
        .limitToLast(_offSet)
        .snapshots();

    var res = snapshots
        .map((e) => e.docs.map((doc) => MessageResponse(doc)).toList());
    return res;
  }

  Future<Stream<List<MessageResponse>>> getMoreMessages(
      MessageResponse lastMessage) async {
    _firestore = FirebaseFirestore.instance;
    var snapshots = await _firestore!
        .collection("messages")
        .orderBy("date", descending: false)
        .startAfterDocument(lastMessage.doc)
        .limit(50)
        .snapshots();

    var res = snapshots
        .map((event) => event.docs.map((e) => MessageResponse(e)).toList());
    print("more is lengthet");
    print(res.length);
    return res;
  }
}
