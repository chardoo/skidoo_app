import 'dart:ui';

import 'package:flutter/material.dart';

class LoadingSpinner extends StatelessWidget {
  const LoadingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Center(
            child: Wrap(
              children: [
                Container(
                    width: 153,
                    height: 156,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(14))),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.secondary,
                    )),
              ],
            ),
          ),
        ));
  }
}
