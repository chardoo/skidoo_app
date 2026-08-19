import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';

/// The "♪ Title · Artist" chip over a feed card, and the mute control.
///
/// Sits in the caption column rather than floating on its own, because it is
/// part of what the post says about itself — the same reading order as the
/// event name and description above it.
///
/// Drawn light-on-dark unconditionally: it is always over media, under the
/// card's bottom scrim, never over the app's own background. Following the
/// theme here would make it invisible on half the photos in the feed.
class FeedMusicPill extends StatelessWidget {
  const FeedMusicPill({
    super.key,
    required this.track,
    required this.muted,
    required this.onToggleMute,
  });

  final MusicTrack track;
  final bool muted;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // Names the track as well as the action: a screen-reader user gets no
      // benefit from the sound itself, so the label is the only way this
      // conveys what is playing.
      label: muted
          ? 'Music muted. ${track.label}. Tap to unmute'
          : 'Now playing ${track.label}. Tap to mute',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onToggleMute,
        // The pill is small and the gesture is forgiving on purpose — this is
        // the only mute control on the screen.
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                muted
                    ? Icons.volume_off_rounded
                    : Icons.music_note_rounded,
                size: 13.sp,
                color: Colors.white,
              ),
              SizedBox(width: 6.w),
              // Bounded, so a long title truncates instead of pushing the pill
              // under the action rail. The caption column above it is already
              // inset from the rail by the card.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 180.w),
                child: Text(
                  track.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
