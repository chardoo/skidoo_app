import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Feed top bar — collapsed: plain-text Found/For You/Following tabs (active
/// tab bold + underlined), centred as a group, with the QR glyph on the far
/// left and a search icon on the far right; no persistent search field or
/// avatar. Tapping the search icon swaps the whole row for a full-width
/// search input with a scan icon and a close button, matching the design
/// screenshot this was built from (no separate search-bar row above it, and
/// no scan entry point until search is open).
class FeedTopBar extends StatefulWidget {
  const FeedTopBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.isSearchOpen,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
    this.tabs = const ['Found', 'For You', 'Following'],
    this.overSolidBackground = false,
    this.onQrScan,
    this.onUnlockPressed,
    this.initialQuery,
  });

  /// Tab labels, in index order. Guests get `['Found', 'Explore']` per the
  /// guest designs — two tabs, and "Explore" standing in for the signed-in
  /// For You/Following split, which means nothing without an account to
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
  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;

  /// Only reachable once search is open — sits next to the search field.
  final VoidCallback? onQrScan;

  /// Opens the "unlock private photos" sheet (type a code or scan a QR).
  /// Shown as the QR glyph on the far left of the collapsed bar — the design's
  /// leading action — and hidden entirely when null.
  final VoidCallback? onUnlockPressed;

  /// Pre-fills the search field when the bar switches into its open state, so
  /// a code coming back from the unlock sheet lands in the box the user would
  /// have typed it into. Ignored while search is already open.
  final String? initialQuery;

  @override
  State<FeedTopBar> createState() => _FeedTopBarState();
}

class _FeedTopBarState extends State<FeedTopBar> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(FeedTopBar old) {
    super.didUpdateWidget(old);
    if (widget.isSearchOpen && !old.isSearchOpen) {
      final seed = widget.initialQuery ?? '';
      _textCtrl.value = TextEditingValue(
        text: seed,
        selection: TextSelection.collapsed(offset: seed.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.isSearchOpen && old.isSearchOpen) {
      _textCtrl.clear();
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Icon colour for the create/search buttons — same reasoning as the tab
  /// labels: white over media, the theme's icon colour on the solid page.
  Color _chromeColor(AppThemeExtension ext) =>
      widget.overSolidBackground ? ext.greetingColor : Colors.white;

  List<Shadow>? get _chromeShadows =>
      widget.overSolidBackground ? null : _FeedTextTab._shadows;

  void _closeSearch() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    widget.onSearchClose();
  }

  void _clearText() {
    _textCtrl.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: SizedBox(
        height: 32.h,
        child: widget.isSearchOpen
            ? Row(
                children: [
                  // Leading back arrow — the primary, unambiguous way out of
                  // search (the old trailing "X" read as "clear", not "back",
                  // and was easy to miss next to the scan icon).
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      onTap: _closeSearch,
                      child: Padding(
                        padding: EdgeInsets.only(right: AppSpacing.sm.w),
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 24.sp),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textCtrl,
                      builder: (context, value, _) => TextField(
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search',
                          hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: ext.accentGold, size: 20.sp),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : Semantics(
                                  button: true,
                                  label: 'Clear search',
                                  child: GestureDetector(
                                    onTap: _clearText,
                                    child: Icon(Icons.close_rounded,
                                        color: ext.searchHintColor, size: 18.sp),
                                  ),
                                ),
                          border: InputBorder.none,
                        ),
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                  ),
                  if (widget.onQrScan != null) ...[
                    SizedBox(width: AppSpacing.sm.w),
                    Semantics(
                      button: true,
                      label: 'Scan QR code',
                      child: GestureDetector(
                        onTap: widget.onQrScan,
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: ext.searchHintColor, size: 20.sp),
                      ),
                    ),
                  ],
                ],
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++) ...[
                        if (i > 0) SizedBox(width: 18.w),
                        _FeedTextTab(
                          label: widget.tabs[i],
                          active: widget.selectedTab == i,
                          ext: ext,
                          onSolid: widget.overSolidBackground,
                          onTap: () => widget.onTabChanged(i),
                        ),
                      ],
                    ],
                  ),
                  if (widget.onUnlockPressed != null)
                    Positioned(
                      left: 0,
                      child: Semantics(
                        button: true,
                        label: 'Unlock private photos',
                        child: GestureDetector(
                          onTap: widget.onUnlockPressed,
                          behavior: HitTestBehavior.opaque,
                          child: _QrGlyph(
                            color: _chromeColor(ext),
                            size: 24.sp,
                            shadow: !widget.overSolidBackground,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Open search',
                      child: GestureDetector(
                        onTap: widget.onSearchOpen,
                        child: Icon(Icons.search_rounded,
                            color: _chromeColor(ext),
                            size: 24.sp,
                            shadows: _chromeShadows),
                      ),
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
    this.onSolid = false,
  });

  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  /// See [FeedTopBar.overSolidBackground].
  final bool onSolid;

  static const _shadows = [
    Shadow(blurRadius: 10, color: Colors.black87),
  ];

  Color get _foreground => onSolid
      ? (active ? ext.greetingColor : ext.searchHintColor)
      : (active ? Colors.white : Colors.white60);

  /// The underline always matches the active label, so it disappears with it
  /// rather than leaving a white bar under dark text.
  Color get _underline => onSolid ? ext.greetingColor : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _foreground,
                fontSize: 15.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                // The shadow only earns its keep over a photo; on the solid
                // background it just smudges the text.
                shadows: onSolid ? null : _shadows,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 16.w : 0,
              height: 2,
              decoration: BoxDecoration(
                color: _underline,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
