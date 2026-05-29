import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class CardDescriptionText extends StatefulWidget {
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
  State<CardDescriptionText> createState() => _CardDescriptionTextState();
}

class _CardDescriptionTextState extends State<CardDescriptionText> {
  bool _tagsExpanded = false;

  String get _tagLine {
    final tags = widget.event.contentTags;
    if (tags.isEmpty) return '';
    return tags.map((t) => '#$t').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final tagLine = _tagLine;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 9.h, 14.w, 9.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Event name ───────────────────────────────────────────────────
          Text(
            widget.event.eventName,
            maxLines: widget.expanded ? null : 2,
            overflow:
                widget.expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.3,
            ),
          ),

          // ── Content tags from backend ────────────────────────────────────
          if (tagLine.isNotEmpty) ...[
            SizedBox(height: 5.h),
            GestureDetector(
              onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tagLine,
                    maxLines: _tagsExpanded ? null : 1,
                    overflow: _tagsExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ext.accentGold.withValues(alpha: 0.85),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    _tagsExpanded ? 'less' : 'more',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
