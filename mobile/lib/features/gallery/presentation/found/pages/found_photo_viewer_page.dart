import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/widgets/image_aspect.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/dark_media_surface.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_stage.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

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
    this.showSocialActions = true,
  });

  final List<Photo> photos;
  final int initialIndex;

  /// Whether to offer the like/comment/save/share rail. False where the photos
  /// are someone's work on show rather than photos of you — see
  /// [FoundPhotoStage.showSocialActions].
  final bool showSocialActions;

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

  /// Dark in a light app as well: the photo is the whole point of this screen,
  /// and the surround's job is to get out of its way. It is also most of the
  /// screen — the media is boxed to its own shape — and the overlays that sit
  /// *on* it (badge, action rail, meta bar) are white-on-scrim for an arbitrary
  /// photo underneath, which a pale surround undercuts.
  @override
  Widget build(BuildContext context) =>
      DarkMediaSurface(child: Builder(builder: _buildViewer));

  Widget _buildViewer(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final total = widget.photos.length;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Column(
          children: [
         
                _ViewerTopBar(index: _index,  total: total),
            _buildMedia(total),
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

  /// The pager: centred in the space between the top bar and the filmstrip,
  /// and exactly as tall as the current photo needs.
  ///
  /// Two separate things, and both matter. The media sits in the middle of the
  /// page — that is the design, and it is what makes a wide shot and a tall one
  /// feel like the same screen. But its *height* is the image's own
  /// (`width ÷ aspect ratio`) rather than every pixel the column had left, so
  /// the pager's bounds are the photo's bounds: the overlays hang off the
  /// image's edges, swipes and taps land on the photo rather than on empty
  /// background, and a page of an unknown shape can't be handed a fixed slab.
  ///
  /// [Expanded] + [Center] is what centres it; the inner [SizedBox] is what
  /// keeps it the photo's size. The height is capped at what is actually
  /// available so a tall portrait fills the screen instead of overflowing,
  /// without this having to know what the top bar and filmstrip cost.
  Widget _buildMedia(int total) {
    final photo = widget.photos[_index];

    return Expanded(
      child: Center(
        child: ResolvedAspect(
          imageUrl: photo.url,
          knownAspect: photo.aspectRatio,
          builder: (context, aspect) => LayoutBuilder(
            builder: (context, constraints) {
              final natural = constraints.maxWidth / aspect;
              return AnimatedSize(
                // Pages differ in shape, and onPageChanged fires as the swipe
                // crosses the midpoint — without this the media would jump
                // under the user's thumb.
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: SizedBox(
                  // Width is pinned as well as height: [Center] passes loose
                  // constraints, which would leave the pager unbounded.
                  width: constraints.maxWidth,
                  height: math.min(natural, constraints.maxHeight),
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: total,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => FoundPhotoStage(
                      key: ValueKey('stage_${widget.photos[i].id}'),
                      photo: widget.photos[i],
                      isActive: i == _index,
                      onViewAlbum: widget.onViewAlbum,
                      showSocialActions: widget.showSocialActions,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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
            child: AppBackButton(onPressed: () => Navigator.of(context).pop()),
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


