import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Horizontal thumbnail rail under the Found viewer. The active thumbnail is
/// outlined and kept centred as the user pages through the album, so the
/// strip always shows where they are.
class FoundPhotoFilmstrip extends StatefulWidget {
  const FoundPhotoFilmstrip({
    super.key,
    required this.photos,
    required this.activeIndex,
    required this.onTap,
  });

  final List<Photo> photos;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  State<FoundPhotoFilmstrip> createState() => _FoundPhotoFilmstripState();
}

class _FoundPhotoFilmstripState extends State<FoundPhotoFilmstrip> {
  final _scrollCtrl = ScrollController();

  /// Thumb width + trailing gap — also the scroll extent of one item, which
  /// is what centring maths needs.
  double get _itemExtent => 64.w + AppSpacing.sm.w;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _centreOnActive(animate: false));
  }

  @override
  void didUpdateWidget(FoundPhotoFilmstrip old) {
    super.didUpdateWidget(old);
    if (old.activeIndex != widget.activeIndex) _centreOnActive();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _centreOnActive({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    final viewport = _scrollCtrl.position.viewportDimension;
    final target = (widget.activeIndex * _itemExtent) -
        (viewport / 2) +
        (_itemExtent / 2);
    final clamped =
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    if (!animate) {
      _scrollCtrl.jumpTo(clamped);
      return;
    }
    _scrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  /// The filmstrip lives inside the always-dark viewer, so it takes the dark
  /// palette directly rather than the ambient one — reading the ambient theme
  /// put white (#FFFFFF `cardSurface`) placeholder tiles on the dark strip
  /// whenever the app was in light mode.
  static const _palette = AppThemeExtension.dark;

  @override
  Widget build(BuildContext context) {
    const ext = _palette;

    return SizedBox(
      height: 64.w,
      child: ListView.separated(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        itemCount: widget.photos.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm.w),
        itemBuilder: (_, index) {
          final active = index == widget.activeIndex;
          return Semantics(
            button: true,
            selected: active,
            label: 'Photo ${index + 1}',
            child: GestureDetector(
              onTap: () => widget.onTap(index),
              child: Container(
                width: 64.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  // Accent green, per the Found/PhotoSelected designs — not
                  // white. `accentGold` is #1D9E75 in both light and dark, so
                  // the ring reads the same either way; the viewer itself is
                  // deliberately always-dark, like every full-screen media
                  // viewer in the app.
                  border: Border.all(
                    color: active ? ext.accentGold : Colors.transparent,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SkidooImage(
                  imageUrl: widget.photos[index].url,
                  fit: BoxFit.cover,
                  logicalWidth: 64,
                  placeholder: (_, __) => const SkidooImagePlaceholder(alwaysDark: true),
                  errorWidget: (_, __, ___) =>
                      const SkidooImagePlaceholder(alwaysDark: true),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
