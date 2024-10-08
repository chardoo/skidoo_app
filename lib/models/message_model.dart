import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String name;
  final String body;
  final List response;
  final DateTime date;

  Message({
    required this.date,
    required this.name,
    required this.body,
    required this.response,
  });

  Message.fromJson(Map<String, dynamic> json)
      : name = json["name"],
        body = json["body"],
        date = DateTime.fromMillisecondsSinceEpoch(
            json['date'].millisecondsSinceEpoch),
        response = json["response"];

  Map<String, dynamic> toJson() => {
        "name": name,
        "body": body,
        "response": response,
        "date": date,
      };
}

class MessageResponse {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  MessageResponse(this.doc);
  Message get message => Message.fromJson(doc.data());
}
