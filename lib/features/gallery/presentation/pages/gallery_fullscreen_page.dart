import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class GalleryFullscreenPage extends StatefulWidget {
  final Photo photo;

  const GalleryFullscreenPage({super.key, required this.photo});

  @override
  State<GalleryFullscreenPage> createState() => _GalleryFullscreenPageState();
}

class _GalleryFullscreenPageState extends State<GalleryFullscreenPage> {
  bool _barsVisible = true;
  bool _isDownloading = false;
  bool _isSharing = false;
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

  Future<void> _download() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    context.read<CartBloc>().add(CartImageDownloaded(widget.photo.url));
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isDownloading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Downloading image…'),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.only(bottom: 80.h, left: 24.w, right: 24.w),
      ),
    );
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final text = widget.photo.eventName.isNotEmpty
          ? '${widget.photo.eventName} — check out this photo!\n${widget.photo.url}'
          : 'Check out this photo!\n${widget.photo.url}';
      await Share.share(text);
    } catch (_) {
      // Fallback: copy URL to clipboard
      await Clipboard.setData(ClipboardData(text: widget.photo.url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Link copied to clipboard'),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.only(bottom: 80.h, left: 24.w, right: 24.w),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
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
                      // Close
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        iconSize: 22.sp,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      // Event name
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
                      SizedBox(width: 48.w), // balance the back button
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
            bottom: _barsVisible ? 0 : -120.h,
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
                      horizontal: 32.w, vertical: 20.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Download
                      _ActionButton(
                        icon: _isDownloading
                            ? Icons.hourglass_top_rounded
                            : Icons.download_rounded,
                        label: 'Download',
                        accentColor: ext.accentGold,
                        onTap: _download,
                      ),

                      // Divider
                      Container(
                        width: 1,
                        height: 36.h,
                        color: Colors.white24,
                      ),

                      // Share
                      _ActionButton(
                        icon: _isSharing
                            ? Icons.hourglass_top_rounded
                            : Icons.ios_share_rounded,
                        label: 'Share',
                        accentColor: Colors.white,
                        onTap: _share,
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

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, color: accentColor, size: 22.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
