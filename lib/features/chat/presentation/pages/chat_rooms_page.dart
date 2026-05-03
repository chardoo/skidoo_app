import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/chat/presentation/pages/create_group_page.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

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

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        centerTitle: false,
        title: Text(
          AppLocalizations.of(context)!.chatRoomsTitle,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.public_rounded,
                color: ext.accentGold, size: 22.sp),
            onPressed: () => _openGlobalChat(context),
            tooltip: AppLocalizations.of(context)!.chatRoomsGlobalChat,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: ext.greetingColor, size: 20.sp),
            onPressed: () => context
                .read<ChatRoomsBloc>()
                .add(const ChatRoomsLoadRequested()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ext.accentGold,
        foregroundColor: Colors.white,
        tooltip: AppLocalizations.of(context)!.chatRoomsNewGroup,
        onPressed: () => _openCreateGroup(context),
        child: const Icon(Icons.group_add_rounded),
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

          final filtered =
              state.rooms.where((r) => r.type.isConversation).toList();

          final noConversationsAction = TextButton(
            onPressed: () => _openGlobalChat(context),
            child: Text(AppLocalizations.of(context)!.chatRoomsJoinGlobalChat,
                style: TextStyle(color: ext.accentGold)),
          );

          if (filtered.isEmpty && state.pendingInvites.isEmpty) {
            return AppEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              message: AppLocalizations.of(context)!.chatRoomsNoConversations,
              action: noConversationsAction,
            );
          }

          final sorted = [...filtered]..sort((a, b) {
              final la = state.lastMessageAt[a.id] ?? a.createdAt;
              final lb = state.lastMessageAt[b.id] ?? b.createdAt;
              return lb.compareTo(la);
            });

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  if (state.isSyncing)
                    LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: ext.accentGold.withValues(alpha: 0.6),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: ext.accentGold,
                      onRefresh: () async => context
                          .read<ChatRoomsBloc>()
                          .add(const ChatRoomsLoadRequested()),
                      child: ListView(
                        padding: EdgeInsets.only(top: 8.h, bottom: 80.h),
                        children: [
                          // Pending invites appear above active rooms.
                          if (state.pendingInvites.isNotEmpty) ...[
                            _SectionHeader(label: AppLocalizations.of(context)!.chatRoomsPendingInvites, ext: ext),
                            ...state.pendingInvites.map((room) =>
                                _PendingInviteTile(
                                  room: room,
                                  ext: ext,
                                  onAccept: () => context
                                      .read<ChatRoomsBloc>()
                                      .add(ChatRoomsAcceptInvite(room.id)),
                                  onDecline: () => context
                                      .read<ChatRoomsBloc>()
                                      .add(ChatRoomsDeclineInvite(room.id)),
                                )),
                            SizedBox(height: 8.h),
                          ],
                          if (sorted.isNotEmpty)
                            _SectionHeader(label: AppLocalizations.of(context)!.chatRoomsChats, ext: ext),
                          ...sorted.map((room) => RoomTile(
                                room: room,
                                unreadCount:
                                    state.unreadCounts[room.id] ?? 0,
                                lastMessageAt: state.lastMessageAt[room.id],
                                onTap: () => _openRoom(context, room),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openRoom(BuildContext context, ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );
  }

  void _openGlobalChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatRoomPage.global()),
    );
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    final result = await Navigator.of(context).push<ChatRoom>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (result != null && context.mounted) {
      context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: result)),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.ext});
  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Text(
        label,
        style: TextStyle(
          color: ext.searchHintColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PendingInviteTile extends StatelessWidget {
  const _PendingInviteTile({
    required this.room,
    required this.ext,
    required this.onAccept,
    required this.onDecline,
  });

  final ChatRoom room;
  final AppThemeExtension ext;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: ext.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38.w,
            height: 38.h,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.group_rounded, color: Colors.orange, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.displayName,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  AppLocalizations.of(context)!.chatRoomsYouWereInvited,
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          _ActionButton(
            label: AppLocalizations.of(context)!.chatRoomsJoin,
            color: ext.accentGold,
            onTap: onAccept,
          ),
          SizedBox(width: 6.w),
          _ActionButton(
            label: AppLocalizations.of(context)!.chatRoomsDecline,
            color: ext.searchHintColor,
            onTap: onDecline,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
