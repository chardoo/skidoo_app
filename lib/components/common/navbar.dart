import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/constants/icons.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class AppNavbar extends StatelessWidget {
  const AppNavbar({
    super.key,
    required this.selectedIndex,
    required this.onchange,
    this.messageUnreadCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onchange;
  final int messageUnreadCount;

  static const _items = [
    _NavItem(label: 'Home', iconPath: IconsPath.home),
    _NavItem(label: 'Gallery', iconPath: IconsPath.gallery),
    _NavItem(label: 'Photographers', iconPath: IconsPath.photographer),
    _NavItem(label: 'Messages', iconPath: null, icon: Icons.chat_bubble_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final selected = index == selectedIndex;
              final badge = index == 3 ? messageUnreadCount : 0;
              return _NavBarButton(
                item: _items[index],
                selected: selected,
                ext: ext,
                unreadCount: badge,
                onTap: () => onchange(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Single tab button ─────────────────────────────────────────────────────────

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({
    required this.item,
    required this.selected,
    required this.ext,
    required this.onTap,
    this.unreadCount = 0,
  });

  final _NavItem item;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? ext.accentGold : ext.searchHintColor;
    final iconWidget = item.icon != null
        ? Icon(item.icon, size: 20.h, color: iconColor)
        : Image.asset(
            item.iconPath!,
            width: 20.h,
            height: 20.h,
            color: iconColor,
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 16.w : 12.w,
          vertical: 8.h,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ext.accentGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  iconWidget,
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: EdgeInsets.all(unreadCount > 9 ? 2.r : 3.r),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            else
              iconWidget,
            if (selected) ...[
              SizedBox(width: 8.w),
              Text(
                item.label,
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.label, this.iconPath, this.icon});
  final String label;
  final String? iconPath;
  final IconData? icon;
}
