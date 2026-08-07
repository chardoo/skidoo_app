import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/models/photographer/photographer_sample.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

class PhotographerSampleTile extends StatelessWidget {
  const PhotographerSampleTile({super.key, required this.sample, required this.onTap});

  final PhotographerSample sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: sample.isVideo ? 'Sample video' : 'Sample photo', child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xs.r),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            JpergImage(
              imageUrl: sample.url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const JpergImagePlaceholder(),
              errorWidget: (_, __, ___) => Container(
                color: JpergImagePlaceholder.colorOf(context),
                child: const Icon(Icons.broken_image_rounded,
                    color: Colors.white24, size: 24),
              ),
            ),
            // Same badge the found / search grids use, so a clip reads as one
            // wherever it's tiled.
            if (sample.isVideo)
              Positioned(
                right: 6.w,
                top: 6.h,
                child: Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 18.sp),
              ),
          ],
        ),
      ),
    ));
  }
}
