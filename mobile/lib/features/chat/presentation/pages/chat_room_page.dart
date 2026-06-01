import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/group_info_page.dart';
import 'package:skidoo_app/features/chat/presentation/pages/invite_to_group_page.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/message_entrance.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/services/notification_prefs_service.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

/// Displays the messages for [room].
/// Use the [ChatRoomPage.global] constructor to join the global chat room.
class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key, required this.room, this.shareUrl})
      : _globalMode = false;

  const ChatRoomPage.global({super.key})
      : room = null,
        shareUrl = null,
        _globalMode = true;

  final ChatRoom? room;

  /// When non-null, this image URL is sent as a message as soon as the
  /// WebSocket connects — used by the in-app gallery share flow.
  final String? shareUrl;

  final bool _globalMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      child: _globalMode
          ? const _GlobalRoomInitializer()
          : _ChatRoomView(room: room!, shareUrl: shareUrl),
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
      return webWrap(
        Scaffold(
          backgroundColor: ext.homeBackground,
          body: Center(child: CircularProgressIndicator(color: ext.accentGold)),
        ),
        backgroundColor: ext.homeBackground,
      );
    }
    if (_error != null) {
      return webWrap(
        Scaffold(
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
                  child: Text(AppLocalizations.of(context)!.photographerProfileRetry, style: TextStyle(color: ext.accentGold)),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: ext.homeBackground,
      );
    }
    return _ChatRoomView(room: _room!);
  }
}

// ── Main room view ────────────────────────────────────────────────────────────

class _ChatRoomView extends StatefulWidget {
  const _ChatRoomView({required this.room, this.shareUrl});
  final ChatRoom room;
  final String? shareUrl;

  @override
  State<_ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<_ChatRoomView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

  final Set<String> _knownIds = {};
  final Set<String> _animateIds = {};

  bool get _isEventRoom =>
      widget.room.type == RoomType.event ||
      widget.room.type == RoomType.eventPrivate;

  bool get _isDirect => widget.room.type == RoomType.direct;

