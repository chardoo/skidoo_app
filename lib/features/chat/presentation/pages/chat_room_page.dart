import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_entrance.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/services/notification_prefs_service.dart';

/// Displays the messages for [room].
/// Use the [ChatRoomPage.global] constructor to join the global chat room.
class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key, required this.room}) : _globalMode = false;

  const ChatRoomPage.global({super.key})
      : room = null,
        _globalMode = true;

  final ChatRoom? room;
  final bool _globalMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      child: _globalMode
          ? const _GlobalRoomInitializer()
          : _ChatRoomView(room: room!),
    );
  }
}

// ── Global room initializer ───────────────────────────────────────────────────

class _GlobalRoomInitializer extends StatefulWidget {
  const _GlobalRoomInitializer();

  @override
  State<_GlobalRoomInitializer> createState() => _GlobalRoomInitializerState();
}

class _GlobalRoomInitializerState extends State<_GlobalRoomInitializer> {
  bool _loading = true;
  ChatRoom? _room;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final room = await sl<GetGlobalRoomUseCase>().call();
      if (mounted) setState(() { _room = room; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    if (_loading) {
      return Scaffold(
        backgroundColor: ext.homeBackground,
        body: Center(child: CircularProgressIndicator(color: ext.accentGold)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: ext.homeBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 48.sp),
              SizedBox(height: 8.h),
              Text(_error!,
                  style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                  textAlign: TextAlign.center),
              TextButton(
                onPressed: () {
                  setState(() { _loading = true; _error = null; });
                  _load();
                },
                child: Text('Retry', style: TextStyle(color: ext.accentGold)),
              ),
            ],
          ),
        ),
      );
    }
    return _ChatRoomView(room: _room!);
  }
}

// ── Main room view ────────────────────────────────────────────────────────────

class _ChatRoomView extends StatefulWidget {
  const _ChatRoomView({required this.room});
  final ChatRoom room;

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _myId = '';
  late final ChatRoomBloc _bloc;

  /// IDs of messages already shown — used to detect genuinely new arrivals.
  final Set<String> _knownIds = {};

  /// IDs currently playing their entrance animation.
  final Set<String> _animateIds = {};

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatRoomBloc>();
    _bloc.add(ChatRoomJoined(widget.room.id));
    _scrollCtrl.addListener(_onScroll);
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    final id = await sl<AuthService>().getUserId();
    if (mounted) setState(() => _myId = id);
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
    if (text.isEmpty) return;
    _bloc.add(ChatRoomMessageSent(text));
    _inputCtrl.clear();
  }

  void _onUserTap(BuildContext context, ChatMessage msg) {
    if (msg.senderId == _myId) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserOptionsSheet(
        senderId: msg.senderId,
        senderRole: msg.senderRole,
        onDirectChat: () => _openDirectChat(context, msg),
      ),
    );
  }

  Future<void> _openDirectChat(BuildContext context, ChatMessage msg) async {
    Navigator.of(context).pop(); // close sheet

    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: msg.senderId,
        recipientRole: msg.senderRole,
        localDisplayName: msg.senderRole,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Updates [_knownIds] and [_animateIds] from inside the BlocConsumer builder
  /// so no extra [setState] is needed — one rebuild per state change instead of two.
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: ext.greetingColor, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.room.displayName,
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              buildWhen: (p, c) =>
                  p.isConnected != c.isConnected ||
                  p.isConnecting != c.isConnecting,
              builder: (_, state) {
                final String label;
                final Color color;
                if (state.isConnected) {
                  label = 'Connected';
                  color = Colors.greenAccent;
                } else if (state.isConnecting) {
                  label = 'Connecting…';
                  color = Colors.orangeAccent;
                } else {
                  label = 'Disconnected';
                  color = Colors.redAccent;
                }
                return Text(
                  label,
                  style: TextStyle(color: color, fontSize: 10.sp),
                );
              },
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
        children: [
          BlocBuilder<ChatRoomBloc, ChatRoomState>(
            buildWhen: (p, c) => p.isSyncing != c.isSyncing,
            builder: (_, state) => state.isSyncing
                ? LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: ext.accentGold.withValues(alpha: 0.6),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
              listenWhen: (p, c) =>
                  p.errorMessage != c.errorMessage ||
                  p.messages != c.messages,
              listener: (context, state) {
                if (state.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.errorMessage!),
                      backgroundColor: Colors.redAccent,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                // Haptic for new messages — check before builder updates _knownIds.
                if (!state.isLoadingHistory && _knownIds.isNotEmpty) {
                  final newIds = state.messages
                      .map((m) => m.id)
                      .toSet()
                      .difference(_knownIds);
                  if (newIds.isNotEmpty &&
                      !sl<NotificationPrefsService>().isMuted) {
                    HapticFeedback.lightImpact();
                  }
                }
              },
              buildWhen: (p, c) =>
                  p.messages != c.messages ||
                  p.isLoadingHistory != c.isLoadingHistory ||
                  p.isLoadingMore != c.isLoadingMore,
              builder: (context, state) {
                // Sync animation state inline — no setState, no extra rebuild.
                _syncAnimationState(state.messages, state.isLoadingHistory);
                if (state.isLoadingHistory && state.messages.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: ext.accentGold),
                  );
                }

                if (state.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.\nSay hello!',
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 14.sp),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: state.messages.length +
                      (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == state.messages.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: ext.accentGold, strokeWidth: 2),
                        ),
                      );
                    }
                    final msg = state.messages[index];
                    final isMe = msg.senderId == _myId;
                    if (_animateIds.contains(msg.id)) {
                      return MessageEntrance(
                        key: ValueKey(msg.id),
                        fromRight: isMe,
                        child: MessageBubble(
                          message: msg,
                          isMe: isMe,
                          onUserTap: isMe
                              ? null
                              : () => _onUserTap(context, msg),
                        ),
                      );
                    }
                    return MessageBubble(
                      key: ValueKey(msg.id),
                      message: msg,
                      isMe: isMe,
                      onUserTap: isMe
                          ? null
                          : () => _onUserTap(context, msg),
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(controller: _inputCtrl, onSend: _send, ext: ext),
        ],
          ),
        ),
      ),
    );
  }
}

// ── User options sheet ────────────────────────────────────────────────────────

class _UserOptionsSheet extends StatefulWidget {
  const _UserOptionsSheet({
    required this.senderId,
    required this.senderRole,
    required this.onDirectChat,
  });

  final String senderId;
  final String senderRole;
  final VoidCallback onDirectChat;

  @override
  State<_UserOptionsSheet> createState() => _UserOptionsSheetState();
}

class _UserOptionsSheetState extends State<_UserOptionsSheet> {
  bool _loading = false;

  String get _displayName {
    if (widget.senderRole.isEmpty) return 'User';
    return widget.senderRole[0].toUpperCase() + widget.senderRole.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 36.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 18.h),
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Avatar + name row
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: ext.accentGold.withValues(alpha: 0.2),
                child: Text(
                  _displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    widget.senderRole,
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 20.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.12)),
          SizedBox(height: 8.h),

          // Direct message option
          _SheetOption(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Message directly',
            accentColor: ext.accentGold,
            loading: _loading,
            onTap: () {
              setState(() => _loading = true);
              widget.onDirectChat();
            },
          ),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                          color: accentColor, strokeWidth: 2),
                    )
                  : Icon(icon, color: accentColor, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
