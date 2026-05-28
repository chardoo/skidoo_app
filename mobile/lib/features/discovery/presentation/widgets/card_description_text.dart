import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

/// Instagram-style single-line caption below the photo.
/// The full event context (name, photographer, photo count) is already shown
/// as a TikTok-style overlay on the image; this section is intentionally minimal.
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
    return GestureDetector(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 9.h, 14.w, 9.h),
        child: RichText(
          maxLines: expanded ? null : 2,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.45,
              color: ext.greetingColor,
            ),
            children: [
              TextSpan(
                text: event.eventName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: '  ',
                style: TextStyle(color: ext.searchHintColor),
              ),
              TextSpan(
                text: event.photographerName,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
