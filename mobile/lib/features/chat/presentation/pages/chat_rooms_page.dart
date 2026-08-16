import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_search_page.dart';
import 'package:jperg_app/features/chat/presentation/pages/new_chat_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The inbox — every conversation, newest first, with any pending group
/// invites carded above them.
class ChatRoomsPage extends StatelessWidget {
  const ChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context) => const _ChatRoomsView();
}

class _ChatRoomsView extends StatelessWidget {
  const _ChatRoomsView();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: ext.greetingColor, size: 22.sp),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        // Chats is a bottom-nav destination, so there is usually nothing to pop
        // back to. The arrow is drawn only when there actually is.
        automaticallyImplyLeading: false,
        title: Text(
          'Chats',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(Icons.search_rounded,
                color: ext.greetingColor, size: 22.sp),
            onPressed: () => _openSearch(context),
          ),
          IconButton(
            tooltip: 'New chat',
            icon: Icon(Icons.edit_square,
                color: ext.accentGold, size: 20.sp),
            onPressed: () => _openNewChat(context),
          ),
          SizedBox(width: AppSpacing.xs.w),
        ],
      ),
      body: BlocBuilder<ChatRoomsBloc, ChatRoomsState>(
        builder: (context, state) {
          if (state.isLoading) return const AppLoadingIndicator();

          if (state.errorMessage != null &&
              state.rooms.isEmpty &&
              state.pendingInvites.isEmpty) {
            return AppErrorView(
              message: state.errorMessage!,
              icon: Icons.chat_bubble_outline_rounded,
              onRetry: () => context
                  .read<ChatRoomsBloc>()
                  .add(const ChatRoomsLoadRequested()),
            );
          }

          final conversations =
              state.rooms.where((r) => r.type.isConversation).toList()
                ..sort((a, b) {
                  final la = state.lastMessageAt[a.id] ??
                      a.lastMessage?.createdAt ??
                      a.createdAt;
                  final lb = state.lastMessageAt[b.id] ??
                      b.lastMessage?.createdAt ??
                      b.createdAt;
                  return lb.compareTo(la);
                });

          if (conversations.isEmpty && state.pendingInvites.isEmpty) {
            return _EmptyInbox(onStartChat: () => _openNewChat(context));
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: RefreshIndicator(
                color: ext.accentGold,
                onRefresh: () async => context
                    .read<ChatRoomsBloc>()
                    .add(const ChatRoomsLoadRequested()),
                child: CustomScrollView(
                  slivers: [
                    if (state.isSyncing)
                      SliverToBoxAdapter(
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          color: ext.accentGold.withValues(alpha: 0.6),
                        ),
                      ),

                    if (state.pendingInvites.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _PendingInvitesCard(
                          invites: state.pendingInvites,
                          currentUserId: state.currentUserId,
                          onAccept: (id) => context
                              .read<ChatRoomsBloc>()
                              .add(ChatRoomsAcceptInvite(id)),
                          onDecline: (id) => context
                              .read<ChatRoomsBloc>()
                              .add(ChatRoomsDeclineInvite(id)),
                        ),
                      ),

                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final room = conversations[index];
                          return Reveal(
                            delay: AppMotion.stagger * (index < 8 ? index : 0),
                            offset: const Offset(0, 14),
                            child: Column(
                              children: [
                                RoomTile(
                                  room: room,
                                  unreadCount: state.unreadCounts[room.id] ?? 0,
                                  lastMessageAt: state.lastMessageAt[room.id],
                                  currentUserId: state.currentUserId,
                                  previewOverride: state.livePreviews[room.id],
                                  onTap: () => _openRoom(context, room),
                                ),
                                if (index < conversations.length - 1)
                                  _RowDivider(ext: ext),
                              ],
                            ),
                          );
                        },
                        childCount: conversations.length,
                      ),
                    ),

                    SliverToBoxAdapter(child: SizedBox(height: 90.h)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: Colors.transparent);
  }

  void _openRoom(BuildContext context, ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final bloc = context.read<ChatRoomsBloc>();
    final room = await Navigator.of(context).push<ChatRoom>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const ChatSearchPage(),
        ),
      ),
    );
    if (room != null && context.mounted) _openRoom(context, room);
  }

  Future<void> _openNewChat(BuildContext context) async {
    final bloc = context.read<ChatRoomsBloc>();
    final room = await Navigator.of(context).push<ChatRoom>(
      MaterialPageRoute(builder: (_) => const NewChatPage()),
    );
    if (room == null || !context.mounted) return;
    // A brand-new room is not in the cached list yet, so pull it in before
    // opening — otherwise backing out lands on an inbox that doesn't show it.
    bloc.add(const ChatRoomsLoadRequested());
    _openRoom(context, room);
  }
}

/// Hairline between rows, indented past the avatar as in the designs.
class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: 78.w, right: AppSpacing.lg.w),
        child: Divider(
          height: 1,
          thickness: 1,
          color: ext.searchHintColor.withValues(alpha: 0.14),
        ),
      );
}

// ── Pending invites ───────────────────────────────────────────────────────────

class _PendingInvitesCard extends StatelessWidget {
  const _PendingInvitesCard({
    required this.invites,
    required this.currentUserId,
    required this.onAccept,
    required this.onDecline,
  });

  final List<ChatRoom> invites;
  final String currentUserId;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onDecline;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.fromLTRB(AppSpacing.md.w, AppSpacing.sm.h,
          AppSpacing.md.w, AppSpacing.sm.h),
      padding: EdgeInsets.fromLTRB(AppSpacing.md.w, 12.h, AppSpacing.md.w, 12.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: ext.accentGold.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUP INVITE (${invites.length})',
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          for (int i = 0; i < invites.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                child: Divider(
                  height: 1,
                  color: ext.accentGold.withValues(alpha: 0.25),
                ),
              ),
            _InviteRow(
              room: invites[i],
              currentUserId: currentUserId,
              onAccept: () => onAccept(invites[i].id),
              onDecline: () => onDecline(invites[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.room,
    required this.currentUserId,
    required this.onAccept,
    required this.onDecline,
  });

  final ChatRoom room;
  final String currentUserId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final inviter = room.inviterNameFor(currentUserId);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.displayName,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                // Invites sent before the server recorded who sent them have no
                // name to show, so they fall back to the impersonal wording.
                inviter != null
                    ? '$inviter invited you to join'
                    : 'You were invited to join',
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
        SizedBox(width: AppSpacing.sm.w),
        _InviteButton(label: 'Join', filled: true, onTap: onAccept),
        SizedBox(width: AppSpacing.sm.w),
        _InviteButton(label: 'Decline', filled: false, onTap: onDecline),
      ],
    );
  }
}

class _InviteButton extends StatelessWidget {
  const _InviteButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(
            color: filled ? ext.accentGold : ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            border: filled
                ? null
                : Border.all(
                    color: ext.searchHintColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : ext.greetingColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.onStartChat});
  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ext.accentGold.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.chat_bubble_outline_rounded,
                  color: ext.accentGold, size: 42.sp),
            ),
            SizedBox(height: AppSpacing.xl.h),
            Text(
              'No messages yet!',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            // One sentence with only the opening words tappable, so the link
            // reads as part of the sentence rather than a button under it.
            Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Semantics(
                      button: true,
                      label: 'Start a chat',
                      child: GestureDetector(
                        onTap: onStartChat,
                        child: Text(
                          'Start a chat',
                          style: TextStyle(
                            color: ext.accentGold,
                            fontSize: 13.sp,
                            decoration: TextDecoration.underline,
                            decorationColor: ext.accentGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: ' to see your conversations here',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
