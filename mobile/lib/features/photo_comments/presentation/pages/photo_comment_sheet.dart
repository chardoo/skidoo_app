import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/comments/comment_input_bar_widget.dart';
import 'package:skidoo_app/components/comments/comment_row_data.dart';
import 'package:skidoo_app/components/comments/comment_sheet_shell.dart';
import 'package:skidoo_app/components/comments/threaded_comment_widget.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/time_formatter.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart' show GetPhotoRoomUseCase;
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Bottom sheet showing real-time comments for a photo, backed by a photo room WebSocket.
class PhotoCommentSheet {
  static void show(
    BuildContext context, {
    required String pictureId,
    required String imageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => BlocProvider(
        create: (_) => sl<ChatRoomBloc>(),
        child: _PhotoCommentSheetContent(pictureId: pictureId),
      ),
    );
  }
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _PhotoCommentSheetContent extends StatefulWidget {
  const _PhotoCommentSheetContent({required this.pictureId});
  final String pictureId;

  @override
  State<_PhotoCommentSheetContent> createState() =>
      _PhotoCommentSheetContentState();
}

class _PhotoCommentSheetContentState
    extends State<_PhotoCommentSheetContent> {
  bool _loading = true;
  String? _error;
  String _myId = '';

  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

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
    if (widget.pictureId.isEmpty) {
      if (mounted) setState(() { _error = 'Picture ID is missing.'; _loading = false; });
      return;
    }
    debugPrint('[PhotoComment] _loadRoom pictureId=${widget.pictureId}');
    try {
      final room = await sl<GetPhotoRoomUseCase>().call(widget.pictureId);
      debugPrint('[PhotoComment] got room id=${room.id}');
      if (mounted) {
        setState(() => _loading = false);
        _bloc.add(ChatRoomJoined(room.id));
      }
    } catch (e) {
      debugPrint('[PhotoComment] _loadRoom error: $e');
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

  // ── Thread building (same as EventCommentPage) ────────────────────────────

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

  CommentRowData _toRowData(ChatMessage msg, {List<ChatMessage>? replies}) {
    return CommentRowData(
      id: msg.id,
      label: _label(msg),
      content: msg.content,
      timeLabel: TimeFormatter.relative(msg.createdAt),
      isMe: false,
      isPending: msg.isLocal,
      replyCount: replies?.length ?? 0,
      onReply: () => _startReply(msg),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return CommentSheetShell(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Expanded(
            child: _loading
                ? const AppLoadingIndicator()
                : _error != null
                    ? AppErrorView(
                        message: _error!,
                        onRetry: () {
                          setState(() { _loading = true; _error = null; });
                          _loadRoom();
                        },
                      )
                    : Column(
                        children: [
                          // Live syncing bar
                          BlocBuilder<ChatRoomBloc, ChatRoomState>(
                            buildWhen: (p, c) => p.isSyncing != c.isSyncing,
                            builder: (_, s) => s.isSyncing
                                ? LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    color: ext.accentGold.withValues(alpha: 0.6),
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
                                      horizontal: 16.w, vertical: 8.h),
                                  itemCount: threaded.topLevel.length +
                                      (state.isLoadingMore ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == threaded.topLevel.length) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12.h),
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
                                      comment: _toRowData(msg, replies: replies),
                                      replies: replies
                                          .map((r) => _toRowData(r))
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
