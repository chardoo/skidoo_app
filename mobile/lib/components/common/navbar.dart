import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/constants/icons.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class AppNavbar extends StatelessWidget {
  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onchange,
    required this.onCreateTap,
    this.messageUnreadCount = 0,
    this.showCreate = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onchange;
  final VoidCallback onCreateTap;
  final int messageUnreadCount;
  /// Hide the centre + button when no creatable features are enabled.
  final bool showCreate;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(color: ext.glassBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62.h,
          child: Row(
            children: [
              _NavTab(
                label: 'Home',
                iconPath: IconsPath.home,
                selected: selectedIndex == 0,
                ext: ext,
                onTap: () => onchange(0),
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
              if (showCreate) _CreateFab(onTap: onCreateTap, ext: ext),
              _NavTab(
                label: 'Gallery',
                iconPath: IconsPath.gallery,
                selected: selectedIndex == 2,
                ext: ext,
                onTap: () => onchange(2),
              ),
              _NavTab(
                label: 'Creators',
                iconPath: IconsPath.photographer,
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
    final inactiveColor = ext.glassIcon;
    final color = selected ? activeColor : inactiveColor;

    Widget iconWidget = icon != null
        ? Icon(
            selected && selectedIcon != null ? selectedIcon! : icon!,
            size: 22.sp,
            color: color,
          )
        : Image.asset(
            iconPath!,
            width: 22.sp,
            height: 22.sp,
            color: color,
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

    return Expanded(
      child: Semantics(button: true, child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 62.h,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pill highlight expands behind icon when active
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14.w : 8.w,
                  vertical: 6.h,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: iconWidget,
              ),

              // Label — always occupies space but fades in/out
              SizedBox(height: 3.h),
              SizedBox(
                height: 12.h,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: selected ? 1.0 : 0.0,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: activeColor,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

// ── Center create button ──────────────────────────────────────────────────────

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap, required this.ext});
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(button: true, label: 'Medium impact', child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ext.accentGold, const Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: ext.accentGold.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26.sp,
            ),
          ),
        ),
      )),
    );
  }
}
