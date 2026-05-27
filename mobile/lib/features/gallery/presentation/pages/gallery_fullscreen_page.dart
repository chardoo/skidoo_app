import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/common/widgets/get_app_sheet.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class GalleryFullscreenPage extends StatefulWidget {
  final Photo photo;

  const GalleryFullscreenPage({super.key, required this.photo});

  @override
  State<GalleryFullscreenPage> createState() => _GalleryFullscreenPageState();
}

class _GalleryFullscreenPageState extends State<GalleryFullscreenPage> {
  bool _barsVisible = true;
  final TransformationController _transformCtrl = TransformationController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _transformCtrl.dispose();
    super.dispose();
  }

  void _toggleBars() => setState(() => _barsVisible = !_barsVisible);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Zoomable image ──────────────────────────────────────────────
          GestureDetector(
            onTap: _toggleBars,
            child: InteractiveViewer(
              transformationController: _transformCtrl,
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.photo.url,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  placeholder: (_, __) => Center(
                    child: CircularProgressIndicator(
                        color: ext.accentGold, strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: ext.searchHintColor,
                    size: 64.sp,
                  ),
                ),
              ),
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
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        iconSize: 22.sp,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (widget.photo.eventName.isNotEmpty)
                        Flexible(
                          child: Text(
                            widget.photo.eventName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
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
                      horizontal: 24.w, vertical: 20.h),
                  child: MediaActionButtons(
                    imageId: widget.photo.id,
                    imageUrl: widget.photo.url,
                    eventName: widget.photo.eventName,
                    axis: Axis.horizontal,
                    showLike: false,
                    showComment: false,
                    onSend: () {
                      if (kIsWeb) {
                        final ext = Theme.of(context).extension<AppThemeExtension>()!;
                        GetAppSheet.show(context, ext: ext);
                        return;
                      }
                      GalleryShareSheet.show(
                        context,
                        imageUrl: widget.photo.url,
                        photoLabel: widget.photo.eventName,
                      );
                    },
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
