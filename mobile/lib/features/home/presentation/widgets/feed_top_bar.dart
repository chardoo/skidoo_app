import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/features/home/presentation/widgets/creator_mode_menu.dart';

/// Feed top bar — plain-text Found/Feed/Following tabs (active tab bold +
/// underlined) centred as a group, with the QR glyph on the far left and a
/// search icon on the far right.
///
/// The search icon opens the Search screen as its own route rather than
/// swapping this row for a field: search is a screen with recents, chips and a
/// suggestion grid of its own, none of which fits in a 32 dp strip.
class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onSearchOpen,
    this.tabs = const ['Found', 'Feed', 'Following'],
    this.overSolidBackground = false,
    this.onUnlockPressed,
    this.unlockActive = false,
  });

  /// Tab labels, in index order. Guests get `['Found', 'Explore']` per the
  /// guest designs — two tabs, and "Explore" standing in for the signed-in
  /// Feed/Following split, which means nothing without an account to
  /// follow from.
  final List<String> tabs;

  /// True when the bar sits on the page's own background rather than over
  /// full-bleed media.
  ///
  /// The two cases need opposite colours and the bar can't tell them apart on
  /// its own. Over media the labels are white with a drop shadow, which is the
  /// only thing that stays legible across an arbitrary photo. On the solid
  /// background that same white is invisible in light mode, so the labels take
  /// the theme's own text colours and drop the shadow.
  final bool overSolidBackground;

  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  /// Opens the Search screen.
  final VoidCallback onSearchOpen;

  /// Opens the "unlock private photos" sheet (type a code or scan a QR).
  /// Shown as the QR glyph on the far left — the design's leading action —
  /// and hidden entirely when null.
  final VoidCallback? onUnlockPressed;

  /// True while that sheet is open.
  ///
  /// The glyph takes the accent for as long as it is, so the sheet is visibly
  /// anchored to the control that opened it rather than appearing from nowhere
  /// — and so a sheet dismissed by tapping away leaves no doubt about which
  /// button was pressed.
  final bool unlockActive;

  /// Icon colour for the leading/trailing buttons — same reasoning as the tab
  /// labels: white over media, the theme's text colour on the solid page.
  Color _chromeColor(AppThemeExtension ext) =>
      overSolidBackground ? ext.greetingColor : Colors.white;

  Color _qrColor(AppThemeExtension ext) =>
      unlockActive ? ext.accentGold : _chromeColor(ext);

  List<Shadow>? get _chromeShadows =>
      overSolidBackground ? null : _FeedTextTab._shadows;

  /// The bar's full height, and every control's tap height inside it.
  ///
  /// This used to be a 32 dp strip inside 8 dp of vertical padding. Same 48 dp
  /// overall, but the padding belonged to the *parent*, so the tallest thing a
  /// tab could be was 27 dp — under the 48 dp minimum, and with its top edge
  /// flush against the top of the glyphs. A tap aimed at a label that landed a
  /// couple of pixels high fell outside the box entirely and did nothing, while
  /// the same tap slightly low landed in the underline's share of the box and
  /// worked. Owning the whole 48 dp is what lets the controls fill it.
  static const double _barHeight = 48;

  /// Half the 18 dp gap between labels, applied to each tab instead of being a
  /// bare spacer between them, so neighbouring tap boxes meet rather than
  /// leaving the gap dead. The gap the eye sees is unchanged.
  static const double _tabGap = 9;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        height: _barHeight.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The labels are the one part of this bar whose width isn't ours to
            // choose — a long tab set, a translation, or a large system text
            // scale can all outgrow the strip between the two icons. Scaling the
            // group down as a unit keeps it centred and legible; letting it
            // overflow would just clip the last label.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _FeedTextTab(
                      label: tabs[i],
                      active: selectedTab == i,
                      ext: ext,
                      onSolid: overSolidBackground,
                      height: _barHeight.h,
                      horizontalPadding: _tabGap.w,
                      onTap: () => onTabChanged(i),
                    ),
                ],
              ),
            ),
            if (onUnlockPressed != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: 'Unlock private photos',
                  child: GestureDetector(
                    onTap: onUnlockPressed,
                    behavior: HitTestBehavior.opaque,
                    // Full bar height, and reaching inwards from the edge, so
                    // the target is 36 × 48 rather than the glyph's own 24 × 24.
                    // The glyph itself does not move.
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.md.w),
                      child: Center(
                        // Tweened rather than switched: the sheet takes a beat
                        // to arrive, and a glyph that snaps to the accent ahead
                        // of it reads as a glitch rather than as a response.
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: _qrColor(ext)),
                          duration: const Duration(milliseconds: 150),
                          builder: (_, color, __) => _QrGlyph(
                            color: color ?? _qrColor(ext),
                            size: 24.sp,
                            shadow: !overSolidBackground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              // Search and the mode switcher share the trailing edge, so they
              // sit in one row rather than stacking Positioned children that
              // would need their widths hardcoded to avoid overlapping.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'Open search',
                    child: GestureDetector(
                      onTap: onSearchOpen,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.only(left: AppSpacing.md.w),
                        child: Center(
                          child: Icon(Icons.search_rounded,
                              color: _chromeColor(ext),
                              size: 24.sp,
                              shadows: _chromeShadows),
                        ),
                      ),
                    ),
                  ),
                  // Draws nothing unless the signed-in account is a
                  // photographer, so the bar is unchanged for everyone else.
                  CreatorModeMenu(overSolidBackground: overSolidBackground),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The design's leading QR mark: three rounded finder squares plus a block
