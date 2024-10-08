import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/firebase_controllers.dart';
import 'package:skidoo_app/models/message_model.dart';

class ButtomTextBox extends StatefulWidget {
  const ButtomTextBox({super.key});

  @override
  State<ButtomTextBox> createState() => _ButtomTextBoxState();
}

class _ButtomTextBoxState extends State<ButtomTextBox> {
  final bodyController = TextEditingController();

  @override
  void dispose() {
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Color.fromARGB(255, 168, 167, 167),
          borderRadius: BorderRadius.circular(30)),
      margin: EdgeInsets.only(left: 15),
      padding: const EdgeInsets.only(left: 10, bottom: 10, top: 10),
      height: 60,
      width: double.infinity,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: bodyController,
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  hintText: "Write message...",
                  hintStyle: TextStyle(color: Colors.black54),
                  border: InputBorder.none),
            ),
          ),
          const SizedBox(
            width: 15,
          ),

          IconButton(onPressed: onPressed, icon:  Icon(
              Icons.send,
              color: Color.fromARGB(255, 6, 6, 6),
              size: 18,
            ))
          // FloatingActionButton(
          //   onPressed: onPressed,
          //   backgroundColor: Color.fromARGB(255, 168, 167, 167),
          //   // backgroundColor: Color.fromARGB(255, 245, 246, 246),
          //   elevation: 0,
          //   child: const Icon(
          //     Icons.send,
          //     color: Color.fromARGB(255, 6, 6, 6),
          //     size: 18,
          //   ),
          // ),
        ],
      ),
    );
  }

  onPressed() {
    if (bodyController.text.isEmpty) {
      Get.dialog(const AlertDialog(
        content: Text("please type in some cool message"),
        title: Text("Empty message"),
      ));
    } else {
      Message message = Message(
          name: "Richard",
          body: bodyController.text,
          date: DateTime.now(),
          response: []);
      Get.find<FireStoreController>().addMessage(message);
      bodyController.clear();
    }
  }
}
