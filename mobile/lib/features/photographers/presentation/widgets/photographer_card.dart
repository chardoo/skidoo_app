import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

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

    return Semantics(button: true, label: photographer.name, child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 11.h),
        child: Row(
          children: [
            _PhotographerAvatar(photographer: photographer, ext: ext),
            SizedBox(width: AppSpacing.md.w),
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

/// Card used in the grid layout of the creators page: a large cover image with
/// the name + rating below. Works across mobile and web.
class PhotographerGridCard extends StatelessWidget {
  const PhotographerGridCard({
    super.key,
    required this.photographer,
    required this.onTap,
  });

  final PhotographerModel photographer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasImage =
        photographer.imageUrl != null && photographer.imageUrl!.isNotEmpty;
    final initial =
        photographer.name.isNotEmpty ? photographer.name[0].toUpperCase() : '?';

    return Semantics(button: true, label: photographer.name, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg.r),
      child: Container(
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: ext.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image fills the flexible top area; text takes its natural
            // height below so the tile never overflows its grid cell.
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: hasImage
                    ? SkidooImage(
                        imageUrl: photographer.imageUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: 'Photo by ${photographer.name}',
                        placeholder: (_, __) =>
                            ColoredBox(color: ext.searchFieldFill),
                        errorWidget: (_, __, ___) =>
                            _GridImageFallback(initial: initial, ext: ext),
                      )
                    : _GridImageFallback(initial: initial, ext: ext),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    photographer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  if (photographer.rating != null && photographer.rating! > 0)
                    _RatingRow(rating: photographer.rating!, ext: ext)
                  else
                    Text(
                      photographer.contact.isNotEmpty
                          ? photographer.contact
                          : 'No rating yet',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 11.sp,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _GridImageFallback extends StatelessWidget {
  const _GridImageFallback({required this.initial, required this.ext});
  final String initial;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ext.accentGold.withValues(alpha: 0.28),
            ext.accentGold.withValues(alpha: 0.08),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: ext.accentGold,
          fontWeight: FontWeight.bold,
          fontSize: 40.sp,
        ),
      ),
    );
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
            return Icon(Icons.star_rounded, color: Colors.amber, size: 12.sp);
          } else if (i < rating && rating - i >= 0.5) {
            return Icon(Icons.star_half_rounded,
                color: Colors.amber, size: 12.sp);
          } else {
            return Icon(Icons.star_outline_rounded,
                color: ext.searchHintColor, size: 12.sp);
          }
        }),
        SizedBox(width: AppSpacing.xs.w),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
