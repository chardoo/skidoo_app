import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_confirm_dialog.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/contact_info_page.dart';
import 'package:jperg_app/features/chat/presentation/pages/group_info_page.dart';
import 'package:jperg_app/features/chat/presentation/pages/invite_to_group_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/features/chat/presentation/widgets/day_separator.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_entrance.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_avatar.dart';
import 'package:jperg_app/features/chat/presentation/widgets/system_message_row.dart';
import 'package:jperg_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/services/notification_prefs_service.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

/// Displays the messages for [room].
class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key, required this.room, this.shareUrl});

  final ChatRoom room;

  /// When non-null, this image URL is sent as a message as soon as the
  /// WebSocket connects — used by the in-app gallery share flow.
  final String? shareUrl;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChatRoomBloc>(),
      child: _ChatRoomView(room: room, shareUrl: shareUrl),
    );
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

  bool get _isGroup => widget.room.type == RoomType.group;

  /// Only DMs and groups have a details screen. An event or photo room has no
  /// contact behind it and no membership to manage.
  bool get _hasDetailsScreen => _isDirect || _isGroup;

  /// The line under the room name in the header: who else is in the group.
  /// Null in a DM, where the name is already the whole answer.
  String? _headerSubtitle(ChatRoom room, String myId) {
    if (room.type != RoomType.group) return null;
    final others = room.othersFor(myId).where((p) => !p.isPending).toList();
    if (others.isEmpty) return 'Just you';
    final names = [for (final p in others) _firstName(p.displayName)];
    // "You" last, matching the designs — the list is about who else is here.
    return '${names.join(', ')}, You';
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return 'Someone';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }

  /// Whether the peer is blocked.
  ///
  /// A notifier rather than plain state because Contact Info is a separate
  /// route: it is built once when pushed, so a setState here would never reach
  /// it and its Block/Unblock label would stay on whatever it said at push
  /// time, however many times it was tapped.
  final _isBlockedNotifier = ValueNotifier<bool>(false);
  bool get _isBlocked => _isBlockedNotifier.value;
  set _isBlocked(bool value) => _isBlockedNotifier.value = value;

  bool _blockLoading = false;
  String _otherUserId = '';
  // The super admin's account is never blockable — matches the 'admin' /
  // 'superAdmin' role-string convention already used for participant-level
  // checks elsewhere (e.g. ChatRoom.hasAdminParticipant, not AuthService's
  // own-role check, which uses a different 'super_admin' string for a
  // different purpose — the signed-in user's own role).
  bool _isPeerSuperAdmin = false;

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
      if (mounted) {
        setState(() => _isPeerSuperAdmin = peer.userRole == 'superAdmin');
      } else {
        _isPeerSuperAdmin = peer.userRole == 'superAdmin';
      }
      if (_isPeerSuperAdmin) return;

      final blocked = await sl<GetBlockedUsersUseCase>().call();
      if (mounted) setState(() => _isBlocked = blocked.contains(_otherUserId));
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    if (_otherUserId.isEmpty || _blockLoading || _isPeerSuperAdmin) return;
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
    _isBlockedNotifier.dispose();
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
    // The composer is empty again, so we are no longer typing. Without this the
    // indicator sits on the recipient's screen next to the message that just
    // arrived, until it times out.
    _bloc.add(const ChatRoomTypingChanged(false));
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
        content: AppTextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          filled: false,
          hint: AppLocalizations.of(context)!.chatRoomEditYourMessage,
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.chatRoomDeleteMessage,
      message: AppLocalizations.of(context)!.chatRoomDeleteForEveryone,
      confirmLabel: AppLocalizations.of(context)!.chatRoomDelete,
      cancelLabel: AppLocalizations.of(context)!.chatRoomCancel,
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
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

  /// Group info for a group, contact info for a DM. Both are reached the same
  /// way — tapping the header, or the overflow — so they resolve in one place.
  void _openDetails(BuildContext context) {
    if (!_hasDetailsScreen) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _bloc,
          child: _isGroup
              ? const GroupInfoPage()
              : ContactInfoPage(
                  isBlocked: _isBlockedNotifier,
                  canBlock: !_isPeerSuperAdmin,
                  onToggleBlock: _toggleBlock,
                ),
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
      AppSnackBar.error(
        context,
        chatErrorText(
          e,
          fallback: AppLocalizations.of(context)!
              .chatRoomCouldNotOpenChat(e.toString()),
        ),
      );
    }
  }

  // ── Conversation rows ─────────────────────────────────────────────────────
  //
  // The list is reversed, so these run newest-first: the typing bubble is at
  // index 0 (visually the bottom), and a day separator follows the last message
  // of that day (visually above it).

  List<_Row> _buildRows(ChatRoomState state) {
    final rows = <_Row>[];

    final typingNames = state.typingUsers.values
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    if (state.typingUsers.isNotEmpty) {
      rows.add(_Row.typing(
        // A DM has one possible sender, so naming them is redundant. In a group
        // it is the whole point.
        _isGroup && typingNames.isNotEmpty ? typingNames.join(', ') : null,
      ));
    }

    for (int i = 0; i < state.messages.length; i++) {
      final msg = state.messages[i];
      rows.add(_Row.message(msg));

      // The next entry is older, so a change of day means this message opens
      // its day and the separator belongs after it in reversed order.
      final older = i + 1 < state.messages.length ? state.messages[i + 1] : null;
      if (older == null ||
          DaySeparator.needsSeparator(older.createdAt, msg.createdAt)) {
        rows.add(_Row.day(msg.createdAt));
      }
    }

    return rows;
  }

  Widget _buildRow(BuildContext context, ChatRoomState state, _Row row) {
    switch (row.kind) {
      case _RowKind.typing:
        return TypingIndicator(label: row.label);

      case _RowKind.day:
        return DaySeparator(date: row.date!);

      case _RowKind.message:
        var msg = row.message!;
        final isMe = msg.senderId == state.myUserId;

        if (msg.isSystem) {
          return SystemMessageRow(
            key: ValueKey(msg.id),
            message: msg,
            currentUserId: state.myUserId,
          );
        }

        // Fill senderName and the avatar from the participants list when the
        // server or cache left them blank.
        final participant = state.room?.participants
            .where((p) => p.userId == msg.senderId)
            .firstOrNull;
        if (!isMe && msg.senderName.isEmpty && participant != null) {
          msg = msg.copyWith(senderName: participant.displayName);
        }

        final totalOthers = (state.room?.participants ?? [])
            .where((p) => p.userId != msg.senderId)
            .length;

        final bubble = MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMe: isMe,
          isGroup: _isGroup,
          senderImageUrl: participant?.userImage,
          readCount: msg.readBy.length,
          totalOthers: totalOthers,
          onUserTap: isMe ? null : () => _onUserTap(context, msg),
          onLongPress: () => _onMessageOptions(context, msg, isMe),
        );

        if (_animateIds.contains(msg.id)) {
          return MessageEntrance(
            key: ValueKey('anim_${msg.id}'),
            fromRight: isMe,
            child: bubble,
          );
        }
        return bubble;
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
        leading: kIsWeb ? null : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        titleSpacing: 0,
        title: BlocBuilder<ChatRoomBloc, ChatRoomState>(
          buildWhen: (p, c) => p.room != c.room || p.myUserId != c.myUserId,
          builder: (_, state) {
            final room = state.room ?? widget.room;
            final subtitle = _headerSubtitle(room, state.myUserId);
            return Semantics(
              // Event and photo rooms have no details screen, so the header is
              // not a button there — announcing one that does nothing is worse
              // than announcing nothing.
              button: _hasDetailsScreen,
              label: _hasDetailsScreen ? 'Open chat details' : null,
              child: GestureDetector(
                onTap: _hasDetailsScreen ? () => _openDetails(context) : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoomAvatar(
                      room: room,
                      currentUserId: state.myUserId,
                      radius: 18,
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            room.displayNameFor(state.myUserId),
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: ext.searchHintColor,
                                fontSize: 11.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
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
          // One overflow for everything that used to be its own icon. Contact
          // info now owns block, mute and shared media, so the header keeps a
          // single control instead of three competing ones.
          if (_hasDetailsScreen)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: ext.greetingColor, size: 20.sp),
              color: ext.cardSurface,
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    _openDetails(context);
                  case 'invite':
                    _openInvitePage(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'details',
                  child: Text(
                    _isGroup ? 'Group info' : 'Contact info',
                    style: TextStyle(
                        color: ext.greetingColor, fontSize: 14.sp),
                  ),
                ),
                if (_isGroup)
                  PopupMenuItem(
                    value: 'invite',
                    child: Text(
                      AppLocalizations.of(context)!.chatRoomAddPeople,
                      style: TextStyle(
                          color: ext.greetingColor, fontSize: 14.sp),
                    ),
                  ),
              ],
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
                            color: ext.searchHintColor.withValues(alpha: 0.6),
                          )
                        : const SizedBox.shrink(),
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
                                color: ext.searchHintColor),
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

                        // Flattened up front rather than derived inside the
                        // builder: day separators depend on the *next* item, and
                        // working that out per-index in a reversed list is where
                        // off-by-one separators come from.
                        final rows = _buildRows(state);

                        return ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                          itemCount:
                              rows.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == rows.length) {
                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.md.h),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: ext.searchHintColor,
                                      strokeWidth: 2),
                                ),
                              );
                            }
                            return _buildRow(context, state, rows[index]);
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
                              vertical: AppSpacing.lg.h, horizontal: AppSpacing.xl.w),
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
                              SizedBox(width: AppSpacing.sm.w),
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
                        onTypingChanged: (isTyping) =>
                            _bloc.add(ChatRoomTypingChanged(isTyping)),
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

enum _RowKind { message, day, typing }

/// One entry in the conversation list — a message, a day marker, or the typing
/// bubble. Flattened ahead of the builder so separators can look at neighbours.
class _Row {
  const _Row._(this.kind, {this.message, this.date, this.label});

  factory _Row.message(ChatMessage message) =>
      _Row._(_RowKind.message, message: message);
  factory _Row.day(DateTime date) => _Row._(_RowKind.day, date: date);
  factory _Row.typing(String? label) => _Row._(_RowKind.typing, label: label);

  final _RowKind kind;
  final ChatMessage? message;
  final DateTime? date;
  final String? label;
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
    return Semantics(button: true, label: 'Like', child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? Colors.redAccent : ext.searchHintColor,
              size: 20.sp,
            ),
            if (likes != null) ...[
              SizedBox(width: AppSpacing.xs.w),
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
                backgroundColor: ext.searchFieldFill,
                child: Text(
                  _displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: ext.greetingColor,
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
          SizedBox(height: AppSpacing.xl.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.12)),
          SizedBox(height: AppSpacing.sm.h),
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
    return Semantics(button: true, label: label, child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h, horizontal: AppSpacing.xs.w),
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
            accentColor: Colors.teal,
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w, vertical: 14.h),
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
