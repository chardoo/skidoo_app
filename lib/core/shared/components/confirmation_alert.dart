// ignore_for_file: must_be_immutable

import 'dart:ui';

import 'package:flutter/material.dart';

class ConfirmationAlert extends StatelessWidget {
  String title;
  String content;
  String cancelText;
  String confirmText;

  Function? confirmFunction;

  ConfirmationAlert({
    Key? key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.confirmText,
    required this.confirmFunction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.normal)),
        content: Wrap(
          children: [
            Column(
              children: [
                Text(
                  content,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFAAAAB3),
                            ),
                            child: Text(cancelText,
                                style: const TextStyle(fontSize: 17))),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            confirmFunction!();
                          },
                          child: Text(confirmText,
                              style: const TextStyle(fontSize: 17)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
// #AAAAB3
