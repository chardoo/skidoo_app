import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/user_profile/data/album_download.dart';

/// How far through saving an album we are.
///
/// Its own widget, and public, because two screens draw it: the album being
/// saved, and the profile tab the album was opened from. Neither owns the
/// work — [AlbumDownloader] does — so both can show the same bar, and
/// leaving the album screen mid-run does not take the progress with it.
///
/// Draws nothing when idle, so it can be placed unconditionally.
class AlbumDownloadBar extends StatelessWidget {
  const AlbumDownloadBar({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return ValueListenableBuilder<AlbumDownloadProgress>(
      valueListenable: AlbumDownloader.progress,
      builder: (context, p, _) {
        if (p.isIdle) return const SizedBox.shrink();

        // "Saving 4 of 60" counts the one in flight, which is what somebody
        // watching expects to see; `done` is how many have finished.
        final label = p.running
            ? 'Saving ${(p.done + 1).clamp(1, p.total)} of ${p.total}'
            : p.cancelled
                ? 'Stopped — ${p.saved} of ${p.total} saved'
                : p.failed > 0
                    ? 'Saved ${p.saved}, ${p.failed} failed'
                    : 'Saved ${p.saved} to your gallery';

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 6.w, 10.h),
          color: ext.accentGold.withValues(alpha: 0.10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.eventName.isEmpty ? label : '${p.eventName} · $label',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                    SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: p.fraction,
                        minHeight: 4,
                        backgroundColor: ext.accentGold.withValues(alpha: 0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(ext.accentGold),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              if (p.running)
                TextButton(
                  onPressed: AlbumDownloader.instance.cancel,
                  child: const Text('Stop'),
                )
              else
                IconButton(
                  tooltip: 'Dismiss',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: AlbumDownloader.instance.reset,
                ),
            ],
          ),
        );
      },
    );
  }
}
