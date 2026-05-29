import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/comments/comment_input_bar_widget.dart';
import 'package:skidoo_app/core/widgets/emoji_panel.dart';
import 'package:skidoo_app/components/comments/comment_row_data.dart';
import 'package:skidoo_app/components/comments/comment_sheet_shell.dart';
import 'package:skidoo_app/components/comments/threaded_comment_widget.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/time_formatter.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart' show GetEventRoomUseCase;
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Opens a bottom sheet showing an image slider + real-time event comments.
class EventCommentPage {
  static void show(BuildContext context, EventDiscovery event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => BlocProvider(
        create: (_) => sl<ChatRoomBloc>(),
        child: _EventCommentSheet(event: event),
      ),
    );
  }
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _EventCommentSheet extends StatefulWidget {
  const _EventCommentSheet({required this.event});
  final EventDiscovery event;

  @override
  State<_EventCommentSheet> createState() => _EventCommentSheetState();
}

class _EventCommentSheetState extends State<_EventCommentSheet> {
  bool _loading = true;
  String? _error;
  String _myId = '';

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

  // Local expand state for threaded comments (ChatRoomBloc doesn't track this).
  final _expandedIds = <String>{};

  ChatMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatRoomBloc>();
    _scrollCtrl.addListener(_onScroll);
    _loadRoom();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await sl<AuthService>().getUserId();
    if (mounted) setState(() => _myId = id);
  }

  Future<void> _loadRoom() async {
    try {
      final room = await sl<GetEventRoomUseCase>().call(widget.event.id);
      if (mounted) {
        setState(() => _loading = false);
        _bloc.add(ChatRoomJoined(room.id, room: room));
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  void dispose() {
    _bloc.add(const ChatRoomLeft());
    _inputCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _bloc.add(const ChatRoomLoadMoreRequested());
    }
  }

  void _startReply(ChatMessage msg) {
    setState(() => _replyingTo = msg);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _bloc.add(ChatRoomMessageSent(text, replyToId: _replyingTo?.id));
    _inputCtrl.clear();
    if (_replyingTo != null) setState(() => _replyingTo = null);
  }

  String _label(ChatMessage msg) {
    if (msg.senderId == _myId) return 'You';
    if (msg.senderName.isNotEmpty) return msg.senderName;
    final r = msg.senderRole;
    return r.isEmpty ? 'User' : r[0].toUpperCase() + r.substring(1);
  }

  void _openProfile(ChatMessage msg) {
    final name = msg.senderName.isNotEmpty ? msg.senderName : 'Creator';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotographerProfilePage(
          photographer: PhotographerModel(msg.senderId, '', name, ''),
        ),
      ),
    );
  }

  // ── Thread building ──────────────────────────────────────────────────────────

  ({List<ChatMessage> topLevel, Map<String, List<ChatMessage>> repliesMap})
      _buildThreads(List<ChatMessage> messages) {
    final allIds = {for (final m in messages) m.id};
    bool isTop(ChatMessage m) =>
        m.replyToId == null || !allIds.contains(m.replyToId);

    final topLevelIds = {
      for (final m in messages)
        if (isTop(m)) m.id,
    };

    String rootOf(ChatMessage m) {
      var pid = m.replyToId!;
      while (!topLevelIds.contains(pid)) {
        final parent = messages.cast<ChatMessage?>().firstWhere(
            (x) => x?.id == pid,
            orElse: () => null);
        if (parent == null || parent.replyToId == null) break;
        pid = parent.replyToId!;
      }
      return pid;
    }

    final topLevel = messages.where(isTop).toList();
    final repliesMap = <String, List<ChatMessage>>{};
    for (final m in messages) {
      if (!isTop(m)) {
        repliesMap.putIfAbsent(rootOf(m), () => []).add(m);
      }
    }
    return (topLevel: topLevel, repliesMap: repliesMap);
  }

  CommentRowData _toRowData(
    ChatMessage msg, {
    List<ChatMessage>? replies,
    required void Function(ChatMessage) onReply,
  }) {
    return CommentRowData(
      id: msg.id,
      label: _label(msg),
      content: msg.content,
      timeLabel: TimeFormatter.relative(msg.createdAt),
      isMe: msg.senderId == _myId,
      isPending: msg.isLocal,
      replyCount: replies?.length ?? 0,
      onReply: () => onReply(msg),
      onUserTap: (msg.senderId == _myId ||
              msg.senderRole != ChatConfig.rolePhotographer)
          ? null
          : () => _openProfile(msg),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return CommentSheetShell(
      title: widget.event.eventName,
      subtitle: 'by ${widget.event.photographerName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Comments ────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? AppErrorView(
                        message: _error!,
                        onRetry: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadRoom();
                        },
                      )
                    : Column(
                        children: [
                          // WebSocket syncing bar
                          BlocBuilder<ChatRoomBloc, ChatRoomState>(
                            buildWhen: (p, c) =>
                                p.isSyncing != c.isSyncing,
                            builder: (_, s) => s.isSyncing
                                ? LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    color: ext.accentGold
                                        .withValues(alpha: 0.6),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          Expanded(
                            child: BlocConsumer<ChatRoomBloc,
                                ChatRoomState>(
                              listenWhen: (prev, curr) =>
                                  curr.errorMessage != null &&
                                  curr.errorMessage != prev.errorMessage,
                              listener: (_, state) {
                                AppSnackBar.error(
                                    context, state.errorMessage!);
                              },
                              builder: (_, state) {
                                if (state.isLoadingHistory &&
                                    state.messages.isEmpty) {
                                  return const AppLoadingIndicator();
                                }
                                if (state.messages.isEmpty) {
                                  return CommentEmptyState(ext: ext);
                                }

                                final threaded =
                                    _buildThreads(state.messages);

                                return ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 8.h),
                                  itemCount: threaded.topLevel.length +
                                      (state.isLoadingMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i ==
                                        threaded.topLevel.length) {
                                      return Padding(
                                        padding:
                                            EdgeInsets.symmetric(
                                                vertical: 12.h),
                                        child: Center(
                                          child:
                                              CircularProgressIndicator(
                                            color: ext.accentGold,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    final msg =
                                        threaded.topLevel[i];
                                    final replies =
                                        threaded.repliesMap[msg.id] ??
                                            [];

                                    return ThreadedCommentWidget(
                                      key: ValueKey(msg.id),
                                      comment: _toRowData(msg,
                                          replies: replies,
                                          onReply: _startReply),
                                      replies: replies
                                          .map((r) => _toRowData(r,
                                              onReply: _startReply))
                                          .toList(),
                                      ext: ext,
                                      isExpanded: _expandedIds
                                          .contains(msg.id),
                                      onToggleReplies: () =>
                                          setState(() {
                                        if (_expandedIds
                                            .contains(msg.id)) {
                                          _expandedIds.remove(msg.id);
                                        } else {
                                          _expandedIds.add(msg.id);
                                        }
                                      }),
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          CommentInputBarWidget(
                            controller: _inputCtrl,
                            focusNode: _focusNode,
                            onSend: _send,
                            ext: ext,
                            replyingToName: _replyingTo != null
                                ? _label(_replyingTo!)
                                : null,
                            onCancelReply: _cancelReply,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Inline comment panel (web) ────────────────────────────────────────────────

/// Embeds the event comment UI directly in the card's side panel on web,
/// instead of opening a modal bottom sheet. Manages its own [ChatRoomBloc].
class EventCommentInlinePanel extends StatelessWidget {
  const EventCommentInlinePanel({
    super.key,
    required this.event,
    required this.onClose,
    this.isExternalPanel = false,
  });

  final EventDiscovery event;
  final VoidCallback onClose;
  /// True when rendered outside the 480px card column (wide desktop layout).
  /// Removes the left border and uses slightly looser padding.
  final bool isExternalPanel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      child: _InlineCommentContent(
          event: event, onClose: onClose, isExternalPanel: isExternalPanel),
    );
  }
}

class _InlineCommentContent extends StatefulWidget {
  const _InlineCommentContent({
    required this.event,
    required this.onClose,
    this.isExternalPanel = false,
  });
  final EventDiscovery event;
  final VoidCallback onClose;
  final bool isExternalPanel;

  @override
  State<_InlineCommentContent> createState() =>
      _InlineCommentContentState();
}

class _InlineCommentContentState extends State<_InlineCommentContent> {
  bool _loading = true;
  String? _error;
  String _myId = '';
  ChatMessage? _replyingTo;

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;
  final _expandedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatRoomBloc>();
    _scrollCtrl.addListener(_onScroll);
    _loadRoom();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await sl<AuthService>().getUserId();
    if (mounted) setState(() => _myId = id);
  }

  Future<void> _loadRoom() async {
    try {
      final room = await sl<GetEventRoomUseCase>().call(widget.event.id);
      if (mounted) {
        setState(() => _loading = false);
        _bloc.add(ChatRoomJoined(room.id, room: room));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _bloc.add(const ChatRoomLeft());
    _inputCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _bloc.add(const ChatRoomLoadMoreRequested());
    }
  }

  void _startReply(ChatMessage msg) {
    setState(() => _replyingTo = msg);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _bloc.add(ChatRoomMessageSent(text, replyToId: _replyingTo?.id));
    _inputCtrl.clear();
    if (_replyingTo != null) setState(() => _replyingTo = null);
  }

  String _label(ChatMessage msg) {
    if (msg.senderId == _myId) return 'You';
    if (msg.senderName.isNotEmpty) return msg.senderName;
    final r = msg.senderRole;
    return r.isEmpty ? 'User' : r[0].toUpperCase() + r.substring(1);
  }

  void _openProfile(ChatMessage msg) {
    final name = msg.senderName.isNotEmpty ? msg.senderName : 'Creator';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotographerProfilePage(
          photographer: PhotographerModel(msg.senderId, '', name, ''),
        ),
      ),
    );
  }

  ({List<ChatMessage> topLevel, Map<String, List<ChatMessage>> repliesMap})
      _buildThreads(List<ChatMessage> messages) {
    final allIds = {for (final m in messages) m.id};
    bool isTop(ChatMessage m) =>
        m.replyToId == null || !allIds.contains(m.replyToId);
    final topLevelIds = {
      for (final m in messages)
        if (isTop(m)) m.id,
    };
    String rootOf(ChatMessage m) {
      var pid = m.replyToId!;
      while (!topLevelIds.contains(pid)) {
        final parent = messages
            .cast<ChatMessage?>()
            .firstWhere((x) => x?.id == pid, orElse: () => null);
        if (parent == null || parent.replyToId == null) break;
        pid = parent.replyToId!;
      }
      return pid;
    }

    final topLevel = messages.where(isTop).toList();
    final repliesMap = <String, List<ChatMessage>>{};
    for (final m in messages) {
      if (!isTop(m)) {
        repliesMap.putIfAbsent(rootOf(m), () => []).add(m);
      }
    }
    return (topLevel: topLevel, repliesMap: repliesMap);
  }

  CommentRowData _toRowData(ChatMessage msg,
      {List<ChatMessage>? replies,
      required void Function(ChatMessage) onReply}) {
    return CommentRowData(
      id: msg.id,
      label: _label(msg),
      content: msg.content,
      timeLabel: TimeFormatter.relative(msg.createdAt),
      isMe: msg.senderId == _myId,
      isPending: msg.isLocal,
      replyCount: replies?.length ?? 0,
      onReply: () => onReply(msg),
      onUserTap: (msg.senderId == _myId ||
              msg.senderRole != ChatConfig.rolePhotographer)
          ? null
          : () => _openProfile(msg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.10);

    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          left: BorderSide(color: dividerColor, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 28,
            offset: const Offset(-6, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          _CommentPanelHeader(
            ext: ext,
            onClose: widget.onClose,
            bloc: _bloc,
          ),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? AppErrorView(
                        message: _error!,
                        onRetry: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadRoom();
                        },
                      )
                    : Column(
                        children: [
                          BlocBuilder<ChatRoomBloc, ChatRoomState>(
                            buildWhen: (p, c) =>
                                p.isSyncing != c.isSyncing,
                            builder: (_, s) => s.isSyncing
                                ? LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    color: ext.accentGold
                                        .withValues(alpha: 0.6),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          Expanded(
                            child: Stack(
                              children: [
                                BlocConsumer<ChatRoomBloc, ChatRoomState>(
                                  listenWhen: (prev, curr) =>
                                      curr.errorMessage != null &&
                                      curr.errorMessage !=
                                          prev.errorMessage,
                                  listener: (_, state) {
                                    AppSnackBar.error(
                                        context, state.errorMessage!);
                                  },
                                  builder: (_, state) {
                                    if (state.isLoadingHistory &&
                                        state.messages.isEmpty) {
                                      return const AppLoadingIndicator();
                                    }
                                    if (state.messages.isEmpty) {
                                      return _CommentEmptyView(ext: ext);
                                    }
                                    final threaded =
                                        _buildThreads(state.messages);
                                    return ListView.builder(
                                      controller: _scrollCtrl,
                                      padding: EdgeInsets.fromLTRB(
                                          10.w, 12.h, 10.w, 12.h),
                                      itemCount:
                                          threaded.topLevel.length +
                                              (state.isLoadingMore
                                                  ? 1
                                                  : 0),
                                      itemBuilder: (_, i) {
                                        if (i ==
                                            threaded.topLevel.length) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10.h),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(
                                                color: ext.accentGold,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        final msg =
                                            threaded.topLevel[i];
                                        final replies = threaded
                                                .repliesMap[msg.id] ??
                                            [];
                                        return _CommentCard(
                                          ext: ext,
                                          isDark: isDark,
                                          child: ThreadedCommentWidget(
                                            key: ValueKey(msg.id),
                                            comment: _toRowData(msg,
                                                replies: replies,
                                                onReply: _startReply),
                                            replies: replies
                                                .map((r) => _toRowData(
                                                    r,
                                                    onReply: _startReply))
                                                .toList(),
                                            ext: ext,
                                            isExpanded: _expandedIds
                                                .contains(msg.id),
                                            onToggleReplies: () =>
                                                setState(() {
                                              if (_expandedIds
                                                  .contains(msg.id)) {
                                                _expandedIds
                                                    .remove(msg.id);
                                              } else {
                                                _expandedIds.add(msg.id);
                                              }
                                            }),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),

                                // Soft fade at the bottom of the list
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 28,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            ext.cardSurface
                                                .withValues(alpha: 0),
                                            ext.cardSurface,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Web-native input bar with emoji
                          _WebCommentInput(
                            controller: _inputCtrl,
                            focusNode: _focusNode,
                            onSend: _send,
                            ext: ext,
                            replyingToName: _replyingTo != null
                                ? _label(_replyingTo!)
                                : null,
                            onCancelReply: _cancelReply,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Comment card bubble — wraps each thread in a visible elevated card ────────

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    required this.child,
    required this.ext,
    required this.isDark,
  });
  final Widget child;
  final AppThemeExtension ext;
  final bool isDark;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.fromLTRB(12.w, 11.h, 12.w, 9.h),
        decoration: BoxDecoration(
          // Use the dedicated field-fill colour — clearly distinct from
          // cardSurface (the panel background) on both dark and light themes.
          color: _hovered
              ? ext.searchHintColor.withValues(alpha: 0.10)
              : ext.searchFieldFill,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: ext.glassBorder.withValues(alpha: _hovered ? 0.22 : 0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.18 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Web-native comment input bar — emoji + text field + send ─────────────────

class _WebCommentInput extends StatefulWidget {
  const _WebCommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.ext,
    this.replyingToName,
    this.onCancelReply,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final AppThemeExtension ext;
  final String? replyingToName;
  final VoidCallback? onCancelReply;

  @override
  State<_WebCommentInput> createState() => _WebCommentInputState();
}

class _WebCommentInputState extends State<_WebCommentInput> {
  bool _emojiOpen = false;

  void _toggleEmoji() {
    setState(() => _emojiOpen = !_emojiOpen);
    if (_emojiOpen) {
      widget.focusNode.unfocus();
    } else {
      widget.focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final dividerColor =
        ext.glassBorder.withValues(alpha: 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji panel — above the input row, always fully visible
        if (_emojiOpen)
          EmojiPickerPanel(
            ext: ext,
            onEmojiSelected: (emoji) =>
                insertEmoji(widget.controller, emoji),
          ),

        // Reply strip
        if (widget.replyingToName != null)
          Container(
            padding: EdgeInsets.fromLTRB(14.w, 7.h, 8.w, 7.h),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.08),
              border: Border(
                top: BorderSide(color: dividerColor),
                left: BorderSide(color: ext.accentGold, width: 3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply_rounded,
                    size: 13.sp, color: ext.accentGold),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Replying to ${widget.replyingToName}',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCancelReply,
                  child: Icon(Icons.close_rounded,
                      size: 14.sp, color: ext.searchHintColor),
                ),
              ],
            ),
          ),

        // Input row
        Container(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 12.h),
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            border: Border(
              top: BorderSide(color: dividerColor),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Emoji toggle button — circle background like WebActionBtn
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggleEmoji,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 34.w,
                    height: 34.w,
                    decoration: BoxDecoration(
                      color: _emojiOpen
                          ? ext.accentGold.withValues(alpha: 0.18)
                          : ext.glassFill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _emojiOpen
                            ? ext.accentGold.withValues(alpha: 0.50)
                            : ext.glassBorder.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _emojiOpen ? '⌨️' : '😊',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),

              // Text field
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter,
                        shift: false): widget.onSend,
                    const SingleActivator(
                        LogicalKeyboardKey.numpadEnter,
                        shift: false): widget.onSend,
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onTap: () {
                      if (_emojiOpen) setState(() => _emojiOpen = false);
                    },
                    style: TextStyle(
                        color: ext.greetingColor, fontSize: 13.sp),
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.replyingToName != null
                          ? 'Write a reply…'
                          : 'Add a comment…',
                      hintStyle: TextStyle(
                          color: ext.searchHintColor, fontSize: 13.sp),
                      filled: true,
                      fillColor: ext.cardSurface,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 9.h),
                      isDense: true,
                    ),
                    onSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              SizedBox(width: 8.w),

              // Send button
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onSend,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ext.accentGold, const Color(0xFFFF6B35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: ext.accentGold.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child:
                        Icon(Icons.send_rounded, color: Colors.white, size: 16.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Redesigned inline panel header ───────────────────────────────────────────

class _CommentPanelHeader extends StatelessWidget {
  const _CommentPanelHeader({
    required this.ext,
    required this.onClose,
    required this.bloc,
  });

  final AppThemeExtension ext;
  final VoidCallback onClose;
  final ChatRoomBloc bloc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        border: Border(
          bottom: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 10.w, 12.h),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ext.accentGold.withValues(alpha: 0.20),
                    ext.accentGold.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ext.accentGold.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.mode_comment_rounded,
                  color: ext.accentGold, size: 16.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.sp,
                      letterSpacing: -0.3,
                    ),
                  ),
                  BlocBuilder<ChatRoomBloc, ChatRoomState>(
                    bloc: bloc,
                    buildWhen: (p, c) =>
                        p.messages.length != c.messages.length,
                    builder: (_, state) {
                      final count = state.messages.length;
                      if (count == 0) return const SizedBox.shrink();
                      return Text(
                        '$count ${count == 1 ? 'comment' : 'comments'}',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    color: ext.glassFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: ext.glassBorder, width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.close_rounded,
                      color: ext.searchHintColor, size: 15.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state for inline panel ─────────────────────────────────────────────

class _CommentEmptyView extends StatelessWidget {
  const _CommentEmptyView({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ext.accentGold.withValues(alpha: 0.15),
                    ext.accentGold.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ext.accentGold.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text('💬', style: TextStyle(fontSize: 28.sp)),
            ),
            SizedBox(height: 16.h),
            Text(
              'No comments yet',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Be the first to share your thoughts!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
