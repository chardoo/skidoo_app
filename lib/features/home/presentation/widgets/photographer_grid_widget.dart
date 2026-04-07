import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/features/home/presentation/widgets/photographer_card_widget.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerGridWidget extends StatelessWidget {
  const PhotographerGridWidget({super.key, required this.photographers});

  final List<PhotographerModel> photographers;

  // Staggered heights that alternate to mimic the masonry look in the design.
  // Pattern repeats across the grid.
  static const _heights = [220.0, 175.0, 190.0, 240.0, 170.0, 215.0];

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
      cacheExtent: 800,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: photographers.length,
      itemBuilder: (context, index) {
        final height = _heights[index % _heights.length].h;
        return PhotographerCardWidget(
          photographer: photographers[index],
          height: height,
        );
      },
    );
  }
}
