import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The smallest a thing a finger has to land on may be drawn.
///
/// 44pt is Apple's number (Human Interface Guidelines, "Layout") and the one
/// App Review measures against; Material's is 48dp, which this clears on
/// Android by way of each button's own tap-target padding.
const double kMinTapTarget = 44.0;

/// Control sizes, which are not the same thing as spacing.
///
/// Every size in this app goes through screenutil against a 390×844 design,
/// so `46.h` does not mean 46pt — it means 46 × (screen height / 844). On a
/// phone taller than the design that rounds *up* and nobody notices; on a
/// shorter one it rounds down hard. An iPhone SE is 667pt tall, so its factor
/// is 0.79, and the app's buttons were drawn there at 36pt, its "Follow"
/// chips at 25pt, and its filter chips at 25pt. All three are under the 44pt
/// minimum, which is what "controls that are difficult to use due to size"
/// means when App Review says it.
///
/// That is only ever wrong for a *control*. Shrinking the gaps between things
/// on a smaller screen is correct and should go on using [h] and [w] — it is
/// shrinking the thing the thumb is aiming at that isn't. So the floor lives
/// here rather than in screenutil, and the rule is: anything with an `onTap`,
/// an `onPressed` or a cursor in it is sized with [tapH] / [tapW]; anything
/// that is a gap, a rule, a scrim or a picture keeps [h] and [w].
///
/// On a large phone these are [h] and [w] unchanged — the floor only ever
/// lifts, so a design that is already comfortable is left exactly as drawn.
extension TapTargetSize on num {
  /// A control's height: [h], but never below [kMinTapTarget].
  double get tapH => math.max(h, kMinTapTarget);

  /// A control's width: [w], but never below [kMinTapTarget].
  ///
  /// For round and square controls — a close button, a send button — where
  /// both sides have to clear the minimum or the one that doesn't is the one
  /// the thumb misses by.
  double get tapW => math.max(w, kMinTapTarget);
}

/// Returns true when the device's shortest side is ≥ 600 px (tablet/iPad).
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// Calculates sensible grid column count from available pixel width.
/// minColWidth controls the ideal column size.
int responsiveColumnCount(double availableWidth, {double minColWidth = 220}) =>
    (availableWidth / minColWidth).floor().clamp(2, 6);

// Grids of tiled content don't call the above directly — they go through
// MediaGrid / MediaGridSliver (core/widgets/media_grid.dart), which owns the
// cell shapes, gutters and column counts so every such screen stays in step.

/// Space a scrollable has to leave below its last item so the floating bottom
/// nav bar doesn't come to rest on top of it.
///
/// Read from the ambient padding rather than added up from the bar's own
/// height. The shell runs `extendBody: true`, which makes Flutter report
/// `max(system inset, bottom bar height)` here — so this already accounts for
/// the home indicator, tracks the bar if its height ever changes, and is 0 on
/// a pushed route, which covers the bar and needs no clearance at all.
/// Hard-coded run-outs got all three of those wrong on some device.
double bottomBarClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;
