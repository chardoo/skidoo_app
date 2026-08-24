import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_avatar.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// "Forward to…" — pick one conversation to send a copy of a message to.
///
/// Reads the cached room list first and then the server's, so the list is on
/// screen immediately and corrects itself a moment later. Forwarding is a
/// two-tap action; making the second tap wait on a network round trip is what
/// makes it feel like three.
///
/// Pops with the chosen [ChatRoom], or null when dismissed.
class ForwardMessageSheet extends StatefulWidget {
  const ForwardMessageSheet({
    super.key,
    required this.myUserId,
    this.excludeRoomId,
  });

  final String myUserId;

  /// The room the message came from — offering to forward it back into the
  /// conversation it is already in is never what was meant.
  final String? excludeRoomId;

  @override
  State<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends State<ForwardMessageSheet> {
  List<ChatRoom> _rooms = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cached = await sl<GetCachedRoomsUseCase>().call();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _rooms = _usable(cached);
          _loading = false;
        });
      }
    } catch (_) {
      // Cache miss is not a failure — the fetch below is the real source.
    }
    try {
      final fresh = await sl<GetMyRoomsUseCase>().call();
      if (mounted) setState(() => _rooms = _usable(fresh));
    } catch (_) {
      // Keep whatever the cache gave us rather than emptying the list.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Rooms a message can actually be forwarded into: real conversations the
  /// user is a full member of. A pending invite is not one — the server would
  /// refuse the send.
  List<ChatRoom> _usable(List<ChatRoom> rooms) => [
        for (final room in rooms)
          if (room.type.isConversation &&
              room.id != widget.excludeRoomId &&
              !room.hasPendingInvite(widget.myUserId))
            room,
      ];

  List<ChatRoom> get _visible {
    if (_query.trim().isEmpty) return _rooms;
    final q = _query.trim().toLowerCase();
    return [
      for (final room in _rooms)
        if (room.displayNameFor(widget.myUserId).toLowerCase().contains(q))
          room,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final rooms = _visible;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: AppSpacing.sm.h),
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl.w, AppSpacing.lg.h, AppSpacing.xl.w, AppSpacing.sm.h),
              child: Row(
                children: [
                  Text(
                    'Forward to',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_loading)
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ext.searchHintColor),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: ext.searchFieldFill,
                  hintText: 'Search conversations',
                  hintStyle:
                      TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18.sp, color: ext.searchHintColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22.r),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Expanded(
              child: rooms.isEmpty
                  ? Center(
                      child: Text(
                        _loading ? 'Loading…' : 'No conversations to forward to',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 13.sp),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return ListTile(
                          leading: RoomAvatar(
                            room: room,
                            currentUserId: widget.myUserId,
                            radius: 20,
                          ),
                          title: Text(
                            room.displayNameFor(widget.myUserId),
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(room),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
