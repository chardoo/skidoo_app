import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Default width of the centred column used on web desktop/laptop views.
const double kWebColumnWidth = 480;

/// Wider column width used on content-heavy pages (gallery, search, profiles).
const double kWebColumnWidthWide = 600;

/// Constrains [child] to a centred column on web.
///
/// [width] defaults to [kWebColumnWidth] (480). Pass [kWebColumnWidthWide]
/// (600) for pages that benefit from extra horizontal space (gallery,
/// search results, photographer profiles, etc.).
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
  double width = kWebColumnWidth,
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
