import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Public / private marker over the top-left of a photo in the Found viewer:
/// an eye when anyone can see it, an eye struck through when only the viewer
/// can, on a dark scrim so it stays legible over any image.
///
/// An icon rather than the words it used to spell out. "Public" and "Private"
/// are the same length, start in the same place and differ by a colour a lot
/// of people cannot tell apart, so the pill was read by its shape and its
/// shape never changed. An open eye and a closed one differ at a glance and
/// carry the meaning by themselves — the colour is then reinforcement rather
/// than the whole signal.
///
/// The colours stay as the design set them: public is amber (#FAC775), private
/// is the accent green (#1D9E75). The label survives for screen readers, which
/// need the word and not the glyph.
class FoundVisibilityBadge extends StatelessWidget {
  const FoundVisibilityBadge({super.key, required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final stateColor = isPublic ? ext.publicAmber : ext.accentGold;

    return Semantics(
      label: isPublic ? 'Public photo' : 'Private photo',
      // The word is gone from the screen but not from the tree: a bare icon
      // announces itself as nothing at all, and "eye" is not what a screen
      // reader should say here.
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.sm.w),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadius.pill.r),
        ),
        child: Icon(
          isPublic
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: stateColor,
          size: 16.sp,
        ),
      ),
    );
  }
}
