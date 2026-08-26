import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the music pill leads: what is playing, and the way to hear all of it.
///
/// The feed plays a short excerpt. Somebody who likes what they hear has
/// nowhere to go with that — the pill was a mute button and nothing else — so
/// this is the handover to the provider, and the reason it warns first.
///
/// **The warning is the point.** Tapping through leaves the app entirely and
/// lands in a browser or another app's UI. Doing that on a tap with no notice
/// is disorienting: people lose the feed they were scrolling and often do not
/// find their way back. "Stay here" is given the same weight as leaving,
/// because staying is usually what somebody wants.
class MusicTrackSheet extends StatelessWidget {
  const MusicTrackSheet({super.key, required this.track});

  final MusicTrack track;

  /// Opens the sheet for [track]. Returns once it closes.
  static Future<void> show(BuildContext context, MusicTrack track) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicTrackSheet(track: track),
    );
  }

  Future<void> _openProvider(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final url = Uri.tryParse(track.pageUrl);

    // Closed first, whatever happens next. Leaving the sheet up behind an
    // external app means coming back to a modal still sitting over the feed.
    navigator.pop();

    if (url == null || track.pageUrl.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('This track has no page to open.')),
      );
      return;
    }

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open Audiomack.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xl.w, AppSpacing.md.h, AppSpacing.xl.w, AppSpacing.lg.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle.
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),

              // The mark. Headphones rather than the artwork: a track that
              // carries none would leave a hole here, and the sheet is about
              // where the music goes rather than what it looks like.
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ext.accentGold,
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: Colors.white,
                  size: 30.sp,
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),

              Text(
                track.title.isNotEmpty ? track.title : 'Music',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (track.artist.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  track.artist,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 15.sp,
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.lg.h),

              Text(
                "You'll be redirected to Audiomack to listen to the full song.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.greetingColor.withValues(alpha: 0.75),
                  fontSize: 14.sp,
                  height: 1.4,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),

              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: () => _openProvider(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill.r),
                    ),
                  ),
                  child: Text(
                    'Listen on Audiomack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xs.h),

              // Not a cancel link tucked in a corner. Staying is the ordinary
              // choice — most people tap the pill to see what the song is, not
              // to leave — so it reads as an answer rather than a way out.
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Stay here',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
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
