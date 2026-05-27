import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Default width of the centred column used on web desktop/laptop views.
const double kWebColumnWidth = 480;

/// Wider column width used on content-heavy pages (gallery, search, profiles).
const double kWebColumnWidthWide = 650;

/// Constrains [child] to a centred column on web.
///
/// [width] defaults to [kWebColumnWidthWide] (650). Use [kWebColumnWidth]
/// (480) for pages that should stay narrow — currently only the discovery
/// home page.
///
/// On non-web platforms the child is returned unchanged.
/// [backgroundColor] fills the area outside the column so the page has a
/// consistent background even on wide viewports.
///
/// Usage:
/// ```dart
/// return webWrap(page, backgroundColor: ext.homeBackground);
/// return webWrap(page, backgroundColor: ext.homeBackground, width: kWebColumnWidthWide);
/// ```
Widget webWrap(
  Widget child, {
  required Color backgroundColor,
  double width = kWebColumnWidthWide,
}) {
  if (!kIsWeb) return child;
  return ColoredBox(
    color: backgroundColor,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: width, child: child),
    ),
  );
}

