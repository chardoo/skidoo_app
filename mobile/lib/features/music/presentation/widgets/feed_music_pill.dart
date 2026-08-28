import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';

/// The "♪ Title · Artist — powered by Audiomack" chip over a feed card.
///
/// Sits in the caption column rather than floating on its own, because it is
/// part of what the post says about itself — the same reading order as the
/// event name and description above it.
///
/// Drawn light-on-dark unconditionally: it is always over media, under the
/// card's bottom scrim, never over the app's own background. Following the
/// theme here would make it invisible on half the photos in the feed.
///
/// ## Two taps, not one
///
/// The note icon mutes; the rest of the pill opens the track sheet.
///
/// The design shows one chip and one obvious destination — the sheet — but
/// this pill was previously the *only* mute control anywhere on the feed, and
/// making the whole thing open a sheet would have left somebody scrolling in
/// public with no way to silence it. Splitting the target keeps both: the icon
/// is the thing that already looked like a sound control, and it changes to a
/// struck-through speaker when muted, so its job stays legible.
class FeedMusicPill extends StatelessWidget {
  const FeedMusicPill({
    super.key,
    required this.track,
    required this.muted,
    required this.onToggleMute,
    required this.onOpenTrack,
  });

  final MusicTrack track;
  final bool muted;
  final VoidCallback onToggleMute;

  /// Opens the track sheet — what the song is, and where to hear all of it.
  final VoidCallback onOpenTrack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Mute ──────────────────────────────────────────────────────
          Semantics(
            button: true,
            // Names the track as well as the action: a screen-reader user gets
            // no benefit from the sound itself, so the label is the only way
            // this conveys what is playing.
            label: muted
                ? 'Music muted. ${track.label}. Tap to unmute'
                : 'Now playing ${track.label}. Tap to mute',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onToggleMute,
              // Small target, forgiving gesture — and padding rather than a
              // bare icon so the tap area is a thumb rather than a glyph.
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                child: Icon(
                  muted ? Icons.volume_off_rounded : Icons.music_note_rounded,
                  size: 13.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // ── Track, and where it came from ─────────────────────────────
          //
          // Flexible so the pill can never be wider than the space it is given.
          // Without it the row asked for its natural width and overflowed on a
          // narrower screen — 9 px on a 6.1", and the yellow-and-black stripes
          // land across the bottom of somebody's photograph.
          Flexible(
            child: Semantics(
            button: true,
            label: 'About ${track.label}. Tap to open',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onOpenTrack,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Capped *and* flexible, and it needs both.
                    //
                    // The cap is the design's: a long title truncates rather
                    // than running the pill across the card, which is why it
                    // reads "Regular – Mercy C…" with the whole thing a tap
                    // away in the sheet. The caption column above is already
                    // inset from the action rail by the card.
                    //
                    // The Flexible is what lets the title give way when even
                    // the cap does not fit. A fixed 118 beside an attribution
                    // that cannot shrink is wider than a narrow screen allows,
                    // and the row then overflowed — 9 px on a 6.1", drawn as
                    // yellow-and-black stripes across somebody's photograph.
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 118.w),
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
                    ),
                    SizedBox(width: 8.w),
                    // A hairline rather than a bullet: the attribution is a
                    // different kind of thing from the title, and a separator
                    // that reads as punctuation would run the two together.
                    Container(
                      width: 1,
                      height: 11.h,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    SizedBox(width: 8.w),
                    // Second to give way, after the title and before the name.
                    //
                    // The order is deliberate. On a narrow card something has
                    // to yield, and of the three this is the one that carries
                    // no information: "Audiomack" alone still credits them,
                    // where "powered by" alone credits nobody. So the title
                    // shrinks first, these two words second, and the provider's
                    // name is the last thing standing — it is the attribution
                    // the licence actually rests on.
                    Flexible(
                      child: Text(
                        'powered by',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    // Set in the provider's own weight rather than shipped as
                    // artwork: there is no Audiomack asset in the bundle, and
                    // an approximation of somebody's logo is worse than their
                    // name plainly written.
                    Text(
                      'Audiomack',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
