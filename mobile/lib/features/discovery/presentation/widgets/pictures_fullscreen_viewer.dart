import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

class PicturesFullscreenViewer extends StatefulWidget {
  const PicturesFullscreenViewer({
    super.key,
    required this.pictures,
    required this.initialIndex,
  });

  final List<EventPicture> pictures;
  final int initialIndex;

  @override
  State<PicturesFullscreenViewer> createState() =>
      _PicturesFullscreenViewerState();
}

class _PicturesFullscreenViewerState extends State<PicturesFullscreenViewer> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.pictures.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final pic = widget.pictures[i];
              final isActive = i == _currentIndex;
              return pic.isVideo
                  ? _FullscreenVideo(
                      url: pic.url,
                      isActive: isActive,
                    )
                  : _FullscreenPhoto(url: pic.url);
            },
          ),

          // ── Top bar: close + counter ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: [
                    if (!kIsWeb)
                      Semantics(button: true, label: 'Close', child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close,
                              color: Colors.white, size: 20.sp),
                        ),
                      )),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.pictures[_currentIndex].isVideo)
                            Padding(
                              padding: EdgeInsets.only(right: 4.w),
                              child: Icon(Icons.videocam_rounded,
                                  color: Colors.white70, size: 12.sp),
                            ),
                          Text(
                            '${_currentIndex + 1} / ${widget.pictures.length}',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen photo ──────────────────────────────────────────────────────────

class _FullscreenPhoto extends StatelessWidget {
  const _FullscreenPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2),
          errorWidget: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 64.sp),
        ),
      ),
    );
  }
}

// ── Fullscreen video ──────────────────────────────────────────────────────────

class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({required this.url, required this.isActive});

  final String url;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SkidooVideoPlayer(
      url: url,
      isActive: isActive,
      autoPlay: true,
      loop: true,
      fit: BoxFit.contain,
      backgroundColor: Colors.black,
      showControls: true,
      allowFullscreen: false, // already fullscreen
    );
  }
}
