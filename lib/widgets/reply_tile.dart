import 'package:flutter/material.dart';

class ReplyWidget extends StatelessWidget {
  const ReplyWidget({super.key, required this.reply});
  final String reply;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 100, top: 10, bottom: 10),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Color.fromARGB(255, 235, 176, 176),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            reply,
            style: const TextStyle(fontSize: 15, color: Colors.white),
          ),
        ),
      ),
    );
    ;
  }
}
