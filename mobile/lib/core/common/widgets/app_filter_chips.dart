import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The app's filter chip, and the row it lives in.
///
/// ## The shape, and why this file exists
///
/// A pill. Selected is a **solid accent fill with a white label**; resting is
/// **no fill and a hairline border**. That is not a new decision — it is what
/// the notifications filters, the Found filter sheet and the request board
/// already draw, and the notifications file says so in as many words. What was
/// new was every screen writing it out again: five copies had drifted to four
/// different heights (40, 44, 46, 52), three radii and three different ways of
/// showing "selected", the weakest of which was a 14%-opacity wash that on the
/// near-black settings ground reads as *disabled* rather than chosen.
///
/// So the chip is here, once. A screen picks a [AppFilterRowStyle] and gets the
/// rest.
enum AppFilterRowStyle {
  /// The primary axis — what the list is *of*. Solid fill when selected.
  primary,

  /// A qualifier on the row above it: a status inside a kind, a sort inside a
  /// search. Shorter, lighter, and selected with a tint rather than a fill, so
  /// two rows stacked read as a heading and its refinement instead of as eight
  /// buttons of equal weight.
  secondary,
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.style = AppFilterRowStyle.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppFilterRowStyle style;

  /// The height of a row of these. Exposed so [AppFilterRow] can size itself,
  /// and so a caller laying chips out by hand gets the same number.
  static double heightFor(AppFilterRowStyle style) =>
      style == AppFilterRowStyle.primary ? 40 : 32;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final primary = style == AppFilterRowStyle.primary;

    // `accentGold` is the brand green in both themes — the theme's own
    // `primary` is literally white in dark mode, which is what once turned a
    // selected chip into a white pill with grey text.
    final accent = ext.accentGold;

    final Color background;
    final Color border;
    final Color foreground;
    if (selected) {
      background = primary ? accent : accent.withValues(alpha: 0.16);
      border = primary ? accent : Colors.transparent;
      foreground = primary ? Colors.white : accent;
    } else {
      background = Colors.transparent;
      // The resting chip is an outline on the primary row and nothing at all on
      // the secondary one. Two rows of outlines is a grid of boxes; one row of
      // them reads as a set of choices.
      border = primary
          ? ext.searchHintColor.withValues(alpha: 0.35)
          : Colors.transparent;
      foreground = primary ? ext.greetingColor : ext.searchHintColor;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: (primary ? AppSpacing.lg : AppSpacing.md).w,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: (primary ? 14 : 13).sp,
              // Weight carries the selection as well as colour, so the state
              // survives for anyone who cannot separate the green from the
              // grey.
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [AppFilterChip]s.
///
/// Fades at whichever edge has more chips beyond it. A row that simply stops
/// mid-chip at the screen edge — which is what the payments filters did — reads
/// as a layout fault rather than as something you can push along.
class AppFilterRow extends StatefulWidget {
  const AppFilterRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.style = AppFilterRowStyle.primary,
  });

  final List<String> labels;

  /// Index into [labels]. Out-of-range selects nothing, which is what a screen
  /// wants while its filter is being taken away by a refresh.
  final int selected;

  final ValueChanged<int> onSelect;
  final AppFilterRowStyle style;

  @override
  State<AppFilterRow> createState() => _AppFilterRowState();
}

class _AppFilterRowState extends State<AppFilterRow> {
  final ScrollController _controller = ScrollController();

  /// How wide the fade at each end is when it is showing.
  static const double _fade = 28;

  bool _atStart = true;
  bool _atEnd = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncEdges);
    // The first frame is the one that knows whether the row overflows at all.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncEdges());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncEdges);
    _controller.dispose();
    super.dispose();
  }

  void _syncEdges() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final atStart = position.pixels <= position.minScrollExtent + 1;
    final atEnd = position.pixels >= position.maxScrollExtent - 1;
    if (atStart == _atStart && atEnd == _atEnd) return;
    setState(() {
      _atStart = atStart;
      _atEnd = atEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = AppFilterChip.heightFor(widget.style).h;

    final row = SizedBox(
      height: height,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        itemCount: widget.labels.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm.w),
        itemBuilder: (_, i) => AppFilterChip(
          label: widget.labels[i],
          selected: i == widget.selected,
          style: widget.style,
          onTap: () => widget.onSelect(i),
        ),
      ),
    );

    if (_atStart && _atEnd) return row;

    return ShaderMask(
      shaderCallback: (bounds) {
        // Stops as fractions of the row's width, so the fade is the same
        // physical width whatever the screen is.
        final fade = (_fade.w / bounds.width).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            if (!_atStart) Colors.transparent,
            Colors.white,
            Colors.white,
            if (!_atEnd) Colors.transparent,
          ],
          stops: [
            if (!_atStart) 0.0,
            if (!_atStart) fade else 0.0,
            if (!_atEnd) 1 - fade else 1.0,
            if (!_atEnd) 1.0,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: row,
    );
  }
}
