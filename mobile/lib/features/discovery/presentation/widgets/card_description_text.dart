import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
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

  String get _hashtags {
    final name = event.eventName.toLowerCase().replaceAll(' ', '');
    final ph = event.photographerName.toLowerCase().replaceAll(' ', '');
    return '#$name #$ph #photography #event #moments';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photographer name + caption inline (Instagram style)
          GestureDetector(
            onTap: onToggle,
            child: RichText(
              maxLines: expanded ? null : 2,
              overflow:
                  expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13.sp, height: 1.5, color: ext.greetingColor),
                children: [
                  TextSpan(
                    text: '${event.eventName}  ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ext.greetingColor,
                    ),
                  ),
                  ..._hashtagSpans(),
                ],
              ),
            ),
          ),

          if (!expanded) ...[
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: onToggle,
              child: Text(
                'more',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],

          // Date
          if (eventDate != null && eventDate!.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Text(
              _formatDate(eventDate!),
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 11.sp,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<InlineSpan> _hashtagSpans() {
    return _hashtags.split(' ').map((tag) => TextSpan(
          text: '$tag ',
          style: TextStyle(
            color: ext.accentGold,
            fontWeight: FontWeight.w500,
          ),
        )).toList();
  }

  String _formatDate(String raw) {
    try {
      return DateFormat('MMMM d, y').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}
