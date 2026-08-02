import 'package:flutter/widgets.dart';

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
