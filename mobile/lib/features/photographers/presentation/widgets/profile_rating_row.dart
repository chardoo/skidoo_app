import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class PhotographerRatingRow extends StatelessWidget {
  const PhotographerRatingRow({super.key, required this.rating, required this.ext});
  final double? rating;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final r = rating ?? 0.0;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < r.floor()) {
            return Icon(Icons.star_rounded, color: Colors.amber, size: 16.sp);
          } else if (i < r && r - i >= 0.5) {
            return Icon(Icons.star_half_rounded,
                color: Colors.amber, size: 16.sp);
          } else {
            return Icon(Icons.star_outline_rounded,
                color: ext.searchHintColor, size: 16.sp);
          }
        }),
        SizedBox(width: 6.w),
        Text(
          r > 0 ? '${r.toStringAsFixed(1)} / 5.0' : 'No rating yet',
          style: TextStyle(
            color: r > 0 ? ext.greetingColor : ext.searchHintColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
