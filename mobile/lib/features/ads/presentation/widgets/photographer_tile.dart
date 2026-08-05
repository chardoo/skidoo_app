import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographer_meta.dart';

/// One photographer in the list of who answered a request.
///
/// Lives in its own file so it can be pumped — it is drawn, not computed, and
/// the analyzer sees none of what can go wrong here. See the widget test for
/// why the selected rule is a child rather than a left `BorderSide`.
class PhotographerTile extends StatelessWidget {
  const PhotographerTile({
    super.key,
    required this.person,
    required this.ext,
    required this.onTap,
    this.highlighted = false,
    this.onMessage,
  });

  final RequestInterest person;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  /// The chosen one — a green rule down the left edge, as the design marks it.
  final bool highlighted;
  final VoidCallback? onMessage;

  String get _name => (person.name?.trim().isNotEmpty ?? false)
      ? person.name!.trim()
      : 'Photographer';

  PhotographerMeta get _meta => PhotographerMeta(
        ext: ext,
        location: person.location,
        followerCount: person.followerCount,
        rating: person.rating,
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$_name, ${_meta.semanticsLabel}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
          // Clipped so the rule below takes the card's rounded corners. It is a
          // child rather than a left BorderSide because a Border that is not
          // uniform cannot carry a borderRadius — that combination throws.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  if (highlighted)
                    Container(width: 3.w, color: ext.accentGold),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.md.h,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22.r,
                            backgroundColor: ext.avatarBackground,
                            backgroundImage:
                                (person.profileUrl?.isNotEmpty ?? false)
                                    ? NetworkImage(person.profileUrl!)
                                    : null,
                            child: (person.profileUrl?.isNotEmpty ?? false)
                                ? null
                                : Text(
                                    _name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: ext.avatarForeground,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                          ),
                          SizedBox(width: AppSpacing.md.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ext.greetingColor,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 3.h),
                                _meta,
                              ],
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          // A labelled pill once there is someone to talk to;
                          // a chevron while the row is still just a way in.
                          if (onMessage != null)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: onMessage,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w, vertical: 7.h,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      ext.accentGold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  'Message',
                                  style: TextStyle(
                                    color: ext.accentGold,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          else
                            Icon(Icons.chevron_right_rounded,
                                color: ext.searchHintColor, size: 20.r),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
