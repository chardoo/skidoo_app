import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_stage.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The viewer is always dark, in either app theme — a photo reads best on a
/// dark surround and every full-screen media view in the app agrees, so it
/// takes the dark palette directly rather than the ambient one.
///
/// Dark here is the design's #111110, **not** pure black: the product palette
/// is a warm near-black throughout, and true black beside it reads as a
/// different surface rather than the same one.
const _palette = AppThemeExtension.dark;

/// Full-screen viewer for an album's photos: "n of total" in the app bar, the
/// photo with its badge/action-rail/photographer overlays, and a filmstrip of
/// the whole album along the bottom. Swiping the photo and tapping a
/// thumbnail are two ways to drive the same index.
class FoundPhotoViewerPage extends StatefulWidget {
  const FoundPhotoViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onViewAlbum,
  });

  final List<Photo> photos;
  final int initialIndex;

  /// Shown as "View album" on the photo. Left null when the viewer was pushed
  /// from the album page itself.
  final VoidCallback? onViewAlbum;

  @override
  State<FoundPhotoViewerPage> createState() => _FoundPhotoViewerPageState();
}

class _FoundPhotoViewerPageState extends State<FoundPhotoViewerPage> {
  late int _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
  late final PageController _pageCtrl = PageController(initialPage: _index);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;

    final page = Scaffold(
      backgroundColor: _palette.homeBackground,
      body: SafeArea(
        child: Column(
          children: [
            _ViewerTopBar(label: '${_index + 1} of $total'),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => FoundPhotoStage(
                  key: ValueKey('stage_${widget.photos[i].id}'),
                  photo: widget.photos[i],
                  isActive: i == _index,
                  onViewAlbum: widget.onViewAlbum,
                ),
              ),
            ),
            if (total > 1) ...[
              SizedBox(height: AppSpacing.lg.h),
              FoundPhotoFilmstrip(
                photos: widget.photos,
                activeIndex: _index,
                onTap: _goTo,
              ),
            ],
            // Clears the floating bottom nav bar.
            SizedBox(height: 88.h),
          ],
        ),
      ),
    );

    return webWrap(page, backgroundColor: _palette.homeBackground);
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.h,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              // Not const: field access on a const object isn't itself a
              // constant expression in Dart.
              icon: Icon(Icons.arrow_back_rounded,
                  color: _palette.greetingColor),
              iconSize: 22.sp,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                // The counter sits back from the back arrow in the design —
                // sampled at #B4B2A9 against the arrow's full-strength
                // #F7F7F2. It's a position indicator, not a control.
                color: _palette.greetingColor.withValues(alpha: 0.7),
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                // Fixed-width digits: without these, "9 of 14" → "10 of 14"
                // widens the string and the Center re-centres it, so the
                // counter visibly jumps sideways on every swipe.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
