import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// "Explore event photos →" — the way from a feed post into the event's
/// photos, and since the feed's tap now belongs to the chrome, the only way.
///
/// It appears where the automatic slide stops (the third photo) and again on
/// every third photo after that as the person swipes, plus on the last one.
/// The rhythm is the point: an offer that stood on every photo would be
/// wallpaper, and one that appeared only once would be missed by anyone who
/// swiped past it.
///
/// The [label] moves with what is behind it. A post with one photo has no
/// album to explore, and offering to explore it promises a set that is not
/// there — see [ExploreEventCta.forOneImage].
class ExploreEventCta extends StatelessWidget {
  const ExploreEventCta({
    super.key,
    required this.onTap,
    this.label = 'Explore event photos',
  });

  /// What a post with a single photo says instead: there is nothing to browse,
  /// only this one thing to see properly.
  static const forOneImage = 'View full image';

  /// And when that single thing is a clip.
  static const forOneVideo = 'View full video';

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        // Real glass, the same treatment as the rest of the chrome that floats
        // over media — see [GlassSurface], which frosts on iOS and falls back
        // to a tonal surface where a blur is not what the platform wants.
        //
        // It used to be a flat 62 % black pill that only *called* itself glass.
        // Over a photo that is a grey slab: there is nothing being blurred
        // behind it, so the picture stops at its edge instead of carrying
        // through it. This sits in the middle of the frame, which is the worst
        // place for a widget to punch a hole in the image it is inviting you
        // into.
        //
        // `onDark` is forced rather than read from the theme. The feed wraps
        // itself in [DarkMediaSurface] so the answer is the same today either
        // way, but the ground under this pill is a photograph whatever the app
        // is set to — the decision belongs to what is behind it, not to a theme
        // a future caller might mount it under.
        child: GlassSurface(
          borderRadius: BorderRadius.circular(999),
          onDark: true,
          // Where the platform does not frost, the fallback is a scrim rather
          // than the opaque tonal surface the nav bar wears. The photo has to
          // come through — dimmed, not hidden — because this pill stands in the
          // middle of it. 62 % is what the hand-rolled version used and it
          // reads white text over anything; see [GlassSurface.tonalOpacity].
          tonalOpacity: 0.62,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }
}
