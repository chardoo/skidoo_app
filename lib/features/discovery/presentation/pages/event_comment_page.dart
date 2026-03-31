import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_comment_input_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_comment_item.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_image_slider.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Opens a bottom sheet showing an image slider + real-time comments.
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

// ── Bottom sheet ──────────────────────────────────────────────────────────────

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
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

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

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _bloc.add(ChatRoomMessageSent(text));
    _inputCtrl.clear();
  }

  String _senderLabel(ChatMessage msg) {
    if (msg.senderId == _myId) return 'You';
    final role = msg.senderRole;
    if (role.isEmpty) return 'User';
    return role[0].toUpperCase() + role.substring(1);
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final screenH = MediaQuery.sizeOf(context).height;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;
    final pics = widget.event.pictures;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        height: screenH * 0.88,
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ───────────────────────────────────────────────────
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 14.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            // ── Event header ──────────────────────────────────────────────────
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
                      fontSize: 15.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'by ${widget.event.photographerName}',
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
                  ),
                ],
              ),
            ),

            // ── Image slider ──────────────────────────────────────────────────
            if (pics.isNotEmpty) EventImageSlider(pics: pics, ext: ext),

            SizedBox(height: 10.h),
            Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.15)),

            // ── Comments ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(color: ext.accentGold))
                  : _error != null
                      ? _ErrorView(
                          error: _error!,
                          ext: ext,
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
                                      color: ext.accentGold.withValues(alpha: 0.6),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Expanded(
                              child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
                                listener: (context, state) {
                                  if (state.errorMessage != null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(state.errorMessage!),
                                      backgroundColor: Colors.redAccent,
                                      duration: const Duration(seconds: 3),
                                    ));
                                  }
                                },
                                builder: (_, state) {
                                  if (state.isLoadingHistory &&
                                      state.messages.isEmpty) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                          color: ext.accentGold),
                                    );
                                  }
                                  if (state.messages.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 36.sp,
                                            color: ext.searchHintColor,
                                          ),
                                          SizedBox(height: 8.h),
                                          Text(
                                            'No comments yet.\nBe the first!',
                                            style: TextStyle(
                                                color: ext.searchHintColor,
                                                fontSize: 13.sp),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    controller: _scrollCtrl,
                                    reverse: true,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16.w, vertical: 8.h),
                                    itemCount: state.messages.length +
                                        (state.isLoadingMore ? 1 : 0),
                                    itemBuilder: (_, index) {
                                      if (index == state.messages.length) {
                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12.h),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                                color: ext.accentGold,
                                                strokeWidth: 2),
                                          ),
                                        );
                                      }
                                      final msg = state.messages[index];
                                      final isMe = msg.senderId == _myId;
                                      return EventCommentItem(
                                        key: ValueKey(msg.id),
                                        msg: msg,
                                        isMe: isMe,
                                        label: _senderLabel(msg),
                                        timeLabel: _formatTime(msg.createdAt),
                                        ext: ext,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            EventCommentInputBar(
                              controller: _inputCtrl,
                              onSend: _send,
                              ext: ext,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView(
      {required this.error, required this.ext, required this.onRetry});
  final String error;
  final AppThemeExtension ext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 40.sp),
          SizedBox(height: 8.h),
          Text(error,
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              textAlign: TextAlign.center),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: ext.accentGold)),
          ),
        ],
      ),
    );
  }
}
