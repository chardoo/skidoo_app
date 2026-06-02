import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/navigation/app_navigator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_panel_route.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/create_group_page.dart';
import 'package:skidoo_app/features/chat/presentation/pages/group_info_page.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_entrance.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

// Panel width / top gap and the constrained-page push helper live in
// web_panel_route.dart so every chat page can land in the same panel column.

/// Right-side overlay panel for web desktop/laptop.
///
/// Slides in over the current page without removing it. Shows the rooms list
/// by default; tapping a room opens the conversation inline within the panel.
/// Tapping the semi-transparent backdrop, or pressing the ✕ icon, closes it.
class WebMessagesPanel extends StatefulWidget {
  const WebMessagesPanel({super.key, required this.onClose, this.initialRoom});

  final VoidCallback onClose;

  /// When provided, the panel opens straight into this conversation instead of
  /// the rooms list.
  final ChatRoom? initialRoom;

  /// Opens the messages panel as a global right-side overlay on web, optionally
  /// jumping straight to [initialRoom]. Single entry point so every "message"
  /// affordance (top-bar icon, photographer profile, etc.) lands in the same
  /// panel. Returns true if it was actually shown.
  static bool open({ChatRoom? initialRoom}) {
    final nav = AppNavigator.navigatorKey.currentState;
    if (nav == null) return false;
    nav.push(
      PageRouteBuilder<void>(
        opaque: false,
        // The panel draws its own dimmed backdrop, so the route stays clear.
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => Material(
          color: Colors.transparent,
          child: WebMessagesPanel(
            initialRoom: initialRoom,
            onClose: () => nav.maybePop(),
          ),
        ),
      ),
    );
    return true;
  }

  @override
  State<WebMessagesPanel> createState() => _WebMessagesPanelState();
}

