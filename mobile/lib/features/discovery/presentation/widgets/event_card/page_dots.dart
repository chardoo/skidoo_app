import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Smooth Instagram-style carousel dots: width and opacity interpolate
/// continuously with the [PageController]'s fractional `.page` value so the
/// animation tracks the finger.
class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.totalCount,
    required this.controller,
    required this.maxRevealedPage,
  });

  final int totalCount;
  final PageController controller;

  /// The highest page index the user has swiped to so far.
  /// Dots are revealed up to this index, with a minimum of min(3, totalCount).
  final int maxRevealedPage;

  @override
  Widget build(BuildContext context) {
    // Show min(3, totalCount) dots immediately. Reveal the next dot one step
    // early — when the user reaches the last-but-one of the currently shown
    // dots — so there's always one more waiting ahead.
    final revealedCount = math.min(
      totalCount,
      math.max(math.min(3, totalCount), maxRevealedPage + 3),
    );

    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final page =
            controller.hasClients ? (controller.page ?? 0.0) : 0.0;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(revealedCount, (i) {
              final t = (page - i).abs().clamp(0.0, 1.0);
              // Active dot is wider; interpolated continuously while swiping.
              final w = 20.w - 14.w * t;
              final color = Color.lerp(
                Colors.white,
                Colors.white.withValues(alpha: 0.35),
                t,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
