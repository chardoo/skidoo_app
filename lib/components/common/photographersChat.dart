// import 'dart:async';
// import 'dart:io';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';

// import 'package:fluttertoast/fluttertoast.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';



// class ChatPage extends StatefulWidget {
//   const ChatPage();

//   @override
//   ChatPageState createState() => ChatPageState();
// }

// class ChatPageState extends State<ChatPage> {
//   late String currentUserId;

//   List<QueryDocumentSnapshot> listMessage = [];
//   int _limit = 20;
//   int _limitIncrement = 20;
//   String groupChatId = "";

//   File? imageFile;
//   bool isLoading = false;
//   bool isShowSticker = false;
//   String imageUrl = "";
//   String chardo = "app";
//   final TextEditingController textEditingController = TextEditingController();
//   final ScrollController listScrollController = ScrollController();
//   final FocusNode focusNode = FocusNode();

//   late ChatProvider chatProvider;
//   // late AuthProvider authProvider;
//   final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
//   final FirebaseStorage firebaseStorage = FirebaseStorage.instance;
//   // ignore: prefer_typing_uninitialized_variables
//   dynamic streaming;
//   @override
//   void initState() {
//     // TODO: implement initState
//     meer();
//     super.initState();
//   }

//   void meer() async {
//     print("helloe disdiodsiosdiods");
//     streaming = await firebaseFirestore
//         .collection(FirestoreConstants.pathMessageCollection)
//         .snapshots()
//         .length;
//     print("streaming");
//     print(streaming.toString());
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(body: buildListMessage(context));
//   }

//   Widget buildListMessage(BuildContext context) {
//     return StreamBuilder<QuerySnapshot>(
//       stream: streaming,
//       builder: (context, snapshot) {
//         if (snapshot.hasError) {
//           return const Text('Something went wrong');
//         }

//         if (!snapshot.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         return ListView(
//           children: snapshot.data!.docs
//               .map((DocumentSnapshot document) {
//                 Map<String, dynamic> data =
//                     document.data()! as Map<String, dynamic>;
//                 return ListTile(
//                   title: Text(data['content']),
//                 );
//               })
//               .toList()
//               .cast(),
//         );
//       },
//     );
//   }
// }
