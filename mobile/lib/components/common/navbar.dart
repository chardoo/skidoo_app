import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/constants/icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// Bottom nav: Home / notifications / chat / profile — floating rounded
/// pill, only the active tab shows an icon+label (on a filled accent pill);
/// inactive tabs are bare icons. No centre create button (ad/request
/// creation and the Creators tab moved into [AccountPage]'s `_AdsCard`
/// section since they have no other reachable entry point once removed from
/// here).
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
      minimum: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl.w),
        child: Container(
          height: 58.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            // The pill floats over arbitrary content, so it has to read as a
            // surface in front of the page rather than a hole in it. Dark mode
            // gets that from being blacker than everything behind it; light
            // mode can't, so it takes the palette's white and earns its edge
            // from a shadow instead — white on the light background is only a
            // few percent apart.
            color: onDark ? Colors.black : ext.cardSurface,
            borderRadius: BorderRadius.circular(29.r),
            boxShadow: onDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          // Tabs size to their own content (not 4 equal Expanded slots) so
          // the active tab's icon+label pill gets exactly the room it
          // needs — equal-width slots left too little space for even the
          // shortest label ("Home") on real phone widths.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavTab(
                label: 'Home',
                iconPath: IconsPath.home,
                selected: selectedIndex == _feedTabIndex,
                ext: ext,
                onDark: onDark,
                onTap: () => onchange(0),
              ),
              _NavTab(
                // 'Alerts', not 'Notifications' — the word is what the design
                // calls that screen, and the long one overflowed the pill by
                // ~97px when its tab was active, since only the active tab
                // shows a label and the row is sized to its content.
                label: 'Alerts',
                icon: Icons.notifications_none_rounded,
                selectedIcon: Icons.notifications_rounded,
                selected: selectedIndex == 2,
                ext: ext,
                onDark: onDark,
                onTap: () => onchange(2),
              ),
              _NavTab(
                // 'Chats', matching the screen's own title.
                label: 'Chats',
                // Two overlapping bubbles, per the design — a conversation
                // rather than a single message. The lone bubble this used to
                // carry is the app's "comment" glyph, and the two surfaces were
                // indistinguishable at 20 dp.
                icon: Icons.forum_outlined,
                selectedIcon: Icons.forum_rounded,
                selected: selectedIndex == 1,
                ext: ext,
                onDark: onDark,
                unreadCount: messageUnreadCount,
                onTap: () => onchange(1),
              ),
              _NavTab(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: selectedIndex == 3,
                ext: ext,
                onDark: onDark,
                onTap: () => onchange(3),
              ),
            ],
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
    required this.onDark,
    required this.onTap,
    this.iconPath,
    this.icon,
    this.selectedIcon,
    this.unreadCount = 0,
  }) : assert(iconPath != null || icon != null);

  final String label;
  final bool selected;
  final AppThemeExtension ext;

  /// Whether the bar is sitting on a dark ground — see [AppNavbar].
  final bool onDark;
  final VoidCallback onTap;
  final String? iconPath;
  final IconData? icon;
  final IconData? selectedIcon;
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

    Widget iconWidget = icon != null
        ? Icon(
            selected && selectedIcon != null ? selectedIcon! : icon!,
            size: 20.sp,
            color: iconColor,
          )
        : ExcludeSemantics(child: Image.asset(
            iconPath!,
            width: 20.sp,
            height: 20.sp,
            color: iconColor,
          ));

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
                horizontal: selected ? 16.w : 10.w,
                vertical: 10.h,
              ),
              decoration: BoxDecoration(
                color: selected ? activeColor : Colors.transparent,
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
                  if (selected) ...[
                    SizedBox(width: 6.w),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activeForeground,
                        fontSize: 12.5.sp,
                        // Semibold, not bold: the chip and the accent already
                        // mark the tab, and the design's label sits alongside
                        // its icon rather than shouting over it.
                        fontWeight: FontWeight.w600,
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
