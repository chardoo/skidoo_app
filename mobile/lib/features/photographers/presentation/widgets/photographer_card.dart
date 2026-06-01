import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerCard extends StatelessWidget {
  const PhotographerCard({
    super.key,
    required this.photographer,
    required this.onTap,
  });

  final PhotographerModel photographer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(button: true, child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
        child: Row(
          children: [
            _PhotographerAvatar(photographer: photographer, ext: ext),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photographer.name,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  if (photographer.rating != null && photographer.rating! > 0)
                    _RatingRow(rating: photographer.rating!, ext: ext)
                  else if (photographer.contact.isNotEmpty)
                    Text(
                      photographer.contact,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: ext.searchHintColor,
              size: 20.sp,
            ),
          ],
        ),
      ),
    ));
  }
}

class _PhotographerAvatar extends StatelessWidget {
  const _PhotographerAvatar({required this.photographer, required this.ext});

  final PhotographerModel photographer;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        photographer.imageUrl != null && photographer.imageUrl!.isNotEmpty;
    final initial =
        photographer.name.isNotEmpty ? photographer.name[0].toUpperCase() : '?';

    if (hasImage) {
      return CircleAvatar(
        radius: 24.r,
        backgroundImage: CachedNetworkImageProvider(photographer.imageUrl!),
        backgroundColor: ext.searchFieldFill,
      );
    }
    return CircleAvatar(
      radius: 24.r,
      backgroundColor: ext.accentGold.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: ext.accentGold,
          fontWeight: FontWeight.bold,
          fontSize: 18.sp,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.ext});
  final double rating;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < rating.floor()) {
            return Icon(Icons.star_rounded, color: ext.accentGold, size: 12.sp);
          } else if (i < rating && rating - i >= 0.5) {
            return Icon(Icons.star_half_rounded,
                color: ext.accentGold, size: 12.sp);
          } else {
            return Icon(Icons.star_outline_rounded,
                color: ext.searchHintColor, size: 12.sp);
          }
        }),
        SizedBox(width: 4.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: ext.accentGold,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
