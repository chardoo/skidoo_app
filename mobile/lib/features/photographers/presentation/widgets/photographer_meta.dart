import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';

/// How the line is arranged. The parts are the same either way — that is the
/// point of it being one widget.
enum PhotographerMetaVariant {
  /// A row in a list: `★ 4.5  Paris | 850 followers`. The rating leads,
  /// because in a list it is what the eye is comparing.
  row,

  /// Under the name on a profile: `⌖ Accra, Ghana | 1.2K followers`, with the
  /// follower count in the accent and the rating carried separately by
  /// [RatingPill] over on the right.
  header,
}

/// Where a photographer is, how many follow them, and what they are rated.
///
/// The same three facts sit under every photographer's name in the request
/// flow — the list on Request Details, the profile behind it, Select New
/// Photographer, the review composer — and they were written out four times,
/// which is how the composer ended up showing the location alone with no
/// followers and no rating at all.
class PhotographerMeta extends StatelessWidget {
  const PhotographerMeta({
    super.key,
    required this.ext,
    this.location,
    this.followerCount = 0,
    this.rating,
    this.variant = PhotographerMetaVariant.row,
  });

  final AppThemeExtension ext;
  final String? location;
  final int followerCount;

  /// Null until somebody has rated them. No star is drawn in that case — an
  /// empty one reads as a bad score.
  final double? rating;

  final PhotographerMetaVariant variant;

  bool get _hasLocation => location?.trim().isNotEmpty ?? false;

  String get _followers => '${compactCount(followerCount)} followers';

  /// What a screen reader should hear: one sentence, not three fragments.
  String get semanticsLabel => [
        if (rating != null) 'rated ${rating!.toStringAsFixed(1)}',
        if (_hasLocation) location!.trim(),
        _followers,
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    final grey = TextStyle(color: ext.searchHintColor, fontSize: 12.sp);

    if (variant == PhotographerMetaVariant.header) {
      return Row(
        children: [
          if (_hasLocation) ...[
            Icon(Icons.place_outlined, size: 13.r, color: ext.searchHintColor),
            SizedBox(width: 3.w),
          ],
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  if (_hasLocation) ...[
                    TextSpan(text: location!.trim()),
                    const TextSpan(text: '   |   '),
                  ],
                  // The follower count carries the accent here, as the design
                  // draws it — it is the number worth reading on a profile.
                  TextSpan(
                    text: _followers,
                    style: TextStyle(
                      color: ext.accentGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: grey,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        if (rating != null) ...[
          Icon(Icons.star_rounded, size: 13.r, color: ext.accentGold),
          SizedBox(width: 2.w),
          Text(
            rating!.toStringAsFixed(1),
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8.w),
        ],
        Flexible(
          child: Text(
            _hasLocation ? '${location!.trim()}  |  $_followers' : _followers,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: grey,
          ),
        ),
      ],
    );
  }
}

/// `★ 4.7` in its own tinted pill — the profile's rating, set apart from the
/// line because it is the one number people scan a profile for.
///
/// Renders nothing at all when [rating] is null rather than an empty star.
class RatingPill extends StatelessWidget {
  const RatingPill({super.key, required this.ext, required this.rating});

  final AppThemeExtension ext;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 14.r, color: ext.accentGold),
          SizedBox(width: 3.w),
          Text(
            rating!.toStringAsFixed(1),
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
