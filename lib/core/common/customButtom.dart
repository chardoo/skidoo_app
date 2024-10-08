import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton(
      {super.key, required this.label, this.ontap, this.width, this.height,this.bgColor});
  final String label;
  final Function()? ontap;
  final double? width;
   final double? height;
  final Color? bgColor;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          onPressed: ontap,
          child: Text(label,
           style: const TextStyle(color: Colors.white),
          )),
    );
  }
}


class CustomButtonTwo extends StatelessWidget {
  const CustomButtonTwo(
      {super.key, required this.label, this.ontap, this.width, this.height,this.bgColor});
  final Widget label;
  final Function()? ontap;
  final double? width;
   final double? height;
  final Color? bgColor;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          onPressed: ontap,
          child:label),
    );
  }
}