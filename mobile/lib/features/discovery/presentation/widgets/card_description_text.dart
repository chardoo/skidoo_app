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

  /// Converts event name to a hashtag: "Wedding Party" → "#weddingparty"
  String get _primaryTag {
    final cleaned = event.eventName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '');
    return '#$cleaned';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 9.h, 14.w, 9.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Event name
            Text(
              event.eventName,
              maxLines: expanded ? null : 2,
              overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                height: 1.4,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 4.h),
            // Hashtags
            Text(
              '$_primaryTag #photography #event',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ext.accentGold.withValues(alpha: 0.85),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
