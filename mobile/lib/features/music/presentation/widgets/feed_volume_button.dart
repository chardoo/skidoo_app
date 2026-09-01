import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The feed's sound switch, in the band the navigation bar occupies.
///
/// It comes and goes with the chrome — a tap on the photo brings both up — so
/// the two controls a person reaches for while reading a feed arrive together
/// and leave together, rather than one of them sitting permanently on somebody
/// else's photograph.
///
/// The music pill lower down keeps its own small mute icon. Two ways to do one
/// thing, deliberately: the pill's icon says which state the *track* is in as
/// part of naming it, while this is the control you go to when you want the
/// sound off and are not reading anything.
class FeedVolumeButton extends StatelessWidget {
  const FeedVolumeButton({
    super.key,
    required this.muted,
    required this.onTap,
  });

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: muted ? 'Unmute music' : 'Mute music',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34.w,
          height: 34.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Deliberately dimmer than the nav bar beside it: this is a
            // secondary control on a photograph, not a destination.
            color: Colors.white.withValues(alpha: 0.22),
          ),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 18.sp,
          ),
        ),
      ),
    );
  }
}
