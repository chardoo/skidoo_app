import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyTextField extends StatelessWidget {
  MyTextField(
      {super.key,
      this.controller,
      this.onChanged,
      // this.obsureText = false,
      this.trailing,
      this.label,
      this.line,
      this.readOnly,
      this.ontap,
      this.bgColor,
      this.onEditingComplete,
      this.keyboadType,
      this.validator,
      this.onSubmited,
      this.obscureText = false});
  final TextEditingController? controller;
  // final bool obsureText;
  final bool? readOnly;
  final bool obscureText;
  final Widget? trailing;
  final TextInputType? keyboadType;
  final String? label;
  final Color? bgColor;
  final int? line;
  final Function()? ontap;
  final Function(String val)? onChanged;
  final Function()? onEditingComplete;
  String? Function(String?)? validator;
   String? Function(String?)? onSubmited;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onFieldSubmitted: onSubmited,
      validator: validator,
      controller: controller,
      keyboardType: keyboadType ?? TextInputType.text,
      //obscureText: obsureText,
      obscureText: obscureText,
      onEditingComplete: onEditingComplete,
      onTap: ontap,
      readOnly: readOnly ?? false,
      onChanged: onChanged,
      decoration: InputDecoration(
        fillColor: bgColor,
        filled: bgColor != null,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 18.w, vertical: line != null && line! > 1 ? 10.h : 0),
        suffixIcon: trailing,
        labelText: label,
      ),
    );
  }
}