class _WebMessagesPanelState extends State<WebMessagesPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  ChatRoom? _activeRoom;

  @override
  void initState() {
    super.initState();
    _activeRoom = widget.initialRoom;
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  /// The active conversation's bloc, surfaced by the room view so the header's
  /// settings button can hand it to [GroupInfoPage].
  ChatRoomBloc? _activeRoomBloc;

  void _openRoom(ChatRoom room) {
    _activeRoomBloc = null;
    setState(() => _activeRoom = room);
  }

  void _backToRooms() {
    _activeRoomBloc = null;
    setState(() => _activeRoom = null);
  }

  /// Opens the new-group flow inside the panel, then drops into the freshly
  /// created room. The rooms list is refreshed regardless.
  Future<void> _openCreateGroup() async {
    final room =
        await showWebPanelPage<ChatRoom>(context, const CreateGroupPage());
    if (!mounted) return;
    context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
    if (room != null) setState(() => _activeRoom = room);
  }

  /// Opens group settings inside the panel, reusing the active room's bloc.
  void _openSettings() {
    final bloc = _activeRoomBloc;
    if (bloc == null) return;
    showWebPanelPage<void>(
      context,
      BlocProvider<ChatRoomBloc>.value(
        value: bloc,
        child: const GroupInfoPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Stack(
      children: [
        // ── Backdrop: tapping it closes the panel ──────────────────────────
        Positioned.fill(
          child: Semantics(button: true, label: 'Close', child: GestureDetector(
            onTap: widget.onClose,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          )),
        ),

        // ── Panel ──────────────────────────────────────────────────────────
        Positioned(
          top: kWebChatPanelTopGap,
          right: kWebChatPanelSideMargin,
          bottom: kWebChatPanelBottomMargin,
          width: kWebChatPanelWidth,
          child: SlideTransition(
            position: _slideAnim,
            child: WebPanelFloatingCard(
              child: _PanelShell(
              ext: ext,
              activeRoom: _activeRoom,
              onBack: _backToRooms,
              onClose: widget.onClose,
              onRoomTap: _openRoom,
              onCreateGroup: _openCreateGroup,
              onOpenSettings: _openSettings,
              onBlocReady: (bloc) => _activeRoomBloc = bloc,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Panel shell ───────────────────────────────────────────────────────────────

class _PanelShell extends StatelessWidget {
  const _PanelShell({
    required this.ext,
    required this.activeRoom,
    required this.onBack,
    required this.onClose,
    required this.onRoomTap,
    required this.onCreateGroup,
    required this.onOpenSettings,
    required this.onBlocReady,
  });

  final AppThemeExtension ext;
  final ChatRoom? activeRoom;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<ChatRoom> onRoomTap;
  final VoidCallback onCreateGroup;
  final VoidCallback onOpenSettings;
  final ValueChanged<ChatRoomBloc> onBlocReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
                Colors.white.withValues(alpha: 0.04), ext.homeBackground),
            ext.homeBackground,
          ],
        ),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _PanelHeader(
            ext: ext,
            activeRoom: activeRoom,
            onBack: onBack,
            onClose: onClose,
            onCreateGroup: onCreateGroup,
            onOpenSettings: onOpenSettings,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: activeRoom == null
                  ? _PanelRoomsList(
                      key: const ValueKey('rooms'),
                      ext: ext,
                      onRoomTap: onRoomTap,
                    )
                  : _PanelRoomView(
                      key: ValueKey(activeRoom!.id),
                      room: activeRoom!,
                      onBack: onBack,
                      ext: ext,
                      onBlocReady: onBlocReady,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Panel header ──────────────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.ext,
    required this.activeRoom,
    required this.onBack,
    required this.onClose,
    required this.onCreateGroup,
    required this.onOpenSettings,
  });

  final AppThemeExtension ext;
  final ChatRoom? activeRoom;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback onCreateGroup;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        border: Border(
          bottom: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (activeRoom != null)
            _HeaderIconBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor,
              onTap: onBack,
              semanticLabel: 'Back to conversations',
            ),
          if (activeRoom != null) const SizedBox(width: 8),
          Icon(Icons.chat_bubble_rounded, color: ext.accentGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activeRoom?.displayName ?? 'Messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // New-group button — only on the rooms list, not inside a chat.
          if (activeRoom == null) ...[
            _HeaderIconBtn(
              icon: Icons.group_add_rounded,
              color: ext.greetingColor,
              onTap: onCreateGroup,
              semanticLabel: 'New group',
            ),
            const SizedBox(width: 4),
          ],
          // Group settings — inside a group conversation.
          if (activeRoom?.type == RoomType.group) ...[
            _HeaderIconBtn(
              icon: Icons.info_outline_rounded,
              color: ext.greetingColor,
              onTap: onOpenSettings,
              semanticLabel: 'Group info',
            ),
            const SizedBox(width: 4),
          ],
          _HeaderIconBtn(
            icon: Icons.close_rounded,
            color: ext.searchHintColor,
            onTap: onClose,
            semanticLabel: 'Close messages',
          ),
        ],
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Panel rooms list ──────────────────────────────────────────────────────────

class _PanelRoomsList extends StatefulWidget {
  const _PanelRoomsList({
    super.key,
    required this.ext,
    required this.onRoomTap,
  });

  final AppThemeExtension ext;
  final ValueChanged<ChatRoom> onRoomTap;

  @override
  State<_PanelRoomsList> createState() => _PanelRoomsListState();
}

class _PanelRoomsListState extends State<_PanelRoomsList> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatRoomsBloc, ChatRoomsState>(
      builder: (context, state) {
        if (state.isLoading) return const AppLoadingIndicator();

        final rooms = state.rooms.where((r) => r.type.isConversation).toList()
          ..sort((a, b) {
            final la = state.lastMessageAt[a.id] ?? a.createdAt;
            final lb = state.lastMessageAt[b.id] ?? b.createdAt;
            return lb.compareTo(la);
          });

        final q = _query.toLowerCase();
        final displayed = q.isEmpty
            ? rooms
            : rooms
                .where((r) => r
                    .displayNameFor(state.currentUserId)
                    .toLowerCase()
                    .contains(q))
                .toList();

        // Pending group invites — only on the unfiltered list.
        final pending =
            q.isEmpty ? state.pendingInvites : const <ChatRoom>[];
        final bloc = context.read<ChatRoomsBloc>();

        return Column(
          children: [
            _PanelSearchBar(
              ext: widget.ext,
              controller: _searchCtrl,
              query: _query,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
            ),
            if (state.isSyncing)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: widget.ext.accentGold.withValues(alpha: 0.6),
              ),
            Expanded(
              child: (displayed.isEmpty && pending.isEmpty)
                  ? _PanelEmptyRooms(
                      ext: widget.ext, isFiltered: q.isNotEmpty, query: _query)
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        if (pending.isNotEmpty) ...[
                          _PanelSectionLabel(
                              ext: widget.ext, label: 'Pending invites'),
                          ...pending.map((room) => _PanelPendingTile(
                                room: room,
                                ext: widget.ext,
                                onAccept: () =>
                                    bloc.add(ChatRoomsAcceptInvite(room.id)),
                                onDecline: () =>
                                    bloc.add(ChatRoomsDeclineInvite(room.id)),
                              )),
                          const SizedBox(height: 4),
                          if (displayed.isNotEmpty)
                            _PanelSectionLabel(
                                ext: widget.ext, label: 'Chats'),
                        ],
                        ...displayed.map((room) => RoomTile(
                              room: room,
                              unreadCount: state.unreadCounts[room.id] ?? 0,
                              lastMessageAt: state.lastMessageAt[room.id],
                              currentUserId: state.currentUserId,
                              onTap: () => widget.onRoomTap(room),
                            )),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Panel search bar ──────────────────────────────────────────────────────────

class _PanelSearchBar extends StatelessWidget {
  const _PanelSearchBar({
    required this.ext,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final AppThemeExtension ext;
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: ext.glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ext.glassBorder),
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Icon(Icons.search_rounded, color: ext.glassIcon, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                style: TextStyle(color: ext.greetingColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search messages…',
                  hintStyle:
                      TextStyle(color: ext.searchHintColor, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
            if (query.isNotEmpty)
              Semantics(button: true, label: 'Clear', child: GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.close_rounded,
                      color: ext.searchHintColor, size: 16),
                ),
              ))
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ── Panel empty state ─────────────────────────────────────────────────────────

class _PanelEmptyRooms extends StatelessWidget {
  const _PanelEmptyRooms({
    required this.ext,
    required this.isFiltered,
    required this.query,
  });

  final AppThemeExtension ext;
  final bool isFiltered;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ext.accentGold.withValues(alpha: 0.20),
                    ext.accentGold.withValues(alpha: 0.03),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.forum_rounded,
                size: 38,
                color: ext.accentGold.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered ? 'No chats match "$query"' : 'No conversations yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isFiltered
                  ? 'Try a different name.'
                  : 'Start a chat from a profile, or tap the + to create a group.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pending invites (web panel) ───────────────────────────────────────────────

class _PanelSectionLabel extends StatelessWidget {
  const _PanelSectionLabel({required this.ext, required this.label});

  final AppThemeExtension ext;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.accentGold,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelPendingTile extends StatelessWidget {
  const _PanelPendingTile({
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.group_rounded, color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.chatRoomsYouWereInvited,
                  style: TextStyle(color: ext.searchHintColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _PanelPendingBtn(
              label: l10n.chatRoomsJoin, color: ext.accentGold, onTap: onAccept),
          const SizedBox(width: 6),
          _PanelPendingBtn(
              label: l10n.chatRoomsDecline,
              color: ext.searchHintColor,
              onTap: onDecline),
        ],
      ),
    );
  }
}

class _PanelPendingBtn extends StatelessWidget {
  const _PanelPendingBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Panel room view (provides BLoC) ───────────────────────────────────────────

class _PanelRoomView extends StatelessWidget {
  const _PanelRoomView({
    super.key,
    required this.room,
    required this.onBack,
    required this.ext,
    required this.onBlocReady,
  });

  final ChatRoom room;
  final VoidCallback onBack;
  final AppThemeExtension ext;
  final ValueChanged<ChatRoomBloc> onBlocReady;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      child: _PanelRoomContent(
        room: room,
        onBack: onBack,
        ext: ext,
        onBlocReady: onBlocReady,
      ),
    );
  }
}

// ── Panel room content ────────────────────────────────────────────────────────

class _PanelRoomContent extends StatefulWidget {
  const _PanelRoomContent({
    required this.room,
    required this.onBack,
    required this.ext,
    required this.onBlocReady,
  });

  final ChatRoom room;
  final VoidCallback onBack;
  final AppThemeExtension ext;
  final ValueChanged<ChatRoomBloc> onBlocReady;

  @override
  State<_PanelRoomContent> createState() => _PanelRoomContentState();
}

class _PanelRoomContentState extends State<_PanelRoomContent> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

  final Set<String> _knownIds = {};
  final Set<String> _animateIds = {};

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatRoomBloc>();
    // Surface the bloc so the panel header's settings button can reuse it.
    widget.onBlocReady(_bloc);
    _bloc.add(ChatRoomJoined(widget.room.id, room: widget.room));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _bloc.add(const ChatRoomLeft());
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _bloc.add(const ChatRoomLoadMoreRequested());
    }
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    final hasPendingImage = _bloc.state.pendingImagePath != null;
    if (text.isEmpty && !hasPendingImage) return;
    _bloc.add(ChatRoomMessageSent(
      text.isEmpty ? null : text,
      replyToId: _bloc.state.replyingTo?.id,
    ));
    _inputCtrl.clear();
  }

  void _onImagePicked(String filePath,
      {String? mimeType, bool isVideo = false}) {
    _bloc.add(
        ChatRoomImagePicked(filePath, isVideo: isVideo, mimeType: mimeType));
  }

  void _syncAnimationState(List<ChatMessage> messages, bool isLoadingHistory) {
    if (isLoadingHistory) return;
    final currentIds = messages.map((m) => m.id).toSet();
    if (_knownIds.isEmpty) {
      _knownIds.addAll(currentIds);
      return;
    }
    final newIds = currentIds.difference(_knownIds);
    if (newIds.isNotEmpty) {
      _animateIds.addAll(newIds);
      _knownIds.addAll(newIds);
    } else {
      _knownIds.addAll(currentIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<ChatRoomBloc, ChatRoomState>(
      listenWhen: (p, c) =>
          p.errorMessage != c.errorMessage ||
          p.isDeleted != c.isDeleted ||
          (c.systemNotice != null && p.systemNotice != c.systemNotice),
      listener: (context, state) {
        if (state.isDeleted) {
          widget.onBack();
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
        if (state.systemNotice != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.systemNotice!)),
          );
        }
      },
      buildWhen: (p, c) =>
          p.replyingTo != c.replyingTo ||
          p.isUploadingImage != c.isUploadingImage ||
          p.pendingImagePath != c.pendingImagePath ||
          p.pendingIsVideo != c.pendingIsVideo ||
          p.pendingShareUrl != c.pendingShareUrl ||
          p.messages != c.messages ||
          p.isConnected != c.isConnected ||
          p.isConnecting != c.isConnecting ||
          p.isLoadingHistory != c.isLoadingHistory ||
          p.isLoadingMore != c.isLoadingMore ||
          p.isSyncing != c.isSyncing ||
          // Admin-only toggle / admin status drive the input lock.
          p.room?.adminOnly != c.room?.adminOnly ||
          p.amIAdmin != c.amIAdmin,
      builder: (context, state) {
        _syncAnimationState(state.messages, state.isLoadingHistory);

        return Column(
          children: [
            _ConnectionBanner(ext: ext, state: state, l10n: l10n),
            if (state.isSyncing)
              LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: ext.accentGold.withValues(alpha: 0.6),
              ),
            if (widget.room.type == RoomType.direct ||
                widget.room.type == RoomType.group)
              _E2EBadge(ext: ext, l10n: l10n),
            Expanded(
              child: _MessageList(
                ext: ext,
                l10n: l10n,
                state: state,
                scrollCtrl: _scrollCtrl,
                knownIds: _knownIds,
                animateIds: _animateIds,
                syncAnimationState: _syncAnimationState,
              ),
            ),
            // Admin-only rooms: non-admins can't send — disable the input and
            // show a lock notice (mirrors the mobile chat room behaviour).
            if (state.room?.adminOnly == true && !state.amIAdmin)
              _AdminOnlyNotice(ext: ext, l10n: l10n)
            else
              ChatInputBar(
                controller: _inputCtrl,
                onSend: _send,
                ext: ext,
                replyingTo: state.replyingTo,
                onClearReply: () => _bloc.add(const ChatRoomReplySet(null)),
                onImagePicked: _onImagePicked,
                pendingImagePath: state.pendingImagePath,
                pendingIsVideo: state.pendingIsVideo,
                pendingShareUrl: state.pendingShareUrl,
                onClearImage: () => _bloc.add(const ChatRoomImageCleared()),
                isUploadingImage: state.isUploadingImage,
              ),
          ],
        );
      },
    );
  }
}

// ── Connection banner ─────────────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.ext,
    required this.state,
    required this.l10n,
  });

  final AppThemeExtension ext;
  final ChatRoomState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (state.isConnected) return const SizedBox.shrink();
    final isConnecting = state.isConnecting;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isConnecting
          ? Colors.orangeAccent.withValues(alpha: 0.12)
          : Colors.redAccent.withValues(alpha: 0.10),
      child: Text(
        isConnecting ? l10n.chatRoomConnecting : l10n.chatRoomDisconnected,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isConnecting ? Colors.orangeAccent : Colors.redAccent,
          fontSize: 11.sp,
        ),
      ),
    );
  }
}

// ── E2E badge ─────────────────────────────────────────────────────────────────

/// Shown in place of the input bar when the room is admin-only and the current
/// user is not an admin — they can read but not send.
class _AdminOnlyNotice extends StatelessWidget {
  const _AdminOnlyNotice({required this.ext, required this.l10n});

  final AppThemeExtension ext;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, size: 14, color: ext.searchHintColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.chatRoomOnlyAdminsCanSend,
              style: TextStyle(color: ext.searchHintColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _E2EBadge extends StatelessWidget {
  const _E2EBadge({required this.ext, required this.l10n});

  final AppThemeExtension ext;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded,
              size: 10, color: ext.searchHintColor.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(
            l10n.chatRoomEndToEndEncrypted,
            style: TextStyle(
              fontSize: 10,
              color: ext.searchHintColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.ext,
    required this.l10n,
    required this.state,
    required this.scrollCtrl,
    required this.knownIds,
    required this.animateIds,
    required this.syncAnimationState,
  });

  final AppThemeExtension ext;
  final AppLocalizations l10n;
  final ChatRoomState state;
  final ScrollController scrollCtrl;
  final Set<String> knownIds;
  final Set<String> animateIds;
  final void Function(List<ChatMessage>, bool) syncAnimationState;

  @override
  Widget build(BuildContext context) {
    syncAnimationState(state.messages, state.isLoadingHistory);

    if (state.isLoadingHistory && state.messages.isEmpty) {
      return Center(child: CircularProgressIndicator(color: ext.accentGold));
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Text(
          l10n.chatRoomNoMessages,
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      );
    }

    return ListView.builder(
      controller: scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.messages.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(
                  color: ext.accentGold, strokeWidth: 2),
            ),
          );
        }
        final msg = state.messages[index];
        final isMe = msg.senderId == state.myUserId;
        final shouldAnimate = animateIds.remove(msg.id);
        final totalOthers = (state.room?.participants ?? [])
            .where((p) => p.userId != msg.senderId)
            .length;
        final bubble = MessageBubble(
          message: msg,
          isMe: isMe,
          readCount: msg.readBy.length,
          totalOthers: totalOthers,
          onLongPress: () =>
              context.read<ChatRoomBloc>().add(ChatRoomReplySet(msg)),
        );
        return shouldAnimate
            ? MessageEntrance(fromRight: isMe, child: bubble)
            : bubble;
      },
    );
  }
}