  bool _isBlocked = false;
  bool _blockLoading = false;
  String _otherUserId = '';

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ChatRoomBloc>();
    _bloc.add(ChatRoomJoined(widget.room.id, shareUrl: widget.shareUrl, room: widget.room));
    _scrollCtrl.addListener(_onScroll);
    if (_isDirect) _loadBlockStatus();
  }

  Future<void> _loadBlockStatus() async {
    try {
      // Prefer myUserId already in bloc state (avoids a SharedPrefs round-trip)
      final myId = _bloc.state.myUserId.isNotEmpty
          ? _bloc.state.myUserId
          : await sl<AuthService>().getUserId();

      // widget.room.participants may be empty when the room was opened from the
      // cached rooms list (that API doesn't hydrate per-room participants).
      // Fall back to the BLoC state, waiting for it to load if necessary.
      var participants = widget.room.participants.isNotEmpty
          ? widget.room.participants
          : _bloc.state.room?.participants ?? [];

      if (participants.isEmpty) {
        // Wait until ChatRoomJoined finishes and the state has participants.
        final loaded = await _bloc.stream
            .firstWhere((s) => s.room?.participants.isNotEmpty == true)
            .timeout(const Duration(seconds: 8), onTimeout: () => _bloc.state);
        participants = loaded.room?.participants ?? [];
      }

      final peer = participants.where((p) => p.userId != myId).firstOrNull;
      if (peer == null) return;
      _otherUserId = peer.userId;

      final blocked = await sl<GetBlockedUsersUseCase>().call();
      if (mounted) setState(() => _isBlocked = blocked.contains(_otherUserId));
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    if (_otherUserId.isEmpty || _blockLoading) return;
    setState(() => _blockLoading = true);
    try {
      if (_isBlocked) {
        await sl<UnblockUserUseCase>().call(_otherUserId);
        if (mounted) setState(() => _isBlocked = false);
      } else {
        await sl<BlockUserUseCase>().call(_otherUserId);
        if (mounted) setState(() => _isBlocked = true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not ${_isBlocked ? 'unblock' : 'block'} user: $e');
      }
    } finally {
      if (mounted) setState(() => _blockLoading = false);
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
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _bloc.add(const ChatRoomLoadMoreRequested());
    }
  }

  void _send(String? replyToId, {bool hasPendingImage = false}) {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty && !hasPendingImage) return;
    _bloc.add(ChatRoomMessageSent(
      text.isEmpty ? null : text,
      replyToId: replyToId,
    ));
    _inputCtrl.clear();
  }

  void _onImagePicked(String filePath, {String? mimeType, bool isVideo = false}) {
    _bloc.add(ChatRoomImagePicked(filePath, isVideo: isVideo, mimeType: mimeType));
  }

  void _onReply(ChatMessage msg) {
    HapticFeedback.selectionClick();
    _bloc.add(ChatRoomReplySet(msg));
  }

  void _onMessageOptions(BuildContext context, ChatMessage msg, bool isMe) {
    HapticFeedback.selectionClick();
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final canEdit = isMe && !msg.isEncrypted && msg.imageUrl == null;
    final screenW = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
          maxWidth: screenW > 600 ? 480 : double.infinity),
      builder: (_) => _MessageOptionsSheet(
        ext: ext,
        canEdit: canEdit,
        canDelete: isMe,
        onReply: () {
          Navigator.pop(context);
          _onReply(msg);
        },
        onEdit: canEdit
            ? () {
                Navigator.pop(context);
                _showEditDialog(context, msg);
              }
            : null,
        onDelete: isMe
            ? () {
                Navigator.pop(context);
                _showDeleteDialog(context, msg);
              }
            : null,
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, ChatMessage msg) async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final ctrl = TextEditingController(text: msg.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ext.cardSurface,
        title: Text(AppLocalizations.of(context)!.chatRoomEditMessage,
            style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.chatRoomEditYourMessage,
            hintStyle: TextStyle(color: ext.searchHintColor),
            border: InputBorder.none,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(AppLocalizations.of(context)!.chatRoomCancel, style: TextStyle(color: ext.searchHintColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(AppLocalizations.of(context)!.chatRoomSave,
                style: TextStyle(
                    color: ext.accentGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (newContent != null &&
        newContent.isNotEmpty &&
        newContent != msg.content &&
        context.mounted) {
      _bloc.add(ChatRoomMessageEditRequested(msg.id, newContent));
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, ChatMessage msg) async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ext.cardSurface,
        title: Text(AppLocalizations.of(context)!.chatRoomDeleteMessage,
            style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
        content: Text(AppLocalizations.of(context)!.chatRoomDeleteForEveryone,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text(AppLocalizations.of(context)!.chatRoomCancel, style: TextStyle(color: ext.searchHintColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.chatRoomDelete,
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      _bloc.add(ChatRoomMessageDeleteRequested(msg.id));
    }
  }

  void _clearReply() {
    _bloc.add(const ChatRoomReplySet(null));
  }

  void _onUserTap(BuildContext context, ChatMessage msg) {
    if (msg.senderId == _bloc.state.myUserId) return;
    final screenW = MediaQuery.of(context).size.width;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
          maxWidth: screenW > 600 ? 480 : double.infinity),
      builder: (_) => _UserOptionsSheet(
        senderId: msg.senderId,
        senderRole: msg.senderRole,
        onDirectChat: () => _openDirectChat(context, msg),
      ),
    );
  }

  Future<void> _openInvitePage(BuildContext context) async {
    final count = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => InviteToGroupPage(room: widget.room),
      ),
    );
    if (!context.mounted || count == null) return;
    AppSnackBar.success(context, AppLocalizations.of(context)!.chatRoomInvitedCount(count));
  }

  void _openGroupInfo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _bloc,
          child: const GroupInfoPage(),
        ),
      ),
    );
  }

  Future<void> _openDirectChat(BuildContext context, ChatMessage msg) async {
    Navigator.of(context).pop();
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: msg.senderId,
        recipientRole: msg.senderRole,
        localDisplayName: msg.senderName.isNotEmpty ? msg.senderName : msg.senderRole,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      if (!context.mounted) return;
      final isBlocked = e is ServerException && e.message.contains('400');
      AppSnackBar.error(
        context,
        isBlocked ? AppLocalizations.of(context)!.chatRoomNotAcceptingMessages : AppLocalizations.of(context)!.chatRoomCouldNotOpenChat(e.toString()),
      );
    }
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb ? null : IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: ext.greetingColor, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Semantics(button: true, label: 'Open group info', child: GestureDetector(
          onTap: widget.room.type == RoomType.group
              ? () => _openGroupInfo(context)
              : null,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BlocBuilder<ChatRoomBloc, ChatRoomState>(
                  buildWhen: (p, c) => p.room?.name != c.room?.name,
                  builder: (_, state) => Text(
                    state.room?.displayName ?? widget.room.displayName,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                if (widget.room.type == RoomType.group) ...[
                  SizedBox(width: 4.w),
                  Icon(Icons.keyboard_arrow_right_rounded,
                      color: ext.searchHintColor, size: 16.sp),
                ],
              ],
            ),
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              buildWhen: (p, c) =>
                  p.isConnected != c.isConnected ||
                  p.isConnecting != c.isConnecting,
              builder: (_, state) {
                if (state.isConnected) return const SizedBox.shrink();
                final label =
                    state.isConnecting ? AppLocalizations.of(context)!.chatRoomConnecting : AppLocalizations.of(context)!.chatRoomDisconnected;
                final color =
                    state.isConnecting ? Colors.orangeAccent : Colors.redAccent;
                return Text(
                  label,
                  style: TextStyle(color: color, fontSize: 10.sp),
                );
              },
            ),
          ],
          ),
        )),
        actions: [
          // Block/Unblock menu — only shown for DM rooms
          if (_isDirect)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: ext.greetingColor, size: 20.sp),
              color: ext.cardSurface,
              onSelected: (v) {
                if (v == 'block') _toggleBlock();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: _blockLoading
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: CircularProgressIndicator(
                              color: ext.accentGold, strokeWidth: 2),
                        )
                      : Row(
                          children: [
                            Icon(
                              _isBlocked
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.block_rounded,
                              color: _isBlocked
                                  ? const Color(0xFF10B981)
                                  : Colors.redAccent,
                              size: 18.sp,
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              _isBlocked ? 'Unblock user' : 'Block user',
                              style: TextStyle(
                                color: _isBlocked
                                    ? const Color(0xFF10B981)
                                    : Colors.redAccent,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          // Invite button — only shown for group rooms
          if (widget.room.type == RoomType.group)
            IconButton(
              icon: Icon(Icons.person_add_outlined,
                  color: ext.greetingColor, size: 20.sp),
              tooltip: AppLocalizations.of(context)!.chatRoomAddPeople,
              onPressed: () => _openInvitePage(context),
            ),
          // Like button — only shown for event rooms that have an event_id
          if (_isEventRoom && widget.room.eventId != null)
            BlocBuilder<ChatRoomBloc, ChatRoomState>(
              buildWhen: (p, c) =>
                  p.eventLikes != c.eventLikes ||
                  p.isEventLiked != c.isEventLiked,
              builder: (_, state) {
                return _LikeButton(
                  likes: state.eventLikes,
                  isLiked: state.isEventLiked,
                  ext: ext,
                  onTap: () =>
                      _bloc.add(ChatRoomLikeToggled(widget.room.eventId!)),
                );
              },
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: BlocBuilder<ChatRoomBloc, ChatRoomState>(
            buildWhen: (p, c) =>
                p.replyingTo != c.replyingTo ||
                p.isUploadingImage != c.isUploadingImage ||
                p.pendingImagePath != c.pendingImagePath ||
                p.pendingShareUrl != c.pendingShareUrl,
            builder: (context, inputState) {
              return Column(
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
                  if (widget.room.type == RoomType.direct ||
                      widget.room.type == RoomType.group)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 11.sp,
                              color: ext.searchHintColor.withValues(alpha: 0.6)),
                          SizedBox(width: 4.w),
                          Text(
                            AppLocalizations.of(context)!.chatRoomEndToEndEncrypted,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: ext.searchHintColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: BlocConsumer<ChatRoomBloc, ChatRoomState>(
                      listenWhen: (p, c) =>
                          p.errorMessage != c.errorMessage ||
                          p.messages != c.messages ||
                          p.isDeleted != c.isDeleted ||
                          (c.systemNotice != null && p.systemNotice != c.systemNotice),
                      listener: (context, state) {
                        if (state.isDeleted) {
                          // First close any sub-pages (e.g. GroupInfoPage), then
                          // pop ChatRoomPage itself.
                          final thisRoute = ModalRoute.of(context);
                          final nav = Navigator.of(context);
                          if (thisRoute != null) {
                            nav.popUntil((route) => route == thisRoute);
                          }
                          nav.pop();
                          return;
                        }
                        if (state.errorMessage != null) {
                          AppSnackBar.error(context, state.errorMessage!);
                        }
                        if (state.systemNotice != null) {
                          AppSnackBar.info(context, state.systemNotice!);
                        }
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
                          p.isLoadingMore != c.isLoadingMore ||
                          p.myUserId != c.myUserId,
                      builder: (context, state) {
                        _syncAnimationState(
                            state.messages, state.isLoadingHistory);
                        if (state.isLoadingHistory && state.messages.isEmpty) {
                          return Center(
                            child: CircularProgressIndicator(
                                color: ext.accentGold),
                          );
                        }

                        if (state.messages.isEmpty) {
                          return Center(
                            child: Text(
                              AppLocalizations.of(context)!.chatRoomNoMessages,
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
                            var msg = state.messages[index];
                            final isMe = msg.senderId == state.myUserId;

                            // Fill senderName from the participants list when
                            // the server/cache left it blank.
                            if (!isMe && msg.senderName.isEmpty) {
                              final participant = state.room?.participants
                                  .where((p) => p.userId == msg.senderId)
                                  .firstOrNull;
                              if (participant != null) {
                                msg = msg.copyWith(
                                    senderName: participant.displayName);
                              }
                            }

                            final totalOthers = (state.room?.participants ?? [])
                                .where((p) => p.userId != msg.senderId)
                                .length;
                            final bubble = MessageBubble(
                              key: ValueKey(msg.id),
                              message: msg,
                              isMe: isMe,
                              readCount: msg.readBy.length,
                              totalOthers: totalOthers,
                              onUserTap: isMe
                                  ? null
                                  : () => _onUserTap(context, msg),
                              onLongPress: () =>
                                  _onMessageOptions(context, msg, isMe),
                            );

                            if (_animateIds.contains(msg.id)) {
                              return MessageEntrance(
                                key: ValueKey('anim_${msg.id}'),
                                fromRight: isMe,
                                child: bubble,
                              );
                            }
                            return bubble;
                          },
                        );
                      },
                    ),
                  ),
                  BlocBuilder<ChatRoomBloc, ChatRoomState>(
                    buildWhen: (p, c) =>
                        p.room?.adminOnly != c.room?.adminOnly ||
                        p.amIAdmin != c.amIAdmin ||
                        p.isConnected != c.isConnected,
                    builder: (context, adminState) {
                      final isAdminOnly =
                          adminState.room?.adminOnly == true;
                      final canSend =
                          adminState.amIAdmin || !isAdminOnly;

                      if (!canSend) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 16.h, horizontal: 20.w),
                          decoration: BoxDecoration(
                            color: ext.cardSurface,
                            border: Border(
                              top: BorderSide(
                                  color: ext.searchHintColor
                                      .withValues(alpha: 0.15)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 14.sp,
                                  color: ext.searchHintColor),
                              SizedBox(width: 8.w),
                              Text(
                                AppLocalizations.of(context)!.chatRoomOnlyAdminsCanSend,
                                style: TextStyle(
                                  color: ext.searchHintColor,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (_isBlocked) {
                        return _BlockedBanner(
                          ext: ext,
                          loading: _blockLoading,
                          onUnblock: _toggleBlock,
                        );
                      }

                      return ChatInputBar(
                        controller: _inputCtrl,
                        onSend: () => _send(
                          inputState.replyingTo?.id,
                          hasPendingImage:
                              inputState.pendingImagePath != null ||
                                  inputState.pendingShareUrl != null,
                        ),
                        ext: ext,
                        replyingTo: inputState.replyingTo,
                        onClearReply: _clearReply,
                        onImagePicked: _onImagePicked,
                        pendingImagePath: inputState.pendingImagePath,
                        pendingIsVideo: inputState.pendingIsVideo,
                        pendingShareUrl: inputState.pendingShareUrl,
                        onClearImage: () =>
                            _bloc.add(const ChatRoomImageCleared()),
                        isUploadingImage: inputState.isUploadingImage,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Like button ───────────────────────────────────────────────────────────────

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.likes,
    required this.isLiked,
    required this.ext,
    required this.onTap,
  });

  final int? likes;
  final bool isLiked;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? Colors.redAccent : ext.searchHintColor,
              size: 20.sp,
            ),
            if (likes != null) ...[
              SizedBox(width: 4.w),
              Text(
                '$likes',
                style: TextStyle(
                  color: isLiked ? Colors.redAccent : ext.searchHintColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    ));
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
          _SheetOption(
            icon: Icons.chat_bubble_outline_rounded,
            label: AppLocalizations.of(context)!.chatRoomMessageDirectly,
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
    return Semantics(button: true, child: InkWell(
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
    ));
  }
}

// ── Message options sheet (reply / edit / delete) ─────────────────────────────

class _MessageOptionsSheet extends StatelessWidget {
  const _MessageOptionsSheet({
    required this.ext,
    required this.canEdit,
    required this.canDelete,
    required this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final AppThemeExtension ext;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 36.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          _SheetOption(
            icon: Icons.reply_rounded,
            label: AppLocalizations.of(context)!.chatRoomReply,
            accentColor: ext.accentGold,
            onTap: onReply,
          ),
          if (canEdit)
            _SheetOption(
              icon: Icons.edit_rounded,
              label: AppLocalizations.of(context)!.chatRoomEdit,
              accentColor: Colors.blueAccent,
              onTap: onEdit!,
            ),
          if (canDelete)
            _SheetOption(
              icon: Icons.delete_outline_rounded,
              label: AppLocalizations.of(context)!.chatRoomDelete,
              accentColor: Colors.redAccent,
              onTap: onDelete!,
            ),
        ],
      ),
    );
  }
}

// ── Blocked state banner ──────────────────────────────────────────────────────

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({
    required this.ext,
    required this.loading,
    required this.onUnblock,
  });

  final AppThemeExtension ext;
  final bool loading;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(color: ext.searchHintColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: Colors.redAccent, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'You have blocked this user',
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            ),
          ),
          TextButton(
            onPressed: loading ? null : onUnblock,
            child: loading
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                        color: ext.accentGold, strokeWidth: 2),
                  )
                : Text(
                    'Unblock',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
