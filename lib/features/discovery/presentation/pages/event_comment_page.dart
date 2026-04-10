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
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
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
        _bloc.add(ChatRoomJoined(room.id));
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

  Future<void> _openDm(ChatMessage msg) async {
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: msg.senderId,
        recipientRole: msg.senderRole,
        localDisplayName:
            msg.senderName.isNotEmpty ? msg.senderName : msg.senderRole,
      );
      if (!mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.redAccent));
    }
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
      onUserTap: msg.senderId == _myId ? null : () => _openDm(msg),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return CommentSheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event header ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.event.eventName,
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'by ${widget.event.photographerName}',
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 11.sp),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: ext.searchHintColor.withValues(alpha: 0.15)),

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

