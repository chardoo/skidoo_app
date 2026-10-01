import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_typography.dart';

/// The one empty state. Every list that can be empty draws this and nothing
/// else.
///
/// There were three of them, and the differences were not decisions anybody
/// made — the inbox had a tinted circle and a Syne title, the profile tabs had
/// a bare grey glyph in body type sitting 80px from the top, and this widget
/// had a third icon size again. Three screens, three answers to "we have
/// nothing to show you", which reads as three different apps.
///
/// So the numbers below are constants rather than parameters. An icon size or
/// colour that a caller can pass is an icon size or colour that drifts, and
/// drift is the whole of what was wrong.
///
/// The anatomy, from the inbox, which is the one the design settled on:
///
///   ◯  a tinted disc with the glyph in the accent
///   Title — Syne, the same tier as a page title
///   A second line — a plain hint, or an underlined way out
///
/// The second line is one line either way. Where there is something useful to
/// do, [actionLabel] opens it and [hint] finishes the sentence around it
/// ("*Start a chat* to see your conversations here"); where there is not — a
/// tab of photos somebody bought is not somewhere you go to buy one — [hint]
/// stands alone. What does not happen is inventing an action to fill the slot.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
  }) : assert(
          (actionLabel == null) == (onAction == null),
          'an action needs both a label and something to do',
        );

  /// The glyph, as one of [AppIcons].
  ///
  /// A path into the supplied set rather than an [IconData], and the type is
  /// the point: these were nineteen Material glyphs chosen one screen at a
  /// time — `inbox_outlined` here, `rocket_launch_outlined` there — none of
  /// which are in the icon set the rest of the app draws from. An empty state
  /// is a whole screen with one mark on it, so it was the most visible place
  /// the app was still wearing somebody else's icons.
  ///
  /// Size and colour stay out of the caller's hands, as before.
  final String icon;

  /// The title line — "No messages yet", "Nothing liked yet".
  final String message;

  /// The line under it. Reads as a sentence continuing [actionLabel] when one
  /// is given, and stands on its own when not.
  final String? hint;

  /// The tappable opening words of the second line, if there is a way out.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The disc, and the glyph inside it. Fixed: see the note above.
  static const double _discSize = 80;
  static const double _iconSize = 30;

  /// The disc never takes more than this share of the height it is given.
  /// Past it, the glyph stands on its own and the gaps tighten.
  ///
  /// Not a parameter, and not a caller's decision — it is a fact about the box
  /// the widget was handed. A step inside a bottom sheet is a few hundred
  /// pixels tall, and the full treatment in it leaves no room for the words;
  /// drawing it anyway gets the yellow-and-black overflow bars, which is not a
  /// more consistent design, only a broken one.
  static const double _mostOfTheBox = 0.4;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight.isFinite &&
            _discSize.w > constraints.maxHeight * _mostOfTheBox;

        // The accent takes its darker partner shade on a light ground.
        //
        // One accent was serving two very different grounds. The disc is the
        // accent at 12% over the page: on near-black that wash stays dark and
        // the glyph reads off it at 4.9:1, but on the light ground it lands on
        // a pale mint where the *same* glyph measures 2.8:1 — under the 3:1
        // WCAG 1.4.11 asks of a graphic, and visibly so, the mark looking
        // half-erased rather than quiet. The link has it worse: body-sized
        // text needs 4.5:1 and the accent on the light page gives 3.15:1.
        //
        // The dark shade fixes both at once — 4.4:1 in the disc, 5.0:1 for the
        // link — and is already the accent's declared partner, so this is the
        // palette being used as intended rather than a new colour.
        //
        // Read off the ground rather than `Theme.of(context).brightness`,
        // because the ground is the thing the wash actually composites over —
        // a theme that sets one and not the other would still come out right.
        final accent = ext.homeBackground.computeLuminance() > 0.5
            ? ext.accentGoldDark
            : ext.accentGold;

        final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tight)
                  _Glyph(icon, color: accent, size: _iconSize.sp)
                else
                  Container(
                    width: _discSize.w,
                    height: _discSize.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ext.accentGold.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: _Glyph(icon, color: accent, size: _iconSize.sp),
                  ),
                SizedBox(height: (tight ? AppSpacing.md : AppSpacing.xl).h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTypography.title.copyWith(color: ext.greetingColor),
                ),
                if (hint != null || actionLabel != null) ...[
                  SizedBox(height: AppSpacing.sm.h),
                  _SecondLine(
                    hint: hint,
                    actionLabel: actionLabel,
                    onAction: onAction,
                    ext: ext,
                    accent: accent,
                  ),
                ],
              ],
            ),
        );

        // Centred when it fits; scrolled when even the tight form does not.
        // There is always a box small enough, and the alternative is the
        // yellow-and-black bars painted across the words — an empty state that
        // announces a layout bug instead of saying there is nothing here.
        if (!tight) return Center(child: content);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}