/// pattern in the fourth corner.
///
/// Painted rather than picked from [Icons] because none of the Material QR
/// glyphs are this sparse — `qr_code_2` reads as a dense code at this size,
/// which is a visibly different mark. The geometry below is traced off the
/// design at its natural 18 px, then scaled.
class _QrGlyph extends StatelessWidget {
  const _QrGlyph({
    required this.color,
    required this.size,
    this.shadow = false,
  });

  final Color color;
  final double size;

  /// Over media the mark needs the same drop shadow the tab labels get; on the
  /// solid background it would only smudge.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _QrGlyphPainter(color: color, shadow: shadow),
    );
  }
}

class _QrGlyphPainter extends CustomPainter {
  const _QrGlyphPainter({required this.color, required this.shadow});

  final Color color;
  final bool shadow;

  /// Everything below is expressed in the design's own 18-unit box.
  static const double _grid = 18;

  /// Top-left corners of the three finder squares (6×6 each, 2-wide stroke,
  /// so they occupy 8×8 once the stroke is counted).
  static const _finders = [Offset(1, 1), Offset(11, 1), Offset(1, 11)];

  /// The fourth corner's pattern, decomposed into solid blocks.
  static const _blocks = [
    Rect.fromLTWH(10, 10, 4, 2),
    Rect.fromLTWH(15, 10, 3, 2),
    Rect.fromLTWH(16, 12, 2, 1),
    Rect.fromLTWH(10, 13, 2, 3),
    Rect.fromLTWH(13, 13, 5, 2),
    Rect.fromLTWH(10, 16, 4, 2),
    Rect.fromLTWH(15, 16, 3, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _grid;

    void draw(Paint strokePaint, Paint fillPaint) {
      for (final o in _finders) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(o.dx * s, o.dy * s, 6 * s, 6 * s),
            Radius.circular(2 * s),
          ),
          strokePaint,
        );
      }
      for (final b in _blocks) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(b.left * s, b.top * s, b.width * s, b.height * s),
            Radius.circular(0.5 * s),
          ),
          fillPaint,
        );
      }
    }

    if (shadow) {
      final blur = MaskFilter.blur(BlurStyle.normal, 3 * s);
      draw(
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s
          ..maskFilter = blur,
        Paint()
          ..color = Colors.black87
          ..maskFilter = blur,
      );
    }

    draw(
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_QrGlyphPainter old) =>
      old.color != color || old.shadow != shadow;
}

class _FeedTextTab extends StatelessWidget {
  const _FeedTextTab({
    required this.label,
    required this.active,
    required this.ext,
    required this.onTap,
    required this.height,
    required this.horizontalPadding,
    this.onSolid = false,
  });

  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  /// Tap height — the bar's full height, not just the label's.
  final double height;

  /// Half the gap to each neighbour, so adjacent tabs' tap boxes meet.
  final double horizontalPadding;

  /// See [FeedTopBar.overSolidBackground].
  final bool onSolid;

  static const _shadows = [
    Shadow(blurRadius: 10, color: Colors.black87),
  ];

  /// Height of the underline and of the gap above it — mirrored as a spacer on
  /// the other side of the label. See [build].
  static const double _underlineHeight = 2;

  Color get _foreground => onSolid
      ? (active ? ext.greetingColor : ext.searchHintColor)
      : (active ? Colors.white : Colors.white60);

  /// The underline always matches the active label, so it disappears with it
  /// rather than leaving a white bar under dark text.
  Color get _underline => onSolid ? ext.greetingColor : Colors.white;

  TextStyle _style({required bool bold}) => TextStyle(
        color: _foreground,
        fontSize: 15.sp,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        // The shadow only earns its keep over a photo; on the solid
        // background it just smudges the text.
        shadows: onSolid ? null : _shadows,
      );

  /// Width this label takes at its *active* weight.
  ///
  /// The active label is heavier than the others, so it is also wider. The row
  /// is sized to its contents and centred, which meant selecting a different
  /// tab changed the row's width and slid every label sideways by a couple of
  /// pixels. Reserving the bold width in both states holds them still.
  ///
  /// Measured rather than reserved with a hidden second [Text]: a phantom label
  /// would be a duplicate in the semantics tree and would make `find.text` in
  /// tests match two widgets for every tab.
  ///
  /// The style has to be resolved against [DefaultTextStyle] first. A [Text]
  /// merges its style onto the ambient one, which is where the app's font comes
  /// from — [_style] never names a family. A bare [TextPainter] inherits
  /// nothing, so measuring the raw style would size the slot in the fallback
  /// font and leave every label sitting in a box of the wrong width.
  double _activeWidth(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: DefaultTextStyle.of(context).style.merge(_style(bold: true)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final belowLabel = AppSpacing.xs.h + _underlineHeight;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mirrors the gap + underline below, so what ends up centred in
                // the bar is the *label* rather than the label-and-underline
                // block. Without it the underline's 6 dp pushed every label
                // 3 dp above the leading and trailing icons, which is visible
                // as the labels sitting high against them.
                SizedBox(height: belowLabel),
                SizedBox(
                  width: _activeWidth(context),
                  child: Text(
                    label,
                    style: _style(bold: active),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 16.w : 0,
                  height: _underlineHeight,
                  decoration: BoxDecoration(
                    color: _underline,
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
