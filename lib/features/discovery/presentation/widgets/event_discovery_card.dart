import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_description_text.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_comment_sheet.dart';

class EventDiscoveryCard extends StatefulWidget {
  const EventDiscoveryCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isAuthenticated = false,
    this.onCommentTap,
  });

  final EventDiscovery event;
  final VoidCallback onTap;

  /// When true: no blur overlay, interaction bar shown below the card.
  final bool isAuthenticated;

  /// Called when the comment button is tapped (authenticated only).
  final VoidCallback? onCommentTap;

  @override
  State<EventDiscoveryCard> createState() => _EventDiscoveryCardState();
}

class _EventDiscoveryCardState extends State<EventDiscoveryCard> {
  bool _liked = false;
  bool _saved = false;
  int _likeCount = 0;
  bool _descExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = widget.event.pictures;

    final screenSize = MediaQuery.sizeOf(context);
    final photoH = (screenSize.height * 0.27).clamp(170.0, 320.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo area ───────────────────────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              height: photoH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photos
                  pics.isEmpty
                      ? CardGradientPlaceholder(name: widget.event.eventName)
                      : CardPhotoPreviewGrid(
                          pics: pics,
                          ext: ext,
                          showBlur: !widget.isAuthenticated,
                        ),

                  // Gradient behind header text
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 90.h,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xCC000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),

                  // Header: avatar + event name + count badge
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16.r,
                            backgroundColor: ext.accentGold,
                            child: Text(
                              widget.event.photographerName.isNotEmpty
                                  ? widget.event.photographerName[0]
                                      .toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.event.eventName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 4,
                                          color: Colors.black54),
                                    ],
                                  ),
                                ),
                                Text(
                                  'by ${widget.event.photographerName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pics.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '${pics.length} photos',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Interaction bar (authenticated only) ─────────────────────
          if (widget.isAuthenticated) ...[
            CardInteractionBar(
              liked: _liked,
              saved: _saved,
              likeCount: _likeCount,
              ext: ext,
              onLike: () => setState(() {
                _liked = !_liked;
                _likeCount += _liked ? 1 : -1;
              }),
              onComment: widget.onCommentTap ?? () => _showCommentSheet(context, ext),
              onShare: () {},
              onSave: () => setState(() => _saved = !_saved),
            ),
            CardDescriptionText(
              event: widget.event,
              ext: ext,
              expanded: _descExpanded,
              onToggle: () =>
                  setState(() => _descExpanded = !_descExpanded),
            ),
            SizedBox(height: 12.h),
          ],
        ],
      ),
        ),
      ),
    );
  }

  void _showCommentSheet(BuildContext context, AppThemeExtension ext) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CardCommentSheet(ext: ext, eventName: widget.event.eventName),
    );
  }
}
