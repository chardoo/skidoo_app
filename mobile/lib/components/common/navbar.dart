import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/navigation/chrome_visibility.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// How far the pill floats above the bottom of the screen.
///
/// It used to be the whole system inset, and on a phone with a home indicator
/// that is about 34 dp — so the bar sat a visible band above the bottom edge
/// and read as hovering rather than as the bottom of the app. Instagram's is
/// lower, and it is lower because a home indicator is a *hint*, not a control:
/// nothing is hit-tested there, so a floating bar may sit close to it.
///
/// A tall inset is a different thing and is honoured in full. On a phone with
/// three-button navigation the inset is the button bar itself — 48 dp of real
/// controls — and giving any of it back would put the tabs on top of Back and
/// Home. The two cases are told apart by size, which is the only signal there
/// is: [_kSlimInset] is above any home indicator and below any button bar.
const double _kSlimInset = 40;

/// What a slim indicator gives back, and the floor it may not go under.
///
/// 14 brings the bar down by about the width of the gap that was reading as
/// hover, and 6 keeps a little air under it on a device that reports no inset
/// at all — flush against the edge looks like a rendering fault rather than a
/// decision.
const double _kIndicatorGiveBack = 14;
const double _kMinBottomGap = 6;

/// The pill's own height. Named so [AppNavbar.bandHeight] can add it up
/// without the feed having to guess at it.
const double _kPillHeight = 58;

double _bottomGap(BuildContext context) {
  // viewPadding, not padding: `padding` goes to zero while the keyboard is up,
  // and the bar would drop those 34 dp the moment somebody opened a keyboard
  // on a screen that keeps it.
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  if (inset > _kSlimInset) return inset;
  return math.max(inset - _kIndicatorGiveBack, _kMinBottomGap);
}

/// The most space there is between two tabs.
///
/// It used to be whatever was left over after four tabs were spread across the
/// pill — about 28 dp on a 390 dp phone — which, on top of the 10 dp of padding
/// each tab already carries, put roughly 48 dp between one glyph and the next
/// and made the row read as four icons pushed into the corners. 16 brings that
/// to 36 without closing it up entirely.
///
/// A ceiling rather than a fixed width: see [_TabGap].
const double _kTabGap = AppSpacing.lg;

/// The space between two tabs — [_kTabGap] wide, or as much of it as is left.
///
/// Wrapped in a [Flexible] at each call site, so the gaps are the part of the
/// row that gives when there isn't room for all four tabs at full width: a
/// fixed [SizedBox] overflows instead, which is what a long label, a large
/// text scale or a narrow screen would each eventually cause.
class _TabGap extends StatelessWidget {
  const _TabGap();

  @override
  Widget build(BuildContext context) => SizedBox(width: _kTabGap.w);
}

