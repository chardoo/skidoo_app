import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/expandable_caption.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

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

  String get _tagLine {
    final tags = event.contentTags;
    if (tags.isEmpty) return '';
    return tags.map((t) => '#$t').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final tagLine = _tagLine;
    final linkStyle = TextStyle(
      color: ext.searchHintColor,
      fontSize: 11.sp,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 9.h, 14.w, 9.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Event name ───────────────────────────────────────────────────
          Text(
            event.eventName,
            maxLines: expanded ? null : 2,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.3,
            ),
          ),

          // ── Description (backend caption text) — "more"/"less" only shows
          // when the text actually overflows 2 lines. ───────────────────────
          if (event.description.isNotEmpty) ...[
            SizedBox(height: 3.h),
            ExpandableCaption(
              text: event.description,
              collapsedMaxLines: 2,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 13.sp,
                height: 1.35,
              ),
              linkStyle: linkStyle,
            ),
          ],

          // ── Content tags from backend ────────────────────────────────────
          if (tagLine.isNotEmpty) ...[
            SizedBox(height: 5.h),
            ExpandableCaption(
              text: tagLine,
              collapsedMaxLines: 1,
              style: TextStyle(
                color: ext.accentGold.withValues(alpha: 0.85),
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              linkStyle: linkStyle,
            ),
          ],
        ],
      ),
    );
  }
}
