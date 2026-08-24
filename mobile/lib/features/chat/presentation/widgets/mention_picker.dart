import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The member list that opens above the composer while an `@` is being typed.
///
/// Sits directly on top of the input rather than floating over the
/// conversation: it belongs to what is being typed, and the designs put it
/// there — the last messages stay visible above it, which is usually what the
/// mention is about.
class MentionPicker extends StatelessWidget {
  const MentionPicker({
    super.key,
    required this.participants,
    required this.handles,
    required this.onSelected,
  });

  final List<ChatParticipant> participants;

  /// {userId: handle} — the token inserted when a row is tapped.
  final Map<String, String> handles;

  final ValueChanged<ChatParticipant> onSelected;

  /// Roughly three rows. Beyond that the list scrolls rather than pushing the
  /// conversation off the screen — on a short phone a group of twelve would
  /// otherwise leave nothing visible but the picker.
  static const double _maxHeightFraction = 0.28;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final maxHeight = MediaQuery.of(context).size.height * _maxHeightFraction;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(color: ext.searchHintColor.withValues(alpha: 0.15)),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        // Always scrollable so a long member list can be reached even when the
        // constraint above has already capped the height.
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final p = participants[index];
          final handle = handles[p.userId] ?? '';
          // The best match is tinted, as in the designs — it says which name
          // the list is leading with when several are close.
          final isHighlighted = index == 0;
          return Semantics(
            button: true,
            label: 'Mention ${p.displayName}',
            child: InkWell(
              onTap: () => onSelected(p),
              child: Container(
                color: isHighlighted
                    ? ext.accentGold.withValues(alpha: 0.10)
                    : Colors.transparent,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w,
                  vertical: AppSpacing.sm.h,
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      imageUrl: p.userImage,
                      initial: p.displayName,
                      radius: 16,
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.displayName,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@$handle',
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 12.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
