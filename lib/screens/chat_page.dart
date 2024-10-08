import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/pages/photographers.dart';
import 'package:skidoo_app/widgets/buttom_text_box.dart';
import 'package:skidoo_app/widgets/messages_listview.dart';
import '../controller/firebase_controllers.dart';
import '../models/message_model.dart';
import '../widgets/reply_tile.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late StreamController<List<MessageResponse>> messageController;
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
 
  @override
  void initState() {
    messageController = StreamController();
    super.initState();
  }

  @override
  void dispose() {
    messageController.close();
    messageController.onCancel!();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var controller =
        Get.put<FireStoreController>(FireStoreController(messageController));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text("Chat Page"),
        actions: [
          IconButton(
              onPressed: () {
                Get.to(PhotographersScreen(), transition: Transition.fadeIn);
              },
              icon: Icon(Icons.people_alt_outlined))
        ],
      ),
      body: Stack(children: <Widget>[
        // MessagesListView(),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: const ButtomTextBox(),
    );
  }
}

class MessagesListView extends StatelessWidget {
  MessagesListView({super.key});
  final controller = Get.find<FireStoreController>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: controller.messageController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var data = snapshot.requireData;
            if (snapshot.requireData.isEmpty) {
              return const Center(child: Text("No messages yet"));
            }

            return RefreshIndicator(
              onRefresh: () async {
                controller.getMoreMessages(data.last, data);
              },
              child: ListView.builder(
                itemCount: snapshot.data!.length,
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                itemBuilder: (context, index) {
                  MessageResponse resp = data[index];
                  List reply = resp.message.response;
                  return Column(
                    children: [
                      MessageTile(
                        response: resp,
                      ),
                      ...List.generate(reply.length,
                          (i) => ReplyWidget(reply: reply[i].toString()))
                    ],
                  );
                },
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        });
  }
}
