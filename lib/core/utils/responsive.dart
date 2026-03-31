import 'package:flutter/widgets.dart';

/// Returns true when the device's shortest side is ≥ 600 px (tablet/iPad).
bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

/// Calculates sensible masonry/grid column count from available pixel width.
/// minColWidth controls the ideal column size.
int responsiveColumnCount(double availableWidth, {double minColWidth = 220}) =>
    (availableWidth / minColWidth).floor().clamp(2, 6);
