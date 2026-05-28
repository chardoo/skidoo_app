import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class CardDescriptionText extends StatelessWidget {
  const CardDescriptionText({
    super.key,
    required this.event,
    required this.ext,
    required this.expanded,
    required this.onToggle,
    this.eventDate,
  });

  final EventDiscovery event;
  final AppThemeExtension ext;
  final bool expanded;
  final VoidCallback onToggle;
  final String? eventDate;

  @override
  Widget build(BuildContext context) {
    final photoCount = event.pictures.length;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event name + photographer ──────────────────────────────────
          GestureDetector(
            onTap: onToggle,
            child: RichText(
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.5,
                  color: ext.greetingColor,
                ),
                children: [
                  TextSpan(
                    text: event.eventName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ext.greetingColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  TextSpan(
                    text: '  by ',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                    ),
                  ),
                  TextSpan(
                    text: event.photographerName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ext.greetingColor,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 6.h),

          // ── Meta row: photo count + optional date ──────────────────────
          Row(
            children: [
              _MetaChip(
                icon: Icons.photo_library_rounded,
                label: '$photoCount ${photoCount == 1 ? 'photo' : 'photos'}',
                ext: ext,
              ),
              if (eventDate != null && eventDate!.isNotEmpty) ...[
                SizedBox(width: 8.w),
                _MetaChip(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(eventDate!),
                  ext: ext,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.ext,
  });

  final IconData icon;
  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: ext.accentGold),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
