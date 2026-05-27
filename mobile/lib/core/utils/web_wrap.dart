import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Width of the centred column used on web desktop/laptop views.
const double kWebColumnWidth = 480;

/// Constrains [child] to a [kWebColumnWidth]-wide centred column on web.
///
/// On non-web platforms the child is returned unchanged.
/// [backgroundColor] fills the area outside the column so the page has a
/// consistent background even on wide viewports.
///
/// Usage:
/// ```dart
/// return webWrap(page, backgroundColor: ext.homeBackground);
/// ```
Widget webWrap(Widget child, {required Color backgroundColor}) {
  if (!kIsWeb) return child;
  return ColoredBox(
    color: backgroundColor,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: kWebColumnWidth, child: child),
    ),
  );
}
