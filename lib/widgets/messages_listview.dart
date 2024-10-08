import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/firebase_controllers.dart';
import 'package:skidoo_app/models/message_model.dart';

class MessageTile extends StatefulWidget {
  const MessageTile({
    Key? key,
    required this.response,
  }) : super(key: key);
  final MessageResponse response;
  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  final replyController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        replyDialog();
      },
      child: Container(
        padding:
            const EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Color.fromARGB(255, 121, 124, 125),
              ),
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.response.message.name,
                    style: const TextStyle(
                        fontSize: 10, color: Color.fromARGB(255, 19, 19, 19)),
                  ),
                  Text(
                    widget.response.message.body,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ],
              )),
        ),
      ),
    );
  }

  replyDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Reply"),
              content: TextFormField(
                controller: replyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  fillColor: Colors.black54,
                  filled: true,
                ),
              ),
              actions: [
                IconButton(onPressed: _addReply, icon: const Icon(Icons.reply))
              ],
            ));
  }

  _addReply() {
    String uid = widget.response.doc.id;
    // get the message as a json and ..

    Map<String, dynamic> oldres = widget.response.message.toJson();
    // add the reply
    oldres['response'] = [
      ...oldres["response"],
      replyController.text,
    ];

    Get.find<FireStoreController>()
        .updateMessage(uid, Message.fromJson(oldres));
    Navigator.pop(context);
  }
}
