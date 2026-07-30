import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_stage.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final total = widget.photos.length;

    final page = Scaffold(
      // Follows the app theme. The surround is the page's own background, and
      // the overlays that sit *on* the photo (badge, action rail, meta bar)
      // stay light-on-scrim in both themes — the photo underneath is arbitrary.
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Column(
          children: [
         
                _ViewerTopBar(index: _index,  total: total),
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

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SizedBox(
      height: 48.h,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: ext.greetingColor),
              iconSize: 22.sp,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Center(
  // One label for the whole counter. Split across spans it reads out as
  // "1", "of", "2" — three fragments — and the WidgetSpan leaves a
  // placeholder character in the middle of the plain text.
  child: Semantics(
    label: '${index + 1} of $total',
    child: ExcludeSemantics(
  child:

  Text.rich(
    TextSpan(
      style: TextStyle(
        color: ext.greetingColor.withValues(alpha: 0.7),
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
      children: [
        TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: Transform.translate(
    offset: Offset(0, 1),  // positive = down; tweak by 0.5–1.5
    child: Text(
      ' of ',
      style: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 15.sp,
        color: ext.greetingColor.withValues(alpha: 0.7),
      ),
    ),
  ),
),
        TextSpan(
          text: '$total',
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
  ),
    ),
  ),
)
        ],
      ),
    );
  }
}


