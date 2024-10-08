
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// import 'packag
class SpinnerButton extends StatelessWidget {
  const SpinnerButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.black,
        ),
        onPressed: null,
        child: Center(
            child: Image.asset(
          'assets/images/spinner.gif', // Put your gif into the assets folder
          width: 200,
          height: 50,
        )));
  }
}
