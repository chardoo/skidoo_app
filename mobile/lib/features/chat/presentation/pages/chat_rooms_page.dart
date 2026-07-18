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
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/widgets/animations/app_animations.dart';

class ChatRoomsPage extends StatelessWidget {
  const ChatRoomsPage({super.key});

  @override
  Widget build(BuildContext context) => const _ChatRoomsView();
}

class _ChatRoomsView extends StatefulWidget {
  const _ChatRoomsView();

  @override
  State<_ChatRoomsView> createState() => _ChatRoomsViewState();
}

class _ChatRoomsViewState extends State<_ChatRoomsView> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: ext.accentGold,
        foregroundColor: Colors.white,
        tooltip: l10n.chatRoomsNewGroup,
        onPressed: () => _openCreateGroup(context),
        child: const Icon(Icons.group_add_rounded),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 16.w,
            title: Text(
              l10n.chatRoomsTitle,
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: ext.greetingColor, size: 20.sp),
                onPressed: () => context
                    .read<ChatRoomsBloc>()
                    .add(const ChatRoomsLoadRequested()),
              ),
            ],
          ),
        ],
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

            if (filtered.isEmpty && state.pendingInvites.isEmpty) {
              return AppEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                message: l10n.chatRoomsNoConversations,
                action: TextButton(
                  onPressed: () => _openGlobalChat(context),
                  child: Text(l10n.chatRoomsJoinGlobalChat,
                      style: TextStyle(color: ext.accentGold)),
                ),
              );
            }

            final sorted = [...filtered]..sort((a, b) {
                final la = state.lastMessageAt[a.id] ?? a.createdAt;
                final lb = state.lastMessageAt[b.id] ?? b.createdAt;
                return lb.compareTo(la);
              });

            final q = _searchQuery.toLowerCase();
            final displayed = q.isEmpty
                ? sorted
                : sorted
                    .where((r) => r
                        .displayNameFor(state.currentUserId)
                        .toLowerCase()
                        .contains(q))
                    .toList();

            final showPendingInvites =
                state.pendingInvites.isNotEmpty && _searchQuery.isEmpty;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: RefreshIndicator(
                  color: ext.searchHintColor,
                  onRefresh: () async => context
                      .read<ChatRoomsBloc>()
                      .add(const ChatRoomsLoadRequested()),
                  child: CustomScrollView(
                    slivers: [
                      // Sync indicator
                      if (state.isSyncing)
                        SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            backgroundColor: Colors.transparent,
                            color: ext.searchHintColor.withValues(alpha: 0.6),
                          ),
                        ),

                      // Search bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 4.h),
                          child: SearchField(
                            controller: _searchCtrl,
                            hint: 'Search messages...',
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                            onClear: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                        ),
                      ),

                      // Pending invites
                      if (showPendingInvites) ...[
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                              label: l10n.chatRoomsPendingInvites, ext: ext),
                        ),
                        SliverList(
                          delegate: SliverChildListDelegate(
                            state.pendingInvites
                                .map((room) => _PendingInviteTile(
                                      room: room,
                                      ext: ext,
                                      onAccept: () => context
                                          .read<ChatRoomsBloc>()
                                          .add(ChatRoomsAcceptInvite(room.id)),
                                      onDecline: () => context
                                          .read<ChatRoomsBloc>()
                                          .add(
                                              ChatRoomsDeclineInvite(room.id)),
                                    ))
                                .toList(),
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: 8.h)),
                      ],

                      // Chats section header
                      if (displayed.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                              label: l10n.chatRoomsChats, ext: ext),
                        ),

                      // Room tiles
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final room = displayed[index];
                            return Reveal(
                              delay: AppMotion.stagger * (index < 8 ? index : 0),
                              offset: const Offset(0, 14),
                              child: RoomTile(
                                room: room,
                                unreadCount:
                                    state.unreadCounts[room.id] ?? 0,
                                lastMessageAt: state.lastMessageAt[room.id],
                                currentUserId: state.currentUserId,
                                onTap: () => _openRoom(context, room),
                              ),
                            );
                          },
                          childCount: displayed.length,
                        ),
                      ),

                      // No search results
                      if (displayed.isEmpty && _searchQuery.isNotEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40.h),
                              child: Text(
                                'No chats match "$_searchQuery"',
                                style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 14.sp),
                              ),
                            ),
                          ),
                        ),

                      SliverToBoxAdapter(child: SizedBox(height: 80.h)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    return webWrap(page, backgroundColor: Colors.transparent);
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
            child:
                Icon(Icons.group_rounded, color: Colors.orange, size: 18.sp),
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
    return Semantics(button: true, label: label, child: GestureDetector(
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
    ));
  }
}
