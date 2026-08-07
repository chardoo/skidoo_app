import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/utils/responsive.dart';

/// How big the cells are, and therefore how many fit across.
enum MediaGridDensity {
  /// Square thumbnails, three across on a phone — photos and videos, where
  /// the image is the whole cell.
  thumbnails,

  /// Taller-than-wide cards, two across on a phone — a square-ish image with a
  /// name, price or rating underneath.
  cards,
}

/// The grid every tiled collection in the app is built from.
///
/// Cells are uniform: same width, same height, whatever shape the photo behind
/// them is. Media used to be tiled as a masonry wall with each cell at its
/// image's own aspect ratio, which left ragged columns, stranded a short last
/// column, and meant no two photos could be compared at a glance. A photo's
/// real dimensions still matter where the photo is the subject rather than a
/// thumbnail — the full-screen viewers box themselves to it — but not here.
///
/// Everything that tiles content goes through this, so the column counts,
/// gutters and cell shapes stay in step and there is one place to change them.
/// Use [MediaGridSliver] inside a [CustomScrollView]; use [MediaGrid] where a
/// plain scrollable (or a non-scrolling block) is what's needed.
class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.density = MediaGridDensity.thumbnails,
    this.padding = EdgeInsets.zero,
    this.gutter,
    this.columns,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.primary,
  });

  /// The inset a grid gets when it is the page's main content: clear of the
  /// screen edges, with room at the bottom for the floating nav bar.
  static EdgeInsets get pagePadding =>
      EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h);

  final int itemCount;
  final Widget? Function(BuildContext context, int index) itemBuilder;
  final MediaGridDensity density;
  final EdgeInsets padding;

  /// Unscaled gap between cells. Defaults to the density's own — pass one only
  /// when a screen genuinely needs to differ.
  final double? gutter;

  /// Overrides the density's responsive count, for the few grids whose column
  /// count is fixed by what they are showing rather than by how much room
  /// there is — an album preview that must fill exactly one row, say.
  final int? columns;

  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    // Only when this grid is the thing scrolling. Nested in someone else's
    // scroll view it is one sliver among several, and the clearance belongs at
    // the end of that view — adding it here would open a gap mid-page.
    final clearance = shrinkWrap ? EdgeInsets.zero
        : EdgeInsets.only(bottom: bottomBarClearance(context));

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        gridDelegate: density.delegate(constraints.maxWidth,
            gutter: gutter, columns: columns),
        padding: padding + clearance,
        controller: controller,
        shrinkWrap: shrinkWrap,
        physics: physics,
        primary: primary,
        // Tiles are cheap to rebuild and expensive to keep alive; a screen's
        // worth of lookahead is the trade that keeps scrolling smooth without
        // holding decoded images for content nowhere near the viewport.
        cacheExtent: 800,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// [MediaGrid] as a sliver, for pages that scroll other things above the grid.
class MediaGridSliver extends StatelessWidget {
  const MediaGridSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.density = MediaGridDensity.thumbnails,
    this.padding = EdgeInsets.zero,
    this.gutter,
    this.columns,
  });

  final int itemCount;
  final Widget? Function(BuildContext context, int index) itemBuilder;
  final MediaGridDensity density;
  final EdgeInsets padding;
  final double? gutter;

  /// See [MediaGrid.columns].
  final int? columns;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid(
          gridDelegate: density.delegate(constraints.crossAxisExtent,
              gutter: gutter, columns: columns),
          delegate: SliverChildBuilderDelegate(
            itemBuilder,
            childCount: itemCount,
          ),
        ),
      ),
    );
  }
}

extension MediaGridMetrics on MediaGridDensity {
  /// Ideal cell width. Wider viewports get more columns rather than bigger
  /// cells, so a tablet or the centred web column shows more content instead
  /// of the same few blown up.
  double get minCellWidth => switch (this) {
        // Sized so an ordinary phone lands on three columns, the density the
        // designs use wherever media is tiled.
        MediaGridDensity.thumbnails => 118,
        MediaGridDensity.cards => 220,
      };

  /// Width ÷ height of a cell.
  double get aspectRatio => switch (this) {
        MediaGridDensity.thumbnails => 1,
        // Room for a line or two of text under a near-square image.
        MediaGridDensity.cards => 0.78,
      };

  /// Unscaled default gap between cells.
  double get defaultGutter => switch (this) {
        MediaGridDensity.thumbnails => 4,
        MediaGridDensity.cards => 12,
      };

  int columnsFor(double availableWidth) =>
      responsiveColumnCount(availableWidth, minColWidth: minCellWidth);

  SliverGridDelegateWithFixedCrossAxisCount delegate(
    double availableWidth, {
    double? gutter,
    int? columns,
  }) {
    final gap = gutter ?? defaultGutter;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns ?? columnsFor(availableWidth),
      mainAxisSpacing: gap.h,
      crossAxisSpacing: gap.w,
      childAspectRatio: aspectRatio,
    );
  }
}
