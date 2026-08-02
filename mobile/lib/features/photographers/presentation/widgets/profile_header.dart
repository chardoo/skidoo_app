import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

class PhotographerProfileHeader extends StatelessWidget {
  const PhotographerProfileHeader({super.key, required this.photographer, required this.ext});

  final PhotographerModel photographer;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final hasImage = photographer.imageUrl != null &&
        photographer.imageUrl!.isNotEmpty;
    final initial = photographer.name.isNotEmpty
        ? photographer.name[0].toUpperCase()
        : '?';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        if (hasImage)
          SkidooImage(
            imageUrl: photographer.imageUrl!,
            fit: BoxFit.cover,
            semanticLabel: 'Photographer photo',
            placeholder: (_, __) => ColoredBox(color: ext.cardSurface),
            errorWidget: (_, __, ___) => ColoredBox(color: ext.cardSurface),
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ext.cardSurface,
                  ext.accentGold.withValues(alpha: 0.25),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

        // Gradient overlay
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                ext.homeBackground.withValues(alpha: 0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Centred avatar (no bg image) or name initial over image
        if (!hasImage)
          Center(
            child: Container(
              width: 90.w,
              height: 90.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [ext.accentGold, ext.accentGold.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36.sp,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
