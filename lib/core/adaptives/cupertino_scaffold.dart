import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Adaptive Cupertino Scaffold
class AdaptiveCupertinoScaffold extends StatelessWidget {
  final Widget child;
  final String title;

  const AdaptiveCupertinoScaffold({required Key key, required this.child, required this.title})
      : assert(child != null),
        super(key: key);
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(this.title),
      ),
      child: this.child,
    );
  }
}
