import 'package:flutter/material.dart';
import 'package:jperg_app/core/celebration/comment_milestone_watcher.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/comments/comment_input_bar_widget.dart';
import 'package:jperg_app/core/widgets/emoji_panel.dart';
import 'package:jperg_app/components/comments/comment_like_state.dart';
import 'package:jperg_app/components/comments/comment_row_data.dart';
import 'package:jperg_app/components/comments/comment_sheet_shell.dart';
import 'package:jperg_app/components/comments/threaded_comment_widget.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/time_formatter.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart'
    show GetEventRoomUseCase;
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// Opens a bottom sheet showing an image slider + real-time event comments.
class EventCommentPage {
  static void show(BuildContext context, EventDiscovery event,
      {VoidCallback? onCommentSent}) {
    showCommentSheet(
      context,
      builder: (ctx) => BlocProvider(
        create: (_) => sl<ChatRoomBloc>(),
        child: _EventCommentSheet(event: event, onCommentSent: onCommentSent),
      ),
    );
  }
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _EventCommentSheet extends StatefulWidget {
  const _EventCommentSheet({required this.event, this.onCommentSent});
  final EventDiscovery event;
  final VoidCallback? onCommentSent;

  @override
  State<_EventCommentSheet> createState() => _EventCommentSheetState();
}

class _EventCommentSheetState extends State<_EventCommentSheet>
    with CommentLikeState<_EventCommentSheet> {
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
    widget.onCommentSent?.call();
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
    openPhotographerProfile(
      context,
      photographerId: msg.senderId,
      photographerName: name,
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
      likeCount: likeFor(msg).likes,
      viewerLiked: likeFor(msg).liked,
      onLike: likeHandler(msg),
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
                            buildWhen: (p, c) => p.isSyncing != c.isSyncing,
                            builder: (_, s) => s.isSyncing
                                ? LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    color:
                                        ext.accentGold.withValues(alpha: 0.6),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          Expanded(
                            child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
                              listenWhen: (prev, curr) =>
                                  curr.errorMessage != null &&
                                  curr.errorMessage != prev.errorMessage,
                              listener: (_, state) {
                                AppSnackBar.error(context, state.errorMessage!);
                              },
                              builder: (_, state) {
                                if (state.isLoadingHistory &&
                                    state.messages.isEmpty) {
                                  return const AppLoadingIndicator();
                                }
                                if (state.messages.isEmpty) {
                                  return CommentEmptyState(ext: ext);
                                }

                                final threaded = _buildThreads(state.messages);

                                return ListView.builder(
                                  controller: _scrollCtrl,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg.w,
                                      vertical: AppSpacing.sm.h),
                                  itemCount: threaded.topLevel.length +
                                      (state.isLoadingMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == threaded.topLevel.length) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: AppSpacing.md.h),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: ext.accentGold,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    final msg = threaded.topLevel[i];
                                    final replies =
                                        threaded.repliesMap[msg.id] ?? [];

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
                                      isExpanded: _expandedIds.contains(msg.id),
                                      onToggleReplies: () => setState(() {
                                        if (_expandedIds.contains(msg.id)) {
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
    this.onCommentSent,
  });

  final EventDiscovery event;
  final VoidCallback onClose;

  /// True when rendered outside the 480px card column (wide desktop layout).
  /// Removes the left border and uses slightly looser padding.
  final bool isExternalPanel;
  final VoidCallback? onCommentSent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      // Comment UI by any reading — same bloc, same input bar, same thread —
      // so it gets the same celebration. It had none, because the watcher used
      // to live inside [CommentSheetShell] and this panel is not a sheet.
      child: CommentMilestoneWatcher(
        child: _InlineCommentContent(
            event: event,
            onClose: onClose,
            isExternalPanel: isExternalPanel,
            onCommentSent: onCommentSent),
      ),
    );
  }
}

class _InlineCommentContent extends StatefulWidget {
  const _InlineCommentContent({
    required this.event,
    required this.onClose,
    this.isExternalPanel = false,
    this.onCommentSent,
  });
  final EventDiscovery event;
  final VoidCallback onClose;
  final bool isExternalPanel;
  final VoidCallback? onCommentSent;

  @override
  State<_InlineCommentContent> createState() => _InlineCommentContentState();
}

class _InlineCommentContentState extends State<_InlineCommentContent>
    with CommentLikeState<_InlineCommentContent> {
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
    widget.onCommentSent?.call();
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
    openPhotographerProfile(
      context,
      photographerId: msg.senderId,
      photographerName: name,
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
      likeCount: likeFor(msg).likes,
      viewerLiked: likeFor(msg).liked,
      onLike: likeHandler(msg),
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
    final dividerColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10);

    return Container(
      decoration: widget.isExternalPanel
          // Desktop: floating rounded card flush to the right of the feed.
          ? BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            )
          // Inline (mobile web): single left divider, no rounding.
          : BoxDecoration(
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
      clipBehavior: widget.isExternalPanel ? Clip.antiAlias : Clip.none,
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
                            buildWhen: (p, c) => p.isSyncing != c.isSyncing,
                            builder: (_, s) => s.isSyncing
                                ? LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    color:
                                        ext.accentGold.withValues(alpha: 0.6),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          Expanded(
                            child: Stack(
                              children: [
                                BlocConsumer<ChatRoomBloc, ChatRoomState>(
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
                                      return _CommentEmptyView(ext: ext);
                                    }
                                    final threaded =
                                        _buildThreads(state.messages);
                                    return ListView.builder(
                                      controller: _scrollCtrl,
                                      padding: EdgeInsets.fromLTRB(
                                          10.w, 12.h, 10.w, 12.h),
                                      itemCount: threaded.topLevel.length +
                                          (state.isLoadingMore ? 1 : 0),
                                      itemBuilder: (_, i) {
                                        if (i == threaded.topLevel.length) {
                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10.h),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: ext.accentGold,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          );
                                        }
                                        final msg = threaded.topLevel[i];
                                        final replies =
                                            threaded.repliesMap[msg.id] ?? [];
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
                                          isExpanded:
                                              _expandedIds.contains(msg.id),
                                          onToggleReplies: () => setState(() {
                                            if (_expandedIds.contains(msg.id)) {
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
    final dividerColor = ext.glassBorder.withValues(alpha: 0.15);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emoji panel — above the input row, always fully visible
        if (_emojiOpen)
          EmojiPickerPanel(
            ext: ext,
            onEmojiSelected: (emoji) => insertEmoji(widget.controller, emoji),
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
                Icon(Icons.reply_rounded, size: 13.sp, color: ext.accentGold),
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
                Semantics(
                  button: true,
                  label: 'Cancel reply',
                  child: GestureDetector(
                    onTap: widget.onCancelReply,
                    child: Icon(Icons.close_rounded,
                        size: 14.sp, color: ext.searchHintColor),
                  ),
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
              Semantics(
                button: true,
                label: 'Emoji',
                child: MouseRegion(
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
              ),
              SizedBox(width: AppSpacing.sm.w),

              // Text field
              Expanded(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter,
                        shift: false): widget.onSend,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter,
                        shift: false): widget.onSend,
                  },
                  child: AppTextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onTap: () {
                      if (_emojiOpen) setState(() => _emojiOpen = false);
                    },
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    dense: true,
                    borderRadius: 20.r,
                    hint: widget.replyingToName != null
                        ? 'Write a reply…'
                        : 'Add a comment…',
                    onFieldSubmitted: (_) => widget.onSend(),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),

              // Send button
              Semantics(
                button: true,
                label: 'Send comment',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onSend,
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ext.accentGold, ext.accentGoldDark],
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
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 16.sp),
                    ),
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
        padding: EdgeInsets.fromLTRB(18.w, 14.h, 10.w, 14.h),
        child: Row(
          children: [
            // ── Title + inline count (YouTube: "Comments  15") ──────────────
            Text(
              'Comments',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                letterSpacing: -0.2,
              ),
            ),
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              bloc: bloc,
              buildWhen: (p, c) => p.messages.length != c.messages.length,
              builder: (_, state) {
                final count = state.messages.length;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm.w),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: 'Close comments',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 34.w,
                    height: 34.w,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(Icons.close_rounded,
                        color: ext.greetingColor, size: 22.sp),
                  ),
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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
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
            SizedBox(height: AppSpacing.lg.h),
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
