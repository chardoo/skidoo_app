import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

class AdaptiveTextField extends StatelessWidget {
  final TextEditingController textEditingController;
  final BoxDecoration boxDecoration;
  final InputDecoration inputDecoration;
  final TextInputType textInputType;
  final bool obscureText;

  const AdaptiveTextField(
      {required Key key,
      required this.textEditingController,
      this.boxDecoration = const BoxDecoration(),
      this.inputDecoration = const InputDecoration(),
      this.textInputType = TextInputType.text,
      this.obscureText = false})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Platform.isIOS
        ? CupertinoTextField(
            controller: textEditingController,
            decoration: boxDecoration,
            keyboardType: textInputType,
            obscureText: obscureText,
          )
        : TextField(
            controller: textEditingController,
            decoration: inputDecoration,
            obscureText: obscureText,
            keyboardType: textInputType,
          );
  }
}
