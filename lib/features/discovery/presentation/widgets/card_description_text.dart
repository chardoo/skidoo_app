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
  });

  final EventDiscovery event;
  final AppThemeExtension ext;
  final bool expanded;
  final VoidCallback onToggle;

  String get _caption {
    final name = event.eventName.toLowerCase().replaceAll(' ', '');
    final photographer =
        event.photographerName.toLowerCase().replaceAll(' ', '');
    return '${event.eventName} captured by ${event.photographerName}  '
        '#$name #$photographer #photography #event #moments';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: GestureDetector(
        onTap: onToggle,
        child: RichText(
          maxLines: expanded ? null : 2,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(fontSize: 13.sp, height: 1.4),
            children: _buildSpans(context),
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context) {
    final parts = _caption.split(' ');
    final spans = <InlineSpan>[];
    for (final word in parts) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(
              color: ext.accentGold, fontWeight: FontWeight.w500),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: TextStyle(color: ext.greetingColor),
        ));
      }
    }
    return spans;
  }
}