/// The hint, the link, or the link with the hint written around it.
class _SecondLine extends StatelessWidget {
  const _SecondLine({
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    required this.ext,
    required this.accent,
  });

  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppThemeExtension ext;

  /// The accent already resolved against this theme's ground. Passed in rather
  /// than read again so the link and the glyph cannot end up different shades.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.body.copyWith(color: ext.searchHintColor);

    if (actionLabel == null) {
      return Text(hint!, textAlign: TextAlign.center, style: body);
    }

    // Only the opening words are tappable, so the link reads as part of the
    // sentence rather than as a button parked underneath it. A WidgetSpan
    // rather than a TapGestureRecognizer because the recognizer has to be
    // disposed, and a span built in `build` has nowhere to do it.
    return Text.rich(
      TextSpan(children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            button: true,
            label: actionLabel,
            child: GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: AppTypography.body.copyWith(
                  color: accent,
                  decoration: TextDecoration.underline,
                  decorationColor: accent,
                ),
              ),
            ),
          ),
        ),
        if (hint != null) TextSpan(text: ' $hint', style: body),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// An [AppEmptyState] that can still be pulled down on.
///
/// A plain [Center] inside a [RefreshIndicator] has nothing to scroll, so the
/// pull never starts and the only way to retry is to leave the tab and come
/// back. This keeps the message centred in the space it is given and makes
/// that space draggable.
class ScrollableEmptyState extends StatelessWidget {
  const ScrollableEmptyState({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      );
}

/// One of [AppIcons], whichever format it happens to be in.
///
/// The supplied set is SVG and [AppSvgIcon] draws it. The three empty-state
/// marks — the ticked bookmark, the crossed heart, the single bubble — arrived
/// as PNGs instead, so this picks by extension rather than making every caller
/// know which kind of file it asked for.
///
/// Tinted either way, and that matters more than it looks: the empty state
/// chooses between two accent shades depending on the ground it is drawn on,
/// because the lighter one fails WCAG 1.4.11 on the light page (see the note
/// above `accent`). A raster drawn in its own baked-in green would quietly
/// opt out of that. `Image.asset`'s `color` composites in exactly like the
/// SVG's `srcIn` filter, so both honour the choice.
///
/// Local to this file on purpose. If raster icons spread beyond these three
/// this belongs next to [AppSvgIcon] instead — but one shared widget that
/// silently accepts either format is also how a set stops being a set.
class _Glyph extends StatelessWidget {
  const _Glyph(this.asset, {required this.color, required this.size});

  final String asset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (asset.endsWith('.svg')) {
      return AppSvgIcon(asset, color: color, size: size);
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      color: color,
      // The sources are 23-36px and this draws at 30 logical points, so on a
      // 2x or 3x screen they are being scaled up. Medium is the best of the
      // cheap filters for that direction; nothing here can invent detail the
      // file does not have.
      filterQuality: FilterQuality.medium,
    );
  }
}
