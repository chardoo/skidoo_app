import 'package:flutter/material.dart';

class MainButton extends StatelessWidget {
  String title;
  Function onPressed;
  bool disabled = false;
  bool isLoading = false;
   MainButton(
      {super.key,
      required this.title,
      required this.onPressed,
      this.disabled = false,
      this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.only(top: 20, left: 15, right: 15, bottom: 10),
      child: ElevatedButton(
        onPressed: disabled ? null : () => onPressed(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          disabledBackgroundColor: const Color(0xFFAAAAB2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 1,
                ),
              )
            : Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
      ),
    );
  }
}


