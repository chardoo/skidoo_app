import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';
import 'package:jperg_app/models/photographer/photographer_sample.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class SamplesFullscreenPage extends StatefulWidget {
  const SamplesFullscreenPage({
    super.key,
    required this.samples,
    required this.initialIndex,
  });

  final List<PhotographerSample> samples;
  final int initialIndex;

  @override
  State<SamplesFullscreenPage> createState() => _SamplesFullscreenPageState();
}

class _SamplesFullscreenPageState extends State<SamplesFullscreenPage> {
  late final PageController _page;
  late int _current;

  /// Frozen while the sample on screen is zoomed in, or panning across it
  /// would page to the next one instead. See ZoomableArea.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _page = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.samples.length,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) {
              final sample = widget.samples[i];

              // A video sample plays here rather than being handed to an image
              // loader, which could only ever show a broken frame.
              if (sample.isVideo) {
                return JpergVideoPlayer(
                  url: sample.url,
                  isActive: i == _current,
                  autoPlay: true,
                  loop: true,
                  fit: BoxFit.contain,
                  showControls: true,
                  backgroundColor: Colors.black,
                  listenToPauseNotifier: true,
                );
              }

              return ZoomablePhoto(
                key: ValueKey(sample.id),
                imageUrl: sample.url,
                // `POST/PUT /photographer/samples` records these, so a sample
                // opens at its real shape rather than resolving into it.
                knownAspect: sample.aspectRatio,
                semanticLabel: 'Photographer sample',
                isActive: i == _current,
                onZoomChanged: (zoomed) {
                  if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                },
                errorWidget: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image_rounded,
                      color: Colors.white24, size: 60),
                ),
              );
            },
          ),

          // Close button + counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Semantics(button: true, label: 'Close', child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: EdgeInsets.only(left: AppSpacing.lg.w),
                    width: 36.w,
                    height: 36.h,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                )),
                const Spacer(),
                Container(
                  margin: EdgeInsets.only(right: AppSpacing.lg.w),
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: AppSpacing.xs.h),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                  child: Text(
                    '${_current + 1} / ${widget.samples.length}',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: Colors.black);
  }

}
