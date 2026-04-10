import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:skidoo_app/models/chat/chat_room.dart' show ChatRoom;

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
          'Messages',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          // Global chat shortcut
          IconButton(
            icon: Icon(Icons.public_rounded,
                color: ext.accentGold, size: 22.sp),
            onPressed: () => _openGlobalChat(context),
            tooltip: 'Global Chat',
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
      body: BlocBuilder<ChatRoomsBloc, ChatRoomsState>(
        builder: (context, state) {
          if (state.isLoading) return const AppLoadingIndicator();

          if (state.errorMessage != null && state.rooms.isEmpty) {
            return AppErrorView(
              message: state.errorMessage!,
              icon: Icons.chat_bubble_outline_rounded,
              onRetry: () => context
                  .read<ChatRoomsBloc>()
                  .add(const ChatRoomsLoadRequested()),
            );
          }

          final noConversationsAction = TextButton(
            onPressed: () => _openGlobalChat(context),
            child: Text('Join Global Chat',
                style: TextStyle(color: ext.accentGold)),
          );

          if (state.rooms.isEmpty) {
            return AppEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'No conversations yet.',
              action: noConversationsAction,
            );
          }

          // Only show personal conversations (direct messages and private event rooms).
          final filtered = state.rooms
              .where((r) => r.type.isConversation)
              .toList();

          if (filtered.isEmpty) {
            return AppEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              message: 'No conversations yet.',
              action: noConversationsAction,
            );
          }

          // Sort: rooms with unread messages first, then by createdAt descending.
          final sorted = [...filtered]..sort((a, b) {
              final ua = state.unreadCounts[a.id] ?? 0;
              final ub = state.unreadCounts[b.id] ?? 0;
              if (ua != ub) return ub.compareTo(ua);
              return b.createdAt.compareTo(a.createdAt);
            });

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
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
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 8.h, bottom: 24.h),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final room = sorted[index];
                          return RoomTile(
                            room: room,
                            unreadCount: state.unreadCounts[room.id] ?? 0,
                            onTap: () => _openRoom(context, room),
                          );
                        },
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
      MaterialPageRoute(
        builder: (_) => const ChatRoomPage.global(),
      ),
    );
  }
}
