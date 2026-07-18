import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/constants/icons.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

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

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Container(
          height: 58.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(29.r),
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
                selected: selectedIndex == 0,
                ext: ext,
                onTap: () => onchange(0),
              ),
              _NavTab(
                label: 'Notifications',
                icon: Icons.notifications_none_rounded,
                selectedIcon: Icons.notifications_rounded,
                selected: selectedIndex == 2,
                ext: ext,
                onTap: () => onchange(2),
              ),
              _NavTab(
                label: 'Messages',
                icon: Icons.chat_bubble_outline_rounded,
                selectedIcon: Icons.chat_bubble_rounded,
                selected: selectedIndex == 1,
                ext: ext,
                unreadCount: messageUnreadCount,
                onTap: () => onchange(1),
              ),
              _NavTab(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: selectedIndex == 3,
                ext: ext,
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
    required this.onTap,
    this.iconPath,
    this.icon,
    this.selectedIcon,
    this.unreadCount = 0,
  }) : assert(iconPath != null || icon != null);

  final String label;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final String? iconPath;
  final IconData? icon;
  final IconData? selectedIcon;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final activeColor = ext.accentGold;
    final iconColor = selected ? Colors.black : Colors.white70;

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
                borderRadius: BorderRadius.circular(20.r),
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
                        color: Colors.black,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w700,
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
