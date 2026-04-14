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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: ext.accentGold.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gold left accent bar
            Container(
              width: 4.w,
              height: 68.h,
              decoration: BoxDecoration(
                color: ext.accentGold,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                ),
              ),
            ),

            SizedBox(width: 14.w),

            // Avatar
            _PhotographerAvatar(photographer: photographer, ext: ext),

            SizedBox(width: 14.w),

            // Info
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photographer.name,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                
                    if (photographer.contact.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone_outlined,
                              size: 12.sp,
                              color: ext.searchHintColor),
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              photographer.contact,
                              style: TextStyle(
                                color: ext.searchHintColor,
                                fontSize: 12.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(Icons.mail_outline_rounded,
                            size: 12.sp,
                            color: ext.searchHintColor),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            photographer.email,
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 12.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Chevron
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Icon(
                Icons.chevron_right_rounded,
                color: ext.accentGold,
                size: 20.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotographerAvatar extends StatelessWidget {
  const _PhotographerAvatar({
    required this.photographer,
    required this.ext,
  });

  final PhotographerModel photographer;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        photographer.imageUrl != null && photographer.imageUrl!.isNotEmpty;
    final initial =
        photographer.name.isNotEmpty ? photographer.name[0].toUpperCase() : '?';

    if (hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: CachedNetworkImage(
          imageUrl: photographer.imageUrl!,
          width: 46.w,
          height: 46.h,
          fit: BoxFit.cover,
          placeholder: (_, __) => _InitialsAvatar(
              initial: initial, ext: ext),
          errorWidget: (_, __, ___) => _InitialsAvatar(
              initial: initial, ext: ext),
        ),
      );
    }
    return _InitialsAvatar(initial: initial, ext: ext);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initial, required this.ext});
  final String initial;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.w,
      height: 46.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            ext.accentGold,
            ext.accentGold.withValues(alpha: 0.6),
          ],
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
          fontSize: 22.sp,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.ext});
  final double? rating;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final r = rating ?? 0.0;
    return Row(
      children: [
        ...List.generate(5, (i) {
          if (i < r.floor()) {
            return Icon(Icons.star_rounded,
                color: ext.accentGold, size: 13.sp);
          } else if (i < r && r - i >= 0.5) {
            return Icon(Icons.star_half_rounded,
                color: ext.accentGold, size: 13.sp);
          } else {
            return Icon(Icons.star_outline_rounded,
                color: ext.searchHintColor, size: 13.sp);
          }
        }),
        SizedBox(width: 4.w),
        Text(
          r > 0 ? r.toStringAsFixed(1) : 'No rating',
          style: TextStyle(
            color: r > 0 ? ext.accentGold : ext.searchHintColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
