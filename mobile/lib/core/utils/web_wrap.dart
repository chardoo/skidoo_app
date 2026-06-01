import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Default width of the centred column used on web desktop/laptop views.
const double kWebColumnWidth = 530;

/// Wider column width used on content-heavy pages (gallery, search, profiles).
const double kWebColumnWidthWide = 750;

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
      // Shrink to the available width when the host is narrower than the
      // column (e.g. the 400px messages panel) so the page never overflows.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.hasBoundedWidth
              ? math.min(width, constraints.maxWidth)
              : width;
          return SizedBox(width: w, child: child);
        },
      ),
    ),
  );
}

