import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/comments/comment_input_bar_widget.dart';
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
    final borderColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.10);

    // Frosted glass panel for external (desktop) placement; solid card for
    // the narrow inside-card variant.
    Widget panel = Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: widget.isExternalPanel ? 0.55 : 1.0)
            : Colors.white.withValues(alpha: widget.isExternalPanel ? 0.72 : 1.0),
        border: widget.isExternalPanel
            ? null
            : Border(left: BorderSide(color: borderColor, width: 0.5)),
        boxShadow: widget.isExternalPanel
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
                  blurRadius: 20,
                  offset: const Offset(-3, 0),
                ),
              ]
            : null,
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
                          // Syncing bar
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

                          // Comments list with bottom-fade overlay
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
                                          12.w, 12.h, 12.w, 8.h),
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
                                        // Each top-level thread sits in a
                                        // subtle card bubble for visual depth.
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

                                // Scroll-fade: softens the hard clip at the
                                // list's bottom edge above the input bar.
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 32,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                .withValues(alpha: 0),
                                            (isDark
                                                    ? Colors.black
                                                    : Colors.white)
                                                .withValues(
                                                    alpha: widget
                                                            .isExternalPanel
                                                        ? 0.55
                                                        : 1.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Input bar — includes emoji button
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

    // Wrap external-panel variant in a backdrop blur so the background
    // (home feed behind the panel) gets a frosted-glass treatment.
    if (widget.isExternalPanel) {
      panel = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: panel,
        ),
      );
    }

    return panel;
  }
}

// ── Comment card bubble — wraps each thread on web desktop ───────────────────

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
    final isDark = widget.isDark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.03))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: _hovered ? 0.10 : 0.06),
            width: 0.8,
          ),
        ),
        child: widget.child,
      ),
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