/// Bottom nav: Home / notifications / chat / profile — floating rounded
/// pill, only the active tab shows an icon+label (on a filled accent pill);
/// inactive tabs are bare icons. No centre create button (ad/request
/// creation and the Creators tab moved into [AccountPage]'s `_AdsCard`
/// section since they have no other reachable entry point once removed from
/// here).
///
/// Every glyph here is a Material icon, resting shapes all from the `_outlined`
/// family and selected shapes all from the filled `_rounded` one. The rule is
/// worth stating because it is what keeps the row even: a family is drawn to
/// one grid at one outline weight, so four icons from it asked for the same
/// [_NavTab._iconSize] come out the same size and the same weight without
/// anything having to be tuned per tab. The app leans `_rounded` elsewhere, and
/// this row cannot — `home` has no rounded outline, so `_outlined` is the only
/// family that covers all four resting shapes. Picking a glyph from outside it,
/// or from outside Material altogether, is what puts one tab out of step.
class AppNavbar extends StatelessWidget {
  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onchange,
    this.messageUnreadCount = 0,
  });

  /// Index into `HomePage`'s `IndexedStack`: 0 = Home, 1 = Chat,
  /// 2 = Notifications, 3 = Profile (Account).
  final int selectedIndex;
  final ValueChanged<int> onchange;
  final int messageUnreadCount;

  /// The strip along the bottom of the screen this bar occupies: the pill
  /// itself, plus the gap it floats on.
  ///
  /// Anything laying itself out above the bar asks here rather than keeping a
  /// figure of its own. The feed kept 96 — a fair guess when the gap was the
  /// full home-indicator inset, and wrong the moment the bar moved down, which
  /// left the caption sitting a visible band above a bar that had come to meet
  /// it. One number, read from the thing it describes.
  static double bandHeight(BuildContext context) =>
      _bottomGap(context) + _kPillHeight.h;

  /// Index of the feed tab.
  ///
  /// The feed wraps itself in [DarkMediaSurface], which forces the dark palette
  /// whatever theme the app is in — so the ground under this bar is dark there
  /// regardless. See [_onDarkGround].
  static const _feedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Which treatment to wear, decided by what is actually behind the bar
    // rather than by the app's theme.
    //
    // The bar lives in the Scaffold's bottomNavigationBar, outside the body —
    // so it never entered the feed's DarkMediaSurface and read the app theme
    // instead. With extendBody:true the feed runs right under it, which in
    // light mode put a white pill with grey icons on top of full-bleed dark
    // media. The feed is a dark island by design; the bar has to join it.
    final onDark = selectedIndex == _feedTabIndex ||
        Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      // The bottom gap is worked out rather than taken, which is why this side
      // is off and the figure arrives through `minimum` — see [_bottomGap].
      bottom: false,
      minimum: EdgeInsets.only(bottom: _bottomGap(context)),
      // Reading further narrows the bar to bare icons; coming back up opens
      // it. One notifier for this and the top tabs, so the two halves of the
      // chrome can never disagree about which way the thumb went — see
      // [ChromeVisibility].
      child: ValueListenableBuilder<bool>(
        valueListenable: ChromeVisibility.expanded,
        builder: (context, expanded, _) => Padding(
          // Centred rather than stretched, so the collapsed bar shrinks toward
          // the middle instead of leaving a stub against one edge.
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl.w),
          // Align with heightFactor, not Center: Center expands to fill its
          // constraints, and in the bottomNavigationBar slot those are loose —
          // so the bar grew to fill the screen, floated in the middle of
          // itself, and made the Scaffold reserve that whole height as bottom
          // inset. heightFactor: 1 sizes to the child instead.
          //
          // widthFactor does the same job across: without it the pill stretched
          // to the padding on both sides and the four tabs were spread over
          // whatever was left, so the gaps between them were a function of the
          // screen — wide, and wider on a bigger phone. Sizing to the content
          // lets [_kTabGap] be the gap, the same on every device.
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            widthFactor: 1,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: GlassSurface(
                borderRadius: BorderRadius.circular(29.r),
                // The ground decides, not the theme: the feed is a dark island
                // whatever the app is set to, and the bar has to join it.
                onDark: onDark,
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: SizedBox(
                  height: _kPillHeight.h,
                  // Tabs size to their own content (not 4 equal Expanded slots) so
                  // the active tab's icon+label pill gets exactly the room it
                  // needs — equal-width slots left too little space for even the
                  // shortest label ("Home") on real phone widths.
                  //
                  // min + [_TabGap], not spaceBetween: the row no longer has a
                  // width to spread across, so the bar is only as wide as the
                  // four tabs and the three gaps between them.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NavTab(
                        label: 'Home',
                        // Material, like its three neighbours, and paired with
                        // a filled variant like them too. This was the one tab
                        // drawing a bitmap: a 50 px PNG whose artwork ran to
                        // the edge of its own box, so at the shared 20 dp it
                        // came out a mark about 19 dp across with a ~1.9 dp
                        // stroke, against the Material glyphs' 16.7 dp mark and
                        // 1.7 dp stroke. Same number in the code, a visibly
                        // bigger and heavier icon on the screen — and, having
                        // no selected form, the only tab that stayed an outline
                        // when you were on it.
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        asset: AppIcons.home,
                        selected: selectedIndex == _feedTabIndex,
                        ext: ext,
                        onDark: onDark,
                        expanded: expanded,
                        onTap: () => onchange(0),
                      ),
                      const Flexible(child: _TabGap()),
                      _NavTab(
                        // 'Alerts', not 'Notifications' — the word is what the design
                        // calls that screen, and the long one overflowed the pill by
                        // ~97px when its tab was active, since only the active tab
                        // shows a label and the row is sized to its content.
                        label: 'Alerts',
                        icon: Icons.notifications_none_outlined,
                        selectedIcon: Icons.notifications_rounded,
                        asset: AppIcons.bell,
                        selected: selectedIndex == 2,
                        ext: ext,
                        onDark: onDark,
                        expanded: expanded,
                        onTap: () => onchange(2),
                      ),
                      const Flexible(child: _TabGap()),
                      _NavTab(
                        // 'Chats', matching the screen's own title.
                        label: 'Chats',
                        // Two overlapping bubbles, per the design — a conversation
                        // rather than a single message. The lone bubble this used to
                        // carry is the app's "comment" glyph, and the two surfaces were
                        // indistinguishable at 20 dp.
                        icon: Icons.forum_outlined,
                        selectedIcon: Icons.forum_rounded,
                        asset: AppIcons.conversation,
                        selected: selectedIndex == 1,
                        ext: ext,
                        onDark: onDark,
                        expanded: expanded,
                        unreadCount: messageUnreadCount,
                        onTap: () => onchange(1),
                      ),
                      const Flexible(child: _TabGap()),
                      _NavTab(
                        label: 'Profile',
                        icon: Icons.person_outline_outlined,
                        selectedIcon: Icons.person_rounded,
                        asset: AppIcons.user,
                        selected: selectedIndex == 3,
                        ext: ext,
                        onDark: onDark,
                        expanded: expanded,
                        onTap: () => onchange(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Single nav tab ────────────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.selected,
    required this.ext,
    required this.icon,
    required this.selectedIcon,
    this.asset,
    required this.onDark,
    required this.expanded,
    required this.onTap,
    this.unreadCount = 0,
  });

  /// Size of every glyph in the bar, and the only place it is decided.
  ///
  /// It reads as one number because every tab now draws a Material icon, which
  /// all share the family's 24 dp grid and 2 dp outline weight — ask the four
  /// of them for 20 and you get four marks of the same size and the same
  /// weight. That only holds while they stay in the family: an asset dropped in
  /// beside them answers this number with whatever its artwork happens to fill,
  /// which is exactly how the Home tab came to be the odd one out.
  static const double _iconSize = 20;

  final String label;
  final bool selected;
  final AppThemeExtension ext;

  /// Whether the bar is sitting on a dark ground — see [AppNavbar].
  final bool onDark;

  /// Whether the bar is at full size. Collapsed, the active tab drops its
  /// label and its chip and becomes a bare icon like the rest — the accent
  /// still marks it, so which tab you are on survives the collapse.
  final bool expanded;
  final VoidCallback onTap;

  /// The tab's resting glyph, and the filled form it takes when you are on it.
  /// Both required: a tab with no selected form is a tab that stays an outline
  /// while the other three fill.
  final IconData icon;
  final IconData selectedIcon;

  /// The supplied artwork for this tab, drawn instead of either font glyph.
  ///
  /// One drawing for both states, because the set has no filled counterparts —
  /// so the bar stops saying "you are here" by filling the glyph and says it
  /// the three other ways it already does: the accent colour, the chip behind
  /// it, and the label. All four tabs give the fill up together, which is the
  /// part that matters. One tab keeping an outline while the others filled is
  /// the bug this file already warns about.
  ///
  /// The artwork is on the same 24 dp grid and the same 2 dp stroke as the
  /// family it replaces, so [_iconSize] still means what it says.
  final String? asset;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    // The active tab is a quiet chip with the accent *inside* it — green icon,
    // green label — on both grounds. Only the chip's own fill differs, because
    // "one step up from the bar" is a different colour on each: a lift of white
    // over the black pill, a tint of the accent on the light one.
    //
    // It used to be a solid accent chip with the label knocked out in black on
    // dark, which made the whole bar's weight land on one tab and read as a
    // button sitting on the nav rather than as the tab you are on. The design
    // has the fill recede and the accent do the talking.
    //
    // Keyed to the ground the bar is on, not the app theme, so the two halves
    // of the treatment can never disagree — a white chip on the black pill, or
    // grey icons over the feed's dark media.
    final activeColor = onDark
        ? Colors.white.withValues(alpha: 0.12)
        : ext.accentGold.withValues(alpha: 0.14);
    final activeForeground = ext.accentGold;
    final iconColor = selected
        ? activeForeground
        : (onDark ? Colors.white70 : ext.searchHintColor);

    Widget iconWidget = asset != null
        ? AppSvgIcon(asset!, size: _iconSize.sp, color: iconColor)
        : Icon(
            selected ? selectedIcon : icon,
            size: _iconSize.sp,
            color: iconColor,
          );

    if (unreadCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: EdgeInsets.all(2.5.r),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(minWidth: 15.w, minHeight: 15.w),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        // Guarantees a real tap target on the icon-only (unselected) tabs,
        // which would otherwise be as narrow as the icon itself now that
        // tabs size to their own content instead of an equal Expanded slot.
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: selected && expanded ? 16.w : 10.w,
                vertical: 10.h,
              ),
              decoration: BoxDecoration(
                color: selected && expanded ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xl.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  iconWidget,
                  // Label — only the active tab shows one, no reserved
                  // space on inactive tabs (matches the floating-pill
                  // design). maxLines/overflow stay as a safety net, but
                  // tabs are no longer squeezed into an equal-width slot
                  // so this shouldn't actually trigger in normal use.
                  if (selected && expanded) ...[
                    SizedBox(width: 6.w),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeForeground,
                        fontSize: 12.sp,
                        // Medium, not bold: the chip and the accent already
                        // mark the tab, and the design's label sits alongside
                        // its icon rather than shouting over it.
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
