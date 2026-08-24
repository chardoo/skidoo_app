import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_confirm_dialog.dart';
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
import 'package:jperg_app/features/chat/presentation/mentions.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:jperg_app/features/chat/presentation/widgets/forward_message_sheet.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_action_sheet.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/features/chat/presentation/widgets/day_separator.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_entrance.dart';
import 'package:jperg_app/features/chat/presentation/widgets/pinned_message_banner.dart';
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
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  late final ChatRoomBloc _bloc;

  /// The message the composer is currently editing, or null when it is writing
  /// a new one. Lives here rather than in the bloc: nothing outside the
  /// composer changes while an edit is in flight, and the edit itself is a
  /// one-shot event.
  ChatMessage? _editing;

  /// What the composer held before [_editing] took it over, restored on cancel.
  String? _draftBeforeEdit;

  final Set<String> _knownIds = {};
  final Set<String> _animateIds = {};

  /// The message a jump just landed on, tinted for a moment so the reader can
  /// find it. Cleared on a timer — a permanent highlight would look like state.
  String? _highlightedMessageId;

  /// A key per message row, so a jump can scroll to the real widget instead of
  /// guessing an offset from an average row height.
  ///
  /// Only rows the list has actually built have a live context; the rest hold a
  /// key that resolves to null, which is exactly the signal [_jumpToMessage]
  /// needs to fall back. Cleared when the conversation is replaced so the map
  /// cannot outlive the messages it points at.
  final Map<String, GlobalKey> _rowKeys = {};

  /// The message list [_rowKeys] was last pruned against.
  List<ChatMessage>? _rowKeysSyncedTo;

  GlobalKey _rowKeyFor(String messageId) =>
      _rowKeys.putIfAbsent(messageId, () => GlobalKey());

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

  /// The *peer* blocked us. Kept apart from [_isBlocked] because the two need
  /// opposite treatment: one gets an Unblock control, the other must not, since
  /// there is no block of ours to remove and the request would be rejected.
  /// Both close the composer — the server now refuses a DM send in either
  /// direction, so leaving it open only produces messages that fail to send.
  bool _blockedByPeer = false;

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

  /// The other participant's id, resolved against whatever is known *now*.
  ///
  /// Resolved on demand rather than captured once at mount. It used to be set
  /// only by [_loadBlockStatus], a one-shot routine that gives up silently on
  /// every one of its failure paths — an 8-second timeout waiting for the room
  /// to hydrate, a participant list that never fills, a swallowed exception.
  /// When any of those happened `_otherUserId` stayed empty, and because
  /// [_toggleBlock] bailed on its first line, tapping "Block User" did
  /// *nothing*: no request, no error, no feedback of any kind. That is the
  /// state the block feature was found in.
  ///
  /// Returns null only if the peer genuinely cannot be determined, which
  /// callers are expected to report rather than swallow.
  Future<String?> _resolvePeerId({Duration? waitFor}) async {
    if (_otherUserId.isNotEmpty) return _otherUserId;

    final myId = _bloc.state.myUserId.isNotEmpty
        ? _bloc.state.myUserId
        : await sl<AuthService>().getUserId();

    // widget.room.participants may be empty when the room was opened from the
    // cached rooms list (that API doesn't hydrate per-room participants), so
    // fall back to the BLoC state, which ChatRoomJoined fills in.
    var participants = widget.room.participants.isNotEmpty
        ? widget.room.participants
        : _bloc.state.room?.participants ?? const [];

    if (participants.isEmpty && waitFor != null) {
      final loaded = await _bloc.stream
          .firstWhere((s) => s.room?.participants.isNotEmpty == true)
          .timeout(waitFor, onTimeout: () => _bloc.state);
      participants = loaded.room?.participants ?? const [];
    }

    final peer = participants.where((p) => p.userId != myId).firstOrNull;
    if (peer == null) return null;

    _otherUserId = peer.userId;
    final isSuperAdmin = peer.userRole == 'superAdmin';
    if (mounted) {
      setState(() => _isPeerSuperAdmin = isSuperAdmin);
    } else {
      _isPeerSuperAdmin = isSuperAdmin;
    }
    return _otherUserId;
  }

  Future<void> _loadBlockStatus() async {
    try {
      final peerId = await _resolvePeerId(waitFor: const Duration(seconds: 8));
      if (peerId == null || _isPeerSuperAdmin) return;

      // can-message reports both directions in one call. The blocked-users list
      // only ever says what *we* blocked, so a room the peer had closed looked
      // completely normal from this side: an open composer, and sends that the
      // server drops.
      final permission = await sl<CanMessageUseCase>().call(peerId);
      var blockedByMe = permission.blockedByMe;
      var blockedByThem = permission.blockedByThem;

      // A server that predates the two flags says only that *a* block exists,
      // not whose, and both flags read false — which would render an
      // unblocked-looking room over a blocked conversation, and put the app
      // right back in the state this was meant to fix. The block list is
      // served by every version, so it settles whose block it is.
      if (permission.reason == 'USER_BLOCKED' && !blockedByMe && !blockedByThem) {
        blockedByMe = (await sl<GetBlockedUsersUseCase>().call()).contains(peerId);
        blockedByThem = !blockedByMe;
      }

      if (!mounted) return;
      setState(() {
        _isBlocked = blockedByMe;
        _blockedByPeer = blockedByThem;
      });
    } catch (_) {
      // Priming the banner is best-effort — the toggle below no longer depends
      // on it having succeeded.
    }
  }

  Future<void> _toggleBlock() async {
    if (_blockLoading) return;
    setState(() => _blockLoading = true);
    // Read once: the catch below reported the state *after* the optimistic
    // flip, so a failed block said "Could not unblock user".
    final wasBlocked = _isBlocked;
    try {
      // Resolved here, not read from a field primed at mount — see
      // [_resolvePeerId]. By now the room has had time to load, so the short
      // wait is enough on the paths where mount-time resolution lost the race.
      final peerId =
          await _resolvePeerId(waitFor: const Duration(seconds: 3));
      if (peerId == null) {
        if (mounted) {
          AppSnackBar.error(
              context, 'Could not identify this contact — try reopening the chat.');
        }
        return;
      }
      if (_isPeerSuperAdmin) return;

      if (wasBlocked) {
        await sl<UnblockUserUseCase>().call(peerId);
        // Only our own block is lifted. _blockedByPeer is left alone on
        // purpose: in a mutual block, clearing it here would reopen the
        // composer while the other side still has us blocked, and every send
        // would be refused.
        if (mounted) setState(() => _isBlocked = false);
      } else {
        await sl<BlockUserUseCase>().call(peerId);
        if (mounted) setState(() => _isBlocked = true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, 'Could not ${wasBlocked ? 'unblock' : 'block'} user: $e');
      }
    } finally {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  @override
  void dispose() {
    _bloc.add(const ChatRoomLeft());
    _inputCtrl.dispose();
    _inputFocus.dispose();
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
    // While editing, the send button is the edit's confirm — same button, same
    // Enter key, so there is nothing new to learn.
    if (_editing != null) {
      _commitEdit();
      return;
    }
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
    final canEdit = isMe && !msg.isEncrypted && msg.imageUrl == null;
    final hasText = !msg.isEncrypted && msg.content.trim().isNotEmpty;
    final screenW = MediaQuery.of(context).size.width;
    final isPinned = _bloc.state.room?.pinnedMessage?.id == msg.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
          maxWidth: screenW > 600 ? 480 : double.infinity),
      builder: (_) => MessageActionSheet(
        isPinned: isPinned,
        onReply: () {
          Navigator.pop(context);
          _onReply(msg);
        },
        // Nothing to forward from a message the app could not decrypt — the
        // body on screen belongs to this room's key, not the next room's.
        onForward: msg.isEncrypted
            ? null
            : () {
                Navigator.pop(context);
                _forwardMessage(context, msg);
              },
        onCopy: hasText
            ? () {
                Navigator.pop(context);
                _copyMessage(context, msg);
              }
            : null,
        // Only conversations have a banner to pin to; an event or photo room
        // is a comment thread with no header of its own.
        onPin: _canPin
            ? () {
                Navigator.pop(context);
                _bloc.add(ChatRoomPinToggled(isPinned ? null : msg.id));
              }
            : null,
        onEdit: canEdit
            ? () {
                Navigator.pop(context);
                _beginEdit(msg);
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

  /// Whether the reader may change what is pinned here.
  ///
  /// Mirrors the server's rule so the menu doesn't offer an action that comes
  /// back rejected: any active member, except in an admin-only room, where
  /// pinning follows the same restriction as speaking.
  bool get _canPin {
    if (!_hasDetailsScreen) return false;
    final state = _bloc.state;
    if (state.room?.adminOnly == true && !state.amIAdmin) return false;
    return true;
  }

  void _copyMessage(BuildContext context, ChatMessage msg) {
    Clipboard.setData(ClipboardData(text: msg.content));
    AppSnackBar.success(context, 'Copied to clipboard');
  }

  Future<void> _forwardMessage(BuildContext context, ChatMessage msg) async {
    final target = await showModalBottomSheet<ChatRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ForwardMessageSheet(
        myUserId: _bloc.state.myUserId,
        excludeRoomId: widget.room.id,
      ),
    );
    if (target == null || !context.mounted) return;
    // No confirmation here: the bloc announces the forward once the frame has
    // gone out, and reports the refusal otherwise. Saying "Forwarded" from the
    // caller claimed success for sends that never left.
    _bloc.add(ChatRoomForwardRequested(
      msg,
      target.id,
      targetName: target.displayNameFor(_bloc.state.myUserId),
    ));
  }

  /// Scroll the conversation to [messageId], or report that it is too far back
  /// to reach without loading more history.
  void _jumpToMessage(String messageId) {
    final rows = _buildRows(_bloc.state);
    final index = rows.indexWhere(
        (row) => row.kind == _RowKind.message && row.message!.id == messageId);
    if (index < 0) {
      AppSnackBar.info(context, 'That message is further back in the chat');
      return;
    }
    if (!_scrollCtrl.hasClients) return;

    // Prefer the real thing. A row that is currently built — which covers the
    // common case, replying to something a screen or two back — can be scrolled
    // to exactly, and ensureVisible does nothing when it is already in view
    // rather than sliding the conversation for no reason.
    final target = _rowKeys[messageId]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.4,
      );
    } else {
      // Not built, so its offset is unknown: rows are variable height and the
      // list only lays out what is near the viewport. Step by an average row
      // and let the highlight do the rest of the work.
      _scrollCtrl.animateTo(
        (index * 78.0).clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  /// Loads [msg] back into the composer instead of opening a dialog — editing
  /// happens where the text was written in the first place, and the message
  /// stays on screen behind the keyboard for comparison.
  void _beginEdit(ChatMessage msg) {
    HapticFeedback.selectionClick();
    // Editing and replying both own the composer; a reply left staged would be
    // attached to nothing once the edit is applied.
    if (_bloc.state.replyingTo != null) {
      _bloc.add(const ChatRoomReplySet(null));
    }
    // An edit carries text only, so a picked-but-unsent photo cannot ride along
    // with it. Dropping it here beats leaving a preview above a composer whose
    // send button no longer sends.
    if (_bloc.state.pendingImagePath != null ||
        _bloc.state.pendingShareUrl != null) {
      _bloc.add(const ChatRoomImageCleared());
    }
    setState(() {
      // Whatever was half-typed is not lost: cancelling the edit puts it back.
      _draftBeforeEdit = _inputCtrl.text;
      _editing = msg;
    });
    _inputCtrl.value = TextEditingValue(
      text: msg.content,
      selection: TextSelection.collapsed(offset: msg.content.length),
    );
    _inputFocus.requestFocus();
  }

  void _cancelEdit() {
    final draft = _draftBeforeEdit ?? '';
    setState(() {
      _editing = null;
      _draftBeforeEdit = null;
    });
    _inputCtrl.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
    _bloc.add(ChatRoomTypingChanged(draft.trim().isNotEmpty));
  }

  /// Applies the edit the composer currently holds. An unchanged body is
  /// treated as a cancel — stamping "edited" on a message nobody changed is a
  /// lie the reader can see.
  void _commitEdit() {
    final msg = _editing!;
    final text = _inputCtrl.text.trim();
    if (text.isNotEmpty && text != msg.content.trim()) {
      _bloc.add(ChatRoomMessageEditRequested(msg.id, text));
    }
    _cancelEdit();
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

  // ── Mentions ──────────────────────────────────────────────────────────────
  //
  // Only groups have them. In a DM there is one other person, already named in
  // the header — "@Marcus" in a conversation with only Marcus in it says
  // nothing, and offering the picker would only get in the way of typing an
  // email address.

  /// Cache for the three derived maps below.
  ///
  /// They are read once per message row, so recomputing them per call meant
  /// allocating a list, a map and a set for every bubble on screen on every
  /// frame — the cost of scrolling a long group conversation. The participant
  /// list is the only input, so it is also the cache key: a new list instance
  /// (any membership or profile change) invalidates, nothing else has to.
  List<ChatParticipant>? _mentionCacheKey;
  List<ChatParticipant> _mentionCandidatesCache = const [];
  Map<String, String> _mentionHandlesCache = const {};
  Map<String, String> _mentionNamesCache = const {};

  void _refreshMentionCache(ChatRoomState state) {
    final participants = state.room?.participants ?? const <ChatParticipant>[];
    if (identical(_mentionCacheKey, participants)) return;
    _mentionCacheKey = participants;

    // Members who can be mentioned: everyone active in the room, the reader
    // included. Mentioning yourself is odd but harmless, and excluding it would
    // mean the handle you see on your own messages resolves to nobody.
    _mentionCandidatesCache = _isGroup
        ? [
            for (final p in participants)
              if (!p.isPending) p,
          ]
        : const [];
    _mentionHandlesCache = Mentions.handlesFor(_mentionCandidatesCache);
    _mentionNamesCache = {
      for (final p in _mentionCandidatesCache) p.userId: p.displayName,
    };
  }

  List<ChatParticipant> _mentionCandidates(ChatRoomState state) {
    _refreshMentionCache(state);
    return _mentionCandidatesCache;
  }

  Map<String, String> _mentionHandles(ChatRoomState state) {
    _refreshMentionCache(state);
    return _mentionHandlesCache;
  }

  Map<String, String> _mentionNames(ChatRoomState state) {
    _refreshMentionCache(state);
    return _mentionNamesCache;
  }

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

        final replyToId = msg.replyPreview?.id;
        final canJumpToReply = replyToId != null &&
            state.messages.any((m) => m.id == replyToId);

        Widget bubble = MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMe: isMe,
          isGroup: _isGroup,
          senderImageUrl: participant?.userImage,
          readCount: msg.readBy.length,
          totalOthers: totalOthers,
          mentionHandles: _mentionHandles(state),
          mentionNames: _mentionNames(state),
          myUserId: state.myUserId,
          onUserTap: isMe ? null : () => _onUserTap(context, msg),
          onLongPress: () => _onMessageOptions(context, msg, isMe),
          onReplyTap: canJumpToReply ? () => _jumpToMessage(replyToId) : null,
        );

        if (_highlightedMessageId == msg.id) {
          bubble = ColoredBox(
            color: Theme.of(context)
                .extension<AppThemeExtension>()!
                .accentGold
                .withValues(alpha: 0.12),
            child: bubble,
          );
        }

        if (_animateIds.contains(msg.id)) {
          bubble = MessageEntrance(
            key: ValueKey('anim_${msg.id}'),
            fromRight: isMe,
            child: bubble,
          );
        }

        // The key goes on the outermost wrapper so it resolves to whatever is
        // actually in the tree — a jump has to find the row however it is
        // currently decorated.
        return KeyedSubtree(key: _rowKeyFor(msg.id), child: bubble);
    }
  }

  void _syncAnimationState(List<ChatMessage> messages, bool isLoadingHistory) {
    if (isLoadingHistory) return;
    final currentIds = messages.map((m) => m.id).toSet();

    // Drop keys for messages that are gone — deleted, or replaced when an
    // optimistic id was swapped for the server's. Left alone the map would
    // grow for the life of the screen and keep handing out keys that can never
    // resolve. Keyed on the list's identity rather than its length, because a
    // delete and an arrival in the same update leave the count unchanged.
    if (!identical(_rowKeysSyncedTo, messages)) {
      _rowKeysSyncedTo = messages;
      _rowKeys.removeWhere((id, _) => !currentIds.contains(id));
    }

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
        leading: kIsWeb ? null : const AppBackButton(),
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

                  // ── Pinned message banner ─────────────────────────────
                  BlocBuilder<ChatRoomBloc, ChatRoomState>(
                    buildWhen: (p, c) =>
                        p.room?.pinnedMessage?.id != c.room?.pinnedMessage?.id ||
                        p.messages != c.messages ||
                        p.amIAdmin != c.amIAdmin,
                    builder: (context, state) {
                      final pinned = state.room?.pinnedMessage;
                      if (pinned == null) return const SizedBox.shrink();
                      final isLoaded =
                          state.messages.any((m) => m.id == pinned.id);
                      return PinnedMessageBanner(
                        pinned: pinned,
                        onTap:
                            isLoaded ? () => _jumpToMessage(pinned.id) : null,
                        onUnpin: _canPin
                            ? () => _bloc.add(const ChatRoomPinToggled(null))
                            : null,
                      );
                    },
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
                        p.isConnected != c.isConnected ||
                        // The composer's mention picker is built from the
                        // participant list, so a member joining or leaving has
                        // to reach it — without this the picker would keep
                        // offering whoever was in the room when it was opened.
                        p.room?.participants != c.room?.participants,
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

                      if (_isBlocked || _blockedByPeer) {
                        return _BlockedBanner(
                          ext: ext,
                          loading: _blockLoading,
                          // Only our own block is ours to lift.
                          onUnblock: _isBlocked ? _toggleBlock : null,
                          message: _isBlocked
                              ? 'You have blocked this user'
                              : 'You can no longer message this user',
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
                        focusNode: _inputFocus,
                        editing: _editing,
                        onCancelEdit: _cancelEdit,
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
                        mentionCandidates: _mentionCandidates(adminState),
                        mentionHandles: _mentionHandles(adminState),
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
    // Back leaves the edit before it leaves the room: while a message is loaded
    // into the composer, the composer is what the user is "in".
    return PopScope(
      canPop: _editing == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelEdit();
      },
      child: webWrap(page, backgroundColor: ext.homeBackground),
    );
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

// ── Blocked state banner ──────────────────────────────────────────────────────

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({
    required this.ext,
    required this.loading,
    required this.onUnblock,
    required this.message,
  });

  final AppThemeExtension ext;
  final bool loading;

  /// Null when the block is not the reader's to lift — the peer blocked them.
  /// The banner then explains the closed composer and offers no control.
  final VoidCallback? onUnblock;

  final String message;

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
              message,
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            ),
          ),
          if (onUnblock != null)
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
