import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  /// The glyph. Outline or filled is the caller's business; size and colour
  /// are not.
  final IconData icon;

  /// The title line — "No messages yet", "Nothing liked yet".
  final String message;

  /// The line under it. Reads as a sentence continuing [actionLabel] when one
  /// is given, and stands on its own when not.
  final String? hint;

  /// The tappable opening words of the second line, if there is a way out.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The disc, and the glyph inside it. Fixed: see the note above.
  static const double _discSize = 100;
  static const double _iconSize = 42;

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

        final content = Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tight)
                  Icon(icon, color: ext.accentGold, size: _iconSize.sp)
                else
                  Container(
                    width: _discSize.w,
                    height: _discSize.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ext.accentGold.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: ext.accentGold, size: _iconSize.sp),
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
  });

  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final AppThemeExtension ext;

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
                  color: ext.accentGold,
                  decoration: TextDecoration.underline,
                  decorationColor: ext.accentGold,
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
