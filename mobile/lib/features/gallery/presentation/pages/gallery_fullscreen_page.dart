import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

class GalleryFullscreenPage extends StatefulWidget {
  /// Full set of photos so the viewer can page left/right, and the index of
  /// the one that was tapped.
  final List<Photo> photos;
  final int initialIndex;

  const GalleryFullscreenPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  @override
  State<GalleryFullscreenPage> createState() => _GalleryFullscreenPageState();
}

class _GalleryFullscreenPageState extends State<GalleryFullscreenPage> {
  bool _barsVisible = true;
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageCtrl = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toggleBars() => setState(() => _barsVisible = !_barsVisible);

  Photo get _photo => widget.photos[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final total = widget.photos.length;

    final page = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Swipeable, zoomable images ──────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: total,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _ZoomablePhoto(
              key: ValueKey(widget.photos[i].id),
              photo: widget.photos[i],
              ext: ext,
              onTap: _toggleBars,
            ),
          ),

          // ── Top bar ─────────────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _barsVisible ? 0 : -120.h,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
                  child: Row(
                    children: [
                      if (!kIsWeb)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white),
                          iconSize: 22.sp,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      const Spacer(),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_photo.eventName.isNotEmpty)
                              Text(
                                _photo.eventName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (total > 1)
                              Text(
                                '${_currentIndex + 1} / $total',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(width: 48.w),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom action bar ────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _barsVisible ? 0 : -140.h,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xDD000000), Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl.w, vertical: AppSpacing.xl.h),
                  child: MediaActionButtons(
                    // Keyed so the action row rebuilds for the current photo.
                    key: ValueKey(_photo.id),
                    imageId: _photo.id,
                    imageUrl: _photo.url,
                    eventName: _photo.eventName,
                    axis: Axis.horizontal,
                    showLike: false,
                    showComment: false,
                    onSend: () => GalleryShareSheet.show(
                      context,
                      imageUrl: _photo.url,
                      photoLabel: _photo.eventName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: Colors.black);
  }
}

/// A single zoomable image page. Owns its own [TransformationController] so the
/// zoom level resets when the user swipes to another photo. At rest (scale 1)
/// the image is contained, so horizontal drags pass through to the [PageView];
/// once zoomed in, the [InteractiveViewer] pans instead.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    super.key,
    required this.photo,
    required this.ext,
    required this.onTap,
  });

  final Photo photo;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: 'Photo', child: GestureDetector(
      onTap: widget.onTap,
      child: InteractiveViewer(
        transformationController: _transformCtrl,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.photo.url,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            placeholder: (_, __) => Center(
              child: CircularProgressIndicator(
                  color: widget.ext.accentGold, strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              color: widget.ext.searchHintColor,
              size: 64.sp,
            ),
          ),
        ),
      ),
    ));
  }
}
