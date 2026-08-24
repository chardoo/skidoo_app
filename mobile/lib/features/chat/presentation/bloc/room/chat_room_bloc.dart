import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/error/exceptions.dart' show ServerException;
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart'
    show ChatWebSocketService, WsAdminGrantedEvent, WsAdminRevokedEvent,
        WsChatErrorEvent,
        WsKeyBundlesEvent, WsKeyRotationEvent, WsMessageDeletedEvent,
        WsMessageEditedEvent, WsParticipantKeyAvailable,
        WsMessagePinnedEvent,
        WsParticipantRemovedEvent, WsReadReceiptEvent, WsRoomDeletedEvent,
        WsRoomSettingsUpdatedEvent, WsSenderKeyDistributionEvent,
        WsTypingEvent, WsUserJoinedEvent;
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/typing_announcer.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/like_update.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/e2ee_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_key_datasource.dart';

part 'chat_room_event.dart';
part 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetRoomMessagesUseCase _getMessages;
  final GetRoomUseCase _getRoom;
  final GetCachedMessagesUseCase _getCachedMessages;
  final CacheMessageUseCase _cacheMessage;
  final MarkRoomAsReadUseCase _markAsRead;
  final UploadChatImageUseCase _uploadImage;
  final EditMessageUseCase _editMessage;
  final DeleteMessageUseCase _deleteMessage;
  final PinMessageUseCase _pinMessage;
  final UpdateCachedMessageUseCase _updateCachedMessage;
  final DeleteCachedMessageUseCase _deleteCachedMessage;
  final GrantAdminUseCase _grantAdmin;
  final RevokeAdminUseCase _revokeAdmin;
  final UpdateRoomSettingsUseCase _updateRoomSettings;
  final SetRoomMutedUseCase _setRoomMuted;
  final KickParticipantUseCase _kickParticipant;
  final LeaveRoomUseCase _leaveRoom;
  final DeleteRoomUseCase _deleteRoom;
  final ClearRoomCacheUseCase _clearRoomCache;
  final AuthService _authService;
  final ChatBackgroundService _bgService;
  final E2eeService _e2ee;
  final ChatKeyDataSource _keyDs;

  // All rooms use the single shared connection owned by ChatBackgroundService.
  ChatWebSocketService get _ws => _bgService.sharedWs;

  String? _currentRoomId;
  // True once the first WS connect for this room has happened. Later connects
  // are reconnects → we refetch history to backfill anything missed offline.
  bool _didInitialConnect = false;
  String _myUserId = '';

  // E2EE state
  bool _isDirectRoom = false;
  bool _isGroupRoom = false;
  String? _recipientId;          // other party's userId in a DM room
  // Proactive X3DH session held in memory only — never written to secure
  // storage until the first outgoing message actually uses it.
  // Writing it to storage would cause incoming messages (encrypted by the
  // other party with THEIR session key) to fail decryption with a MAC error.
  Uint8List? _proactiveSessionKey;
  String? _pendingEphemeralKey;
  int? _pendingOtpkId;
  // SPK ID from the recipient bundle used in the proactive X3DH session.
  int? _pendingBundleSpkId;
  // Forces a fresh X3DH handshake on the first send after every room open.
  // Reset to false by _onKeyBundlesReceived when keys are confirmed unchanged.
  bool _needsRekey = false;

  StreamSubscription<ChatMessage>? _wsMsgSub;
  StreamSubscription<LikeUpdate>? _wsLikeSub;
  StreamSubscription<PictureLikeUpdate>? _wsPicLikeSub;
  StreamSubscription<WsKeyBundlesEvent>? _wsKeyBundlesSub;
  StreamSubscription<WsParticipantKeyAvailable>? _wsParticipantKeySub;
  StreamSubscription<WsKeyRotationEvent>? _wsKeyRotationSub;
  StreamSubscription<WsMessageEditedEvent>? _wsEditSub;
  StreamSubscription<WsMessageDeletedEvent>? _wsDeleteSub;
  StreamSubscription<WsMessagePinnedEvent>? _wsPinSub;
  StreamSubscription<WsUserJoinedEvent>? _wsUserJoinedSub;
  StreamSubscription<WsAdminGrantedEvent>? _wsAdminGrantedSub;
  StreamSubscription<WsAdminRevokedEvent>? _wsAdminRevokedSub;
  StreamSubscription<WsRoomSettingsUpdatedEvent>? _wsRoomSettingsSub;
  StreamSubscription<WsParticipantRemovedEvent>? _wsParticipantRemovedSub;
  StreamSubscription<WsRoomDeletedEvent>? _wsRoomDeletedSub;
  StreamSubscription<WsSenderKeyDistributionEvent>? _wsSenderKeyDistSub;
  StreamSubscription? _wsParticipantLeftSub;
  StreamSubscription<WsReadReceiptEvent>? _wsReadReceiptSub;
  StreamSubscription<WsTypingEvent>? _wsTypingSub;
  StreamSubscription<WsChatErrorEvent>? _wsErrorSub;
  // Waits for ChatBackgroundService to signal the WS is (re)connected.
  StreamSubscription<bool>? _wsConnectionSub;
  Timer? _otpkPollTimer;
  // Coalesces bursts of membership changes into a single authoritative re-fetch.
  Timer? _reconcileDebounce;
  static const int _otpkReplenishThreshold = 10;
  static const int _otpkReplenishBatchSize = 100;

  ChatRoomBloc({
    required GetRoomMessagesUseCase getRoomMessages,
    required GetRoomUseCase getRoom,
    required GetCachedMessagesUseCase getCachedMessages,
    required CacheMessageUseCase cacheMessage,
    required MarkRoomAsReadUseCase markRoomAsRead,
    required UploadChatImageUseCase uploadImage,
    required EditMessageUseCase editMessage,
    required DeleteMessageUseCase deleteMessage,
    required PinMessageUseCase pinMessage,
    required UpdateCachedMessageUseCase updateCachedMessage,
    required DeleteCachedMessageUseCase deleteCachedMessage,
    required GrantAdminUseCase grantAdmin,
    required RevokeAdminUseCase revokeAdmin,
    required UpdateRoomSettingsUseCase updateRoomSettings,
    required SetRoomMutedUseCase setRoomMuted,
    required KickParticipantUseCase kickParticipant,
    required LeaveRoomUseCase leaveRoom,
    required DeleteRoomUseCase deleteRoom,
    required ClearRoomCacheUseCase clearRoomCache,
    required AuthService authService,
    required ChatBackgroundService bgService,
    required E2eeService e2eeService,
    required ChatKeyDataSource keyDataSource,
  })  : _getMessages = getRoomMessages,
        _getRoom = getRoom,
        _getCachedMessages = getCachedMessages,
        _cacheMessage = cacheMessage,
        _markAsRead = markRoomAsRead,
        _uploadImage = uploadImage,
        _editMessage = editMessage,
        _deleteMessage = deleteMessage,
        _pinMessage = pinMessage,
        _updateCachedMessage = updateCachedMessage,
        _deleteCachedMessage = deleteCachedMessage,
        _grantAdmin = grantAdmin,
        _revokeAdmin = revokeAdmin,
        _updateRoomSettings = updateRoomSettings,
        _setRoomMuted = setRoomMuted,
        _kickParticipant = kickParticipant,
        _leaveRoom = leaveRoom,
        _deleteRoom = deleteRoom,
        _clearRoomCache = clearRoomCache,
        _authService = authService,
        _bgService = bgService,
        _e2ee = e2eeService,
        _keyDs = keyDataSource,
        super(const ChatRoomState()) {
    on<ChatRoomJoined>(_onJoined);
    on<ChatRoomMessageSent>(_onSent);
    on<ChatRoomImagePicked>(_onImagePicked);
    on<ChatRoomImageCleared>(_onImageCleared);
    on<ChatRoomReplySet>(_onReplySet);
    on<ChatRoomLikeToggled>(_onLikeToggled);
    on<ChatRoomPictureLikeToggled>(_onPictureLikeToggled);
    on<ChatRoomUrlStaged>(_onUrlStaged);
    on<ChatRoomMessageReceived>(_onReceived);
    on<ChatRoomLoadMoreRequested>(_onLoadMore);
    on<ChatRoomLeft>(_onLeft);
    on<_WsConnected>(_onWsConnected);
    on<_HistoryRefetchRequested>(_onHistoryRefetch, transformer: droppable());
    on<_WsFailed>(_onWsFailed);
    on<_WsDropped>(_onWsDropped);
    on<_WsGaveUp>(_onWsGaveUp);
    on<_LikeUpdateReceived>(_onLikeUpdateReceived);
    on<_PictureLikeUpdateReceived>(_onPictureLikeUpdateReceived);
    on<_KeyBundlesReceived>(_onKeyBundlesReceived);
    on<_ParticipantKeyAvailable>(_onParticipantKeyAvailable);
    on<_KeyRotationReceived>(_onKeyRotationReceived);
    on<ChatRoomMessageEditRequested>(_onMessageEditRequested);
    on<ChatRoomMessageDeleteRequested>(_onMessageDeleteRequested);
    on<ChatRoomForwardRequested>(_onForwardRequested);
    on<ChatRoomPinToggled>(_onPinToggled);
    on<_MessagePinned>(_onMessagePinned);
    on<_MessageEdited>(_onMessageEdited);
    on<_MessageDeleted>(_onMessageDeleted);
    on<_WsUserJoined>(_onWsUserJoined);
    on<_RoomReconcileRequested>(_onRoomReconcile);
    on<ChatRoomGrantAdminRequested>(_onGrantAdminRequested);
    on<ChatRoomRevokeAdminRequested>(_onRevokeAdminRequested);
    on<ChatRoomUpdateSettingsRequested>(_onUpdateSettingsRequested);
    on<ChatRoomKickRequested>(_onKickRequested);
    on<_AdminGranted>(_onAdminGranted);
    on<_AdminRevoked>(_onAdminRevoked);
    on<_RoomSettingsUpdated>(_onRoomSettingsUpdated);
    on<_ParticipantRemoved>(_onParticipantRemoved);
    on<ChatRoomLeaveGroupRequested>(_onLeaveGroupRequested);
    on<ChatRoomDeleteRequested>(_onDeleteRequested);
    on<_RoomDeleted>(_onRoomDeleted);
    on<_WsServerError>((event, emit) =>
        emit(state.copyWith(errorMessage: event.message)));
    on<_GroupSenderKeyReceived>(_onGroupSenderKeyReceived);
    on<_ParticipantLeft>(_onParticipantLeft);
    on<_ReadReceiptReceived>(_onReadReceiptReceived);
    on<ChatRoomTypingChanged>(_onTypingChanged);
    on<_TypingReceived>(_onTypingReceived);
    on<_TypingExpired>(_onTypingExpired);
    on<ChatRoomMuteToggled>(_onMuteToggled);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onJoined(
    ChatRoomJoined event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    _didInitialConnect = false; // first connect for this room loads history here

    final roomType = event.room?.type;
    final isDm = roomType == RoomType.direct;

    _bgService.pause(event.roomId);

    // For non-DM shared-WS rooms (global, group, photo…): attach WS listeners
    // NOW, before the REST history fetch. Messages and admin events that arrive
    // during the network round-trips are queued in the BLoC event queue and
    // processed after _onJoined completes — nothing is dropped.
    //
    // DM rooms on mobile must wait until after _deriveKeyFromHistory establishes
    // the session key; otherwise messages received before E2EE is ready are
    // decrypted with a null key → blank content → permanent loss.
    //
    // DM rooms on web: E2EE is never used (kIsWeb guard below skips the whole
    // E2EE setup block), so we attach listeners early — same as non-DM rooms.
    // Without this, WS messages that arrive during the REST fetch are dropped
    // by the paused background service and permanently lost (no SQLite on web).
    if (!isDm || kIsWeb) {
      _connectWsInBackground(event.roomId);
    }

    // Load userId and cached messages in parallel (both are fast local reads).
    // We deliberately do NOT wipe the session key here — the receiver must keep
    // the key derived from the sender's original X3DH message across room opens.
    // If the sender has an established session (no new X3DH header), the receiver
    // needs the stored key to decrypt. Wiping it every join was causing "wrong
    // proactive key" to be stored by _setupE2EESession, breaking decryption.
    // The echo-overwrite bug that originally motivated the wipe is now fixed by
    // the `msg.senderId != _myUserId` guard in _onReceived.
    final userId = _myUserId.isNotEmpty
        ? _myUserId
        : await _authService.getUserId();

    final cached = await _getCachedMessages(event.roomId).catchError((_) => <ChatMessage>[]);

    _myUserId = userId;

    final amIAdmin = event.room?.participants
            .any((p) => p.userId == _myUserId && p.isAdmin) ??
        false;

    // ── Emit cached messages IMMEDIATELY ──────────────────────────────────────
    // The user sees existing messages before the WS connects or any network
    // call completes. This is the first and most important state transition.
    //
    // For non-event rooms (DM, global, group, photo) the shared WS is owned by
    // ChatBackgroundService and is almost always already connected — there is no
    // separate connection phase. Reflect that reality immediately so the AppBar
    // never shows a spurious "Connecting…" label for rooms that are already live.
    // Event rooms always need their own per-room WS connection, so they start in
    // the connecting state.
    final bool wsAlreadyConnected = _ws.isConnected;
    emit(ChatRoomState(
      messages: cached.isNotEmpty ? _sorted(cached) : const [],
      isLoadingHistory: cached.isEmpty,
      isConnecting: !wsAlreadyConnected,
      isConnected: wsAlreadyConnected,
      isSyncing: true,
      myUserId: _myUserId,
      pendingShareUrl: event.shareUrl,
      room: event.room,
      amIAdmin: amIAdmin,
    ));

    // ── E2EE setup (DM only) — runs after the emit, never blocks it ───────────
    if (isDm) {
      _isDirectRoom = true;
      _proactiveSessionKey = null;
      _pendingEphemeralKey = null;
      _pendingOtpkId = null;
      _pendingBundleSpkId = null;
      // Default to re-key; _onKeyBundlesReceived cancels this if keys match cache.
      _needsRekey = true;
      _recipientId = event.room!.participants
          .where((p) => p.userId != _myUserId)
          .map((p) => p.userId)
          .firstOrNull;
      debugPrint('[E2EE] DM — recipientId: $_recipientId');

      // E2EE (key exchange + encryption) is not supported on web — messages are
      // sent and received as plaintext in the browser.
      //
      // None of this is gated on ChatConfig.e2eeEnabled. Publishing our bundle
      // and keeping one-time prekeys stocked is what lets *other* people encrypt
      // to *us* — so it has to keep working while clients on older builds, which
      // still encrypt, are out there. Turning it off would mean their messages
      // arrived undecryptable. Only our own outgoing encryption is switched off.
      if (!kIsWeb) {
        // Publish bundle in the background only if login hasn't already done so.
        // _e2ee.bundlePublished is a singleton flag set by LoginUseCase, so it
        // persists across all ChatRoomBloc factory instances in the same session.
        if (!_e2ee.bundlePublished) {
          _publishBundleInBackground();
        }

        _otpkPollTimer?.cancel();
        _otpkPollTimer = Timer.periodic(
          const Duration(seconds: 60),
          (_) => _replenishOtpksIfNeeded(),
        );
      }
    } else {
      _isDirectRoom = false;
      _recipientId = null;
    }

    _isGroupRoom = roomType == RoomType.group;

    try {
      // Fetch messages and fresh room data (for up-to-date adminOnly /
      // participants) in parallel — both are network calls, so running them
      // concurrently saves one full round-trip.
      final msgFuture = _getMessages(event.roomId);
      final roomFuture =
          _getRoom(event.roomId).then<ChatRoom?>((r) => r).catchError((_) => null);
      final fresh = await msgFuture;
      final freshRoom = await roomFuture;

      await _markAsRead(event.roomId);
      _bgService.onUnreadUpdate?.call();
      _bgService.onRoomRead?.call(event.roomId);

      final knownIds = state.messages.map((m) => m.id).toSet();
      final incoming = fresh.where((m) => !knownIds.contains(m.id)).toList();
      final merged = _sorted([...state.messages, ...incoming]);

      // Prefer the server's fresh room data over the potentially-stale object
      // passed at navigation time. This ensures adminOnly and participant list
      // are always current when entering any room.
      final updatedRoom = freshRoom ?? state.room;
      final updatedAmIAdmin = updatedRoom?.participants
              .any((p) => p.userId == _myUserId && p.isAdmin) ??
          state.amIAdmin;
      // Mute lives on our own participant row, so it arrives with the room.
      final updatedIsMuted =
          updatedRoom?.isMutedFor(_myUserId) ?? state.isMuted;

      emit(state.copyWith(
        messages: merged,
        isLoadingHistory: false,
        isSyncing: false,
        clearError: true,
        room: updatedRoom,
        amIAdmin: updatedAmIAdmin,
        isMuted: updatedIsMuted,
        // pendingShareUrl is preserved via copyWith (not cleared here)
      ));

      // Send bulk ack for all loaded messages so the server can notify senders
      // that we've read their messages.
      final latestMessage = merged
          .where((m) => !m.isLocal && m.senderId != _myUserId)
          .firstOrNull;
      if (latestMessage != null) {
        _ws.sendAck(event.roomId, latestMessage.id);
      }

      if (!kIsWeb) {
        // Scan REST history for X3DH headers BEFORE the WS connects.
        // REST messages still carry is_encrypted=true and the full X3DH header.
        // Processing them here stores the correct session key so that the guard
        // in _onKeyBundlesReceived (loadSessionKey != null) skips
        // _setupE2EESession — which would otherwise store a wrong proactive key.
        // Previously-processed messages are cached as is_encrypted=false and are
        // filtered out by knownIds, so their already-deleted OTPKs are never
        // re-used for a second (wrong) derivation.
        if (_isDirectRoom && _currentRoomId != null) {
          await _deriveKeyFromHistory(emit);
        }

        // Group rooms: fetch peer sender keys and distribute our own.
        if (_isGroupRoom && _currentRoomId != null) {
          await _setupGroupE2EE(_currentRoomId!, emit);
        }
      }
    } catch (e) {
      emit(state.copyWith(
        isLoadingHistory: false,
        isSyncing: false,
        errorMessage:
            state.messages.isEmpty ? 'Could not load messages.' : null,
      ));
    } finally {
      // Mobile DMs: attach WS listeners only AFTER _deriveKeyFromHistory has
      // stored the session key, so _onKeyBundlesReceived doesn't overwrite it
      // with a wrong proactive key. Non-DM rooms (and web DMs, which skip E2EE
      // entirely) already called _connectWsInBackground above; re-calling here
      // would cancel valid subscriptions and briefly leave no active listener.
      if (_isDirectRoom && !kIsWeb) {
        _connectWsInBackground(event.roomId);
      }
    }
  }

  void _connectWsInBackground(String roomId) {
    debugPrint('[ChatBloc] _connectWsInBackground for room: $roomId');
    _cancelWsSubscriptions();
    _wsConnectionSub?.cancel();
    _wsConnectionSub = null;

    // Always use the shared connection owned by ChatBackgroundService.
    if (_ws.isConnected) {
      // Explicitly subscribe so the server delivers messages for this room
      // even if the background service hasn't subscribed it yet (e.g. photo
      // rooms opened before connectAll runs, or rooms paused before subscription).
      _ws.subscribeRoom(roomId);
      _setupWsListeners(roomId);
      if (!isClosed) add(const _WsConnected());
      return;
    }

    _wsConnectionSub = _bgService.connectionEvents.listen((connected) {
      if (!connected || isClosed) return;
      _wsConnectionSub?.cancel();
      _wsConnectionSub = null;
      _ws.subscribeRoom(roomId);
      _setupWsListeners(roomId);
      if (!isClosed) add(const _WsConnected());
    });
  }

  void _cancelWsSubscriptions() {
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _wsKeyRotationSub?.cancel();
    _wsEditSub?.cancel();
    _wsDeleteSub?.cancel();
    _wsPinSub?.cancel();
    _wsUserJoinedSub?.cancel();
    _wsAdminGrantedSub?.cancel();
    _wsAdminRevokedSub?.cancel();
    _wsRoomSettingsSub?.cancel();
    _wsParticipantRemovedSub?.cancel();
    _wsRoomDeletedSub?.cancel();
    _wsSenderKeyDistSub?.cancel();
    _wsParticipantLeftSub?.cancel();
    _wsReadReceiptSub?.cancel();
    _wsTypingSub?.cancel();
    _wsErrorSub?.cancel();
    _wsMsgSub = null;
    _wsLikeSub = null;
    _wsPicLikeSub = null;
    _wsKeyBundlesSub = null;
    _wsParticipantKeySub = null;
    _wsKeyRotationSub = null;
    _wsEditSub = null;
    _wsDeleteSub = null;
    _wsPinSub = null;
    _wsUserJoinedSub = null;
    _wsAdminGrantedSub = null;
    _wsAdminRevokedSub = null;
    _wsRoomSettingsSub = null;
    _wsParticipantRemovedSub = null;
    _wsRoomDeletedSub = null;
    _wsSenderKeyDistSub = null;
    _wsParticipantLeftSub = null;
    _wsReadReceiptSub = null;
    _wsTypingSub = null;
    _wsErrorSub = null;
  }

  void _setupWsListeners(String roomId) {
    _cancelWsSubscriptions();

    _wsMsgSub = _ws.messages.listen(
      (msg) {
        debugPrint('[ChatBloc] _wsMsgSub RAW: id=${msg.id} roomId=${msg.roomId} senderId=${msg.senderId} isEncrypted=${msg.isEncrypted} contentLen=${msg.content.length}');
        if (!isClosed && msg.roomId == roomId) {
          debugPrint('[ChatBloc] _wsMsgSub ACCEPTED for room=$roomId — dispatching ChatRoomMessageReceived');
          add(ChatRoomMessageReceived(msg));
        } else if (!isClosed) {
          debugPrint('[ChatBloc] _wsMsgSub FILTERED: msgRoomId=${msg.roomId} currentRoom=$roomId id=${msg.id}');
        }
      },
      onDone: () {
        if (!isClosed) add(_WsDropped(fatal: _ws.hadFatalClose));
      },
      onError: (_) {
        if (!isClosed) add(const _WsDropped());
      },
    );

    _wsLikeSub = _ws.likeUpdates.listen(
      (update) {
        if (!isClosed) add(_LikeUpdateReceived(update));
      },
    );

    _wsPicLikeSub = _ws.pictureLikeUpdates.listen(
      (update) {
        if (!isClosed) add(_PictureLikeUpdateReceived(update));
      },
    );

    _wsKeyBundlesSub = _ws.keyBundleEvents.listen(
      (event) {
        if (!isClosed) add(_KeyBundlesReceived(event.bundles));
      },
    );

    _wsParticipantKeySub = _ws.participantKeyEvents.listen(
      (event) {
        if (!isClosed) {
          add(_ParticipantKeyAvailable(
              event.userId, event.identityKey, event.signedPreKey));
        }
      },
    );

    _wsKeyRotationSub = _ws.keyRotationEvents.listen(
      (event) {
        if (!isClosed) {
          add(_KeyRotationReceived(
              event.userId, event.identityKey, event.signedPreKey,
              registrationId: event.registrationId));
        }
      },
    );

    _wsEditSub = _ws.messageEditedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_MessageEdited(event.id, event.content, event.updatedAt));
        }
      },
    );

    _wsDeleteSub = _ws.messageDeletedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_MessageDeleted(event.id));
        }
      },
    );

    _wsPinSub = _ws.messagePinnedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_MessagePinned(event.pinned));
        }
      },
    );

    _wsUserJoinedSub = _ws.userJoinedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_WsUserJoined(event.userId, event.userName,
              userRole: event.userRole));
        }
      },
    );

    _wsAdminGrantedSub = _ws.adminGrantedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_AdminGranted(event.userId, event.grantedBy));
        }
      },
    );

    _wsAdminRevokedSub = _ws.adminRevokedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_AdminRevoked(event.userId, event.revokedBy));
        }
      },
    );

    _wsRoomSettingsSub = _ws.roomSettingsEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_RoomSettingsUpdated(event.updatedBy,
              adminOnly: event.adminOnly, name: event.name));
        }
      },
    );

    _wsParticipantRemovedSub = _ws.participantRemovedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_ParticipantRemoved(event.userId, event.removedBy));
        }
      },
    );

    _wsRoomDeletedSub = _ws.roomDeletedEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_RoomDeleted(event.deletedBy));
        }
      },
    );

    _wsSenderKeyDistSub = _ws.senderKeyDistributionEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_GroupSenderKeyReceived(event.senderId, event.encryptedKey));
        }
      },
    );

    _wsParticipantLeftSub = _ws.participantLeftEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId) {
          add(_ParticipantLeft(event.userId));
        }
      },
    );

    _wsReadReceiptSub = _ws.readReceiptEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId && event.readerId != _myUserId) {
          add(_ReadReceiptReceived(
            readerId: event.readerId,
            upToMessageId: event.upToMessageId,
            messageId: event.messageId,
          ));
        }
      },
    );

    _wsTypingSub = _ws.typingEvents.listen(
      (event) {
        if (!isClosed && event.roomId == roomId && event.userId != _myUserId) {
          add(_TypingReceived(
            userId: event.userId,
            userName: event.userName,
            isTyping: event.isTyping,
          ));
        }
      },
    );

    // Surface server error frames for this room (or general ones without a
    // room_id, e.g. "Only admins can send messages in this room").
    _wsErrorSub = _ws.errorEvents.listen(
      (event) {
        // Errors for the room on screen, general ones, and refusals from a
        // room this bloc has just forwarded into — see [_forwardTargets].
        final forRoom = event.roomId == null ||
            event.roomId == roomId ||
            _forwardTargets.contains(event.roomId);
        if (!isClosed && forRoom) {
          add(_WsServerError(event.message));
        }
      },
    );

    debugPrint('[ChatBloc] WS listeners attached for room $roomId');
  }

  void _onWsConnected(_WsConnected event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnected: true,
      isConnecting: false,
      clearError: true,
    ));

    // Re-send the read ack now that there is actually a socket to send it on.
    //
    // _onJoined acks right after the REST history load, but a mobile DM
    // deliberately delays connecting until _deriveKeyFromHistory has stored the
    // E2EE session key. That ack is therefore written to a closed socket, and
    // _sendRaw drops it silently — no error, no retry. The effect is that
    // everything already on screen when a DM is opened is never acknowledged,
    // so the sender's ticks stay grey no matter how long you look at them.
    // Only messages that arrive *while* the room is open ever went blue.
    //
    // Safe to repeat: mark_read is an idempotent upsert and returns only
    // genuinely new rows, so a redundant ack writes nothing and broadcasts
    // nothing.
    _ackLatestPeerMessage();

    // Tell the server this room is on screen, so it does not notify us about
    // the conversation we are visibly reading. Sent on every connect because a
    // reconnect is a new socket, and focus is tracked per socket.
    if (_currentRoomId != null) _ws.sendFocus(_currentRoomId);

    // The first connect's history is loaded by _onJoined. Any later connect is
    // a reconnect — the socket doesn't replay, so refetch to backfill anything
    // that arrived while we were offline.
    if (_didInitialConnect) {
      if (!isClosed) add(const _HistoryRefetchRequested());
    } else {
      _didInitialConnect = true;
    }
  }

  /// Acknowledge the newest message from anyone other than me.
  ///
  /// A bulk ack covers everything up to that message, so one frame settles the
  /// whole room. [state.messages] is sorted newest-first, so the first match is
  /// the cursor.
  void _ackLatestPeerMessage() {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    final latest = state.messages
        .where((m) => !m.isLocal && m.senderId != _myUserId)
        .firstOrNull;
    if (latest != null) _ws.sendAck(roomId, latest.id);
  }

  /// Refetch room history after a reconnect and merge in anything new.
  Future<void> _onHistoryRefetch(
      _HistoryRefetchRequested event, Emitter<ChatRoomState> emit) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      final fresh = await _getMessages(roomId);
      if (isClosed) return;
      final knownIds = state.messages.map((m) => m.id).toSet();
      final incoming = fresh.where((m) => !knownIds.contains(m.id)).toList();
      if (incoming.isEmpty) return;
      emit(state.copyWith(
          messages: _sorted([...state.messages, ...incoming])));

      // Mark the backfilled messages read + ack the latest peer message.
      await _markAsRead(roomId);
      _bgService.onUnreadUpdate?.call();
      _bgService.onRoomRead?.call(roomId);
      final latest = _sorted(incoming)
          .where((m) => !m.isLocal && m.senderId != _myUserId)
          .firstOrNull;
      if (latest != null) _ws.sendAck(roomId, latest.id);
    } catch (_) {
      // Backfill is best-effort; live frames keep the room current.
    }
  }

  void _onUrlStaged(ChatRoomUrlStaged event, Emitter<ChatRoomState> emit) {
    // Always add the optimistic message immediately so the user sees it right
    // away regardless of WS state. The actual send happens now (if connected)
    // or in _onWsConnected (if still connecting).
    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      roomId: _currentRoomId ?? '',
      senderId: _myUserId,
      senderRole: ChatConfig.roleClient,
      content: '',
      imageUrl: event.imageUrl,
      createdAt: DateTime.now().toUtc(),
      isLocal: true,
    );
    emit(state.copyWith(messages: _sorted([optimistic, ...state.messages])));
    _cacheAndAnnounce(optimistic);

    if (_ws.isConnected) {
      // WS already up — send immediately.
      _ws.send(null, imageUrl: event.imageUrl, roomId: _currentRoomId);
    } else {
      // WS not ready yet — store URL; _onWsConnected will send it.
      emit(state.copyWith(pendingShareUrl: event.imageUrl));
    }
  }

  void _onWsFailed(_WsFailed event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnected: false,
      isConnecting: true,
    ));
    if (_currentRoomId != null) _connectWsInBackground(_currentRoomId!);
  }

  void _onWsDropped(_WsDropped event, Emitter<ChatRoomState> emit) {
    if (event.fatal) {
      debugPrint('[ChatBloc] WS fatal close — will not reconnect');
      emit(state.copyWith(
        isConnected: false,
        isConnecting: false,
        errorMessage: 'Connection closed. Please restart the app.',
      ));
      return;
    }

    debugPrint('[ChatBloc] WS dropped — waiting for background service to reconnect');
    emit(state.copyWith(isConnected: false, isConnecting: true));
    if (_currentRoomId != null) _connectWsInBackground(_currentRoomId!);
  }

  void _onWsGaveUp(_WsGaveUp event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnecting: false,
      isConnected: false,
      errorMessage: 'Connection lost. Pull down to refresh.',
    ));
  }

  Future<void> _onSent(
    ChatRoomMessageSent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_ws.isConnected) {
      emit(state.copyWith(
          errorMessage: 'Not connected — please wait or retry.'));
      return;
    }

    // Sending is the end of typing. The composer is cleared programmatically
    // after this, and a programmatic clear fires no `onChanged`, so nothing
    // else in the app was ever going to say so — the peer saw the message
    // arrive with "typing…" still sitting under it.
    _stopTyping();

    final content = event.content?.trim();
    final pendingPath = state.pendingImagePath;
    final pendingMimeType = state.pendingMimeType;
    final pendingIsVideo = state.pendingIsVideo;
    final pendingUrl = state.pendingShareUrl;
    final hasText = content != null && content.isNotEmpty;
    final hasLocalImage = pendingPath != null;
    final hasUrlImage = pendingUrl != null;

    if (!hasText && !hasLocalImage && !hasUrlImage) return;

    final replyPreview =
        event.replyToId != null ? _buildReplyPreview(event.replyToId!) : null;

    // Shared gallery URL — already uploaded, send directly without re-uploading.
    if (hasUrlImage && !hasLocalImage) {
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final optimistic = ChatMessage(
        id: tempId,
        roomId: _currentRoomId ?? '',
        senderId: _myUserId,
        senderRole: ChatConfig.roleClient,
        content: content ?? '',
        imageUrl: pendingUrl,
        replyToId: event.replyToId,
        replyPreview: replyPreview,
        createdAt: DateTime.now().toUtc(),
        isLocal: true,
      );
      emit(state.copyWith(
        messages: _sorted([optimistic, ...state.messages]),
        clearPendingShareUrl: true,
        clearReply: true,
      ));
      // Before the send, not after: the inbox tile should change in the same
      // frame as the bubble, not once the network has had its turn.
      _cacheAndAnnounce(optimistic);
      await _encryptAndSend(
        content: hasText ? content : null,
        imageUrl: pendingUrl,
        replyToId: event.replyToId,
        emit: emit,
      );
      return;
    }

    if (hasLocalImage) {
      // Clear the staged image immediately so the user can't double-send.
      emit(state.copyWith(
        isUploadingImage: true,
        clearPendingImage: true,
        clearReply: true,
      ));

      try {
        final imageUrl = await _uploadImage(File(pendingPath), mimeType: pendingMimeType);
        final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';

        final optimistic = ChatMessage(
          id: tempId,
          roomId: _currentRoomId ?? '',
          senderId: _myUserId,
          senderRole: ChatConfig.roleClient,
          content: content ?? '',
          imageUrl: imageUrl,
          isVideo: pendingIsVideo,
          replyToId: event.replyToId,
          replyPreview: replyPreview,
          createdAt: DateTime.now().toUtc(),
          isLocal: true,
        );

        emit(state.copyWith(
          isUploadingImage: false,
          messages: _sorted([optimistic, ...state.messages]),
        ));
        _cacheAndAnnounce(optimistic);

        await _encryptAndSend(
          content: hasText ? content : null,
          imageUrl: imageUrl,
          isVideo: pendingIsVideo,
          replyToId: event.replyToId,
          emit: emit,
        );
      } catch (e) {
        // Restore the pending media so the user can retry, and say what
        // actually went wrong — the server distinguishes "too large" from
        // "unsupported type" from "storage not configured", and all three used
        // to arrive here as the same sentence.
        debugPrint('[ChatBloc] media upload failed: $e');
        emit(state.copyWith(
          isUploadingImage: false,
          pendingImagePath: pendingPath,
          pendingMimeType: pendingMimeType,
          pendingIsVideo: pendingIsVideo,
          errorMessage: uploadErrorText(e, isVideo: pendingIsVideo),
        ));
      }
    } else {
      // Text-only message.
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      final optimistic = ChatMessage(
        id: tempId,
        roomId: _currentRoomId ?? '',
        senderId: _myUserId,
        senderRole: ChatConfig.roleClient,
        content: content!,
        replyToId: event.replyToId,
        replyPreview: replyPreview,
        createdAt: DateTime.now().toUtc(),
        isLocal: true,
      );

      emit(state.copyWith(
        messages: _sorted([optimistic, ...state.messages]),
        clearReply: true,
      ));
      _cacheAndAnnounce(optimistic);

      await _encryptAndSend(
        content: content,
        replyToId: event.replyToId,
        emit: emit,
      );
    }
  }

  /// Caches an outgoing message and tells the inbox about it in the same
  /// breath, so the room's tile shows what was just sent the moment it is sent
  /// — not after the server echo, and not after the next rooms sync.
  ///
  /// The confirmed copy is announced again from [_onReceived] when the echo
  /// lands; it carries the same text, so the tile does not visibly change.
  void _cacheAndAnnounce(ChatMessage msg) {
    _cacheMessage(msg).catchError((_) {});
    _bgService.reportOpenRoomMessage(msg);
  }

  /// Encrypts [content] (when non-empty) for DM rooms and sends over the WS.
  /// [imageUrl], if provided, is included in the payload alongside the encrypted text.
  /// Falls back to plaintext when not in a DM room or when no session key is available.
  Future<void> _encryptAndSend({
    String? content,
    String? imageUrl,
    bool isVideo = false,
    String? replyToId,
    required Emitter<ChatRoomState> emit,
  }) async {
    final hasText = content != null && content.isNotEmpty;

    // Send plaintext when:
    //   • Encryption is switched off (ChatConfig.e2eeEnabled), OR
    //   • Running on web (encryption never supported in the browser), OR
    //   • A web participant is present in this room (mobile must downgrade so
    //     the web client can read the messages).
    //
    // The flag joins the two conditions that were already here rather than
    // getting its own branch: "send it in the clear" is one behaviour with
    // several reasons, and everything below is the encrypted path.
    final roomId = _currentRoomId;
    final hasWebParticipant =
        !kIsWeb && roomId != null && !_bgService.canEncryptRoom(roomId);
    if (!ChatConfig.e2eeEnabled || kIsWeb || hasWebParticipant) {
      debugPrint('[E2EE] send plaintext — e2eeEnabled=${ChatConfig.e2eeEnabled} '
          'kIsWeb=$kIsWeb hasWebParticipant=$hasWebParticipant');
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo,
          replyToId: replyToId, roomId: roomId);
      return;
    }

    debugPrint('[E2EE] send — isDirectRoom: $_isDirectRoom, recipientId: $_recipientId, needsRekey: $_needsRekey');

    if (_isGroupRoom) {
      await _encryptAndSendGroup(
        content: content,
        imageUrl: imageUrl,
        isVideo: isVideo,
        replyToId: replyToId,
      );
      return;
    }

    if (!_isDirectRoom || _recipientId == null || !hasText) {
      debugPrint('[E2EE] Not a DM, no recipient, or no text — sending plaintext');
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo, replyToId: replyToId, roomId: _currentRoomId);
      return;
    }

    try {
      var sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
      String? ephemeralKey;
      String? myIdentityKey;
      int? otpkId;
      int? bundleSpkId;

      if (_needsRekey) {
        _needsRekey = false;
        debugPrint('[E2EE] Re-key: fetching bundle for fresh X3DH');
        final bundle = await _keyDs.fetchBundle(_recipientId!);
        if (bundle != null) {
          final session = await _e2ee.createSendingSession(bundle);
          sessionKey = session.sessionKey;
          await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
          await _e2ee.storeCachedBundle(
            _recipientId!,
            identityKey: bundle.identityKey,
            signedPreKeyId: bundle.signedPreKeyId,
          );
          ephemeralKey = session.ephemeralPublicKey;
          otpkId = session.otpkId;
          bundleSpkId = bundle.signedPreKeyId;
          myIdentityKey = await _e2ee.identityPublicKey();
          _pendingEphemeralKey = null;
          _pendingOtpkId = null;
          _pendingBundleSpkId = null;
          _proactiveSessionKey = null;
          debugPrint('[E2EE] Re-key complete (otpkId: $otpkId)');
        } else if (sessionKey == null) {
          debugPrint('[E2EE] Re-key: no bundle and no key — sending plaintext');
          _ws.send(content, imageUrl: imageUrl, isVideo: isVideo, replyToId: replyToId, roomId: _currentRoomId);
          return;
        } else {
          debugPrint('[E2EE] Re-key: no bundle — reusing existing key (degraded)');
        }
      } else if (_pendingEphemeralKey != null) {
        sessionKey = _proactiveSessionKey!;
        await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
        ephemeralKey = _pendingEphemeralKey;
        otpkId = _pendingOtpkId;
        bundleSpkId = _pendingBundleSpkId;
        myIdentityKey = await _e2ee.identityPublicKey();
        _pendingEphemeralKey = null;
        _pendingOtpkId = null;
        _pendingBundleSpkId = null;
        _proactiveSessionKey = null;
        debugPrint('[E2EE] Using pre-established session (proactive X3DH)');
        await _redecryptEncryptedMessages(emit, sessionKey);
      } else if (sessionKey == null) {
        debugPrint('[E2EE] No session key — fetching recipient bundle for $_recipientId');
        final recipientBundle = await _keyDs.fetchBundle(_recipientId!);
        if (recipientBundle == null) {
          debugPrint('[E2EE] Recipient has no bundle — sending plaintext');
          _ws.send(content, imageUrl: imageUrl, isVideo: isVideo, replyToId: replyToId, roomId: _currentRoomId);
          return;
        }
        debugPrint('[E2EE] Got recipient bundle — running X3DH');
        final session = await _e2ee.createSendingSession(recipientBundle);
        sessionKey = session.sessionKey;
        ephemeralKey = session.ephemeralPublicKey;
        otpkId = session.otpkId;
        bundleSpkId = recipientBundle.signedPreKeyId;
        myIdentityKey = await _e2ee.identityPublicKey();
        await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
        await _e2ee.storeCachedBundle(
          _recipientId!,
          identityKey: recipientBundle.identityKey,
          signedPreKeyId: recipientBundle.signedPreKeyId,
        );
        debugPrint('[E2EE] Session established (otpkId: $otpkId)');
      } else {
        debugPrint('[E2EE] Reusing cached session key');
      }

      final keyHex = sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final encrypted = await _e2ee.encrypt(sessionKey, content);
      debugPrint('[E2EE] Encrypted OK (session: ${ephemeralKey != null ? "new X3DH" : "cached"}, keyPrefix=$keyHex) — sending over WS');
      _ws.sendEncrypted(
        ciphertext: encrypted.ciphertext,
        iv: encrypted.iv,
        imageUrl: imageUrl,
        isVideo: isVideo,
        ephemeralKey: ephemeralKey,
        senderIdentityKey: myIdentityKey,
        otpkId: otpkId,
        senderSpkId: bundleSpkId,
        replyToId: replyToId,
        roomId: _currentRoomId,
      );
    } catch (e) {
      debugPrint('[E2EE] Encrypt failed, sending plaintext: $e');
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo, replyToId: replyToId, roomId: _currentRoomId);
    }
  }

  /// Stage the picked image/video — no upload yet.
  void _onImagePicked(
    ChatRoomImagePicked event,
    Emitter<ChatRoomState> emit,
  ) {
    emit(state.copyWith(
      pendingImagePath: event.filePath,
      pendingMimeType: event.mimeType,
      pendingIsVideo: event.isVideo,
    ));
  }

  void _onImageCleared(
    ChatRoomImageCleared event,
    Emitter<ChatRoomState> emit,
  ) {
    emit(state.copyWith(clearPendingImage: true, clearPendingShareUrl: true));
  }

  void _onReplySet(ChatRoomReplySet event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      replyingTo: event.message,
      clearReply: event.message == null,
    ));
  }

  void _onLikeToggled(ChatRoomLikeToggled event, Emitter<ChatRoomState> emit) {
    if (!_ws.isConnected) return;
    if (state.isEventLiked) {
      _ws.sendUnlike(event.eventId, roomId: _currentRoomId);
    } else {
      _ws.sendLike(event.eventId, roomId: _currentRoomId);
    }
  }

  void _onLikeUpdateReceived(
      _LikeUpdateReceived event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      eventLikes: event.update.likes,
      eventDislikes: event.update.dislikes,
      isEventLiked: event.update.liked,
      isEventDisliked: event.update.disliked,
    ));
  }

  void _onPictureLikeToggled(
      ChatRoomPictureLikeToggled event, Emitter<ChatRoomState> emit) {
    if (!_ws.isConnected) return;
    if (state.isPictureLiked) {
      _ws.sendPictureUnlike(event.pictureId, roomId: _currentRoomId);
    } else {
      _ws.sendPictureLike(event.pictureId, roomId: _currentRoomId);
    }
    // Optimistic update — WS echo will confirm the real value.
    final wasLiked = state.isPictureLiked;
    emit(state.copyWith(
      isPictureLiked: !wasLiked,
      pictureLikes: (state.pictureLikes ?? 0) + (wasLiked ? -1 : 1),
    ));
  }

  void _onPictureLikeUpdateReceived(
      _PictureLikeUpdateReceived event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      pictureLikes: event.update.likes,
      isPictureLiked: event.update.liked,
    ));
  }

  Future<void> _onReceived(
    ChatRoomMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) async {
    var msg = event.message;

    // Their message is here, so they have stopped typing it. Emitted before any
    // of the decryption work below, because the indicator has to go the moment
    // the bubble appears — not whenever that finishes.
    final cleared = _typingCleared(msg.senderId);
    if (cleared != null) emit(state.copyWith(typingUsers: cleared));

    debugPrint('[ChatRoomBloc] _onReceived: msgId=${msg.id}'
        ' roomId=${msg.roomId}'
        ' senderId=${msg.senderId}'
        ' isEncrypted=${msg.isEncrypted}'
        ' isLocal=${msg.isLocal}'
        ' contentLen=${msg.content.length}'
        ' currentRoom=$_currentRoomId');

    if (_isDirectRoom) {
      debugPrint('[E2EE] onReceived: msgId=${msg.id}'
          ' isEncrypted=${msg.isEncrypted}'
          ' hasIv=${msg.iv != null}'
          ' hasEphKey=${msg.ephemeralKey != null && msg.ephemeralKey!.isNotEmpty}'
          ' senderId=${msg.senderId}'
          ' myUserId=$_myUserId');
    }

    // On web: encrypted messages from mobile clients cannot be decrypted.
    // Replace ciphertext with a human-readable notice so the UI stays clean.
    if (kIsWeb && msg.isEncrypted) {
      msg = msg.copyWith(
        content: '🔒 Encrypted message — open in the app to read',
        isEncrypted: false,
      );
    }

    // Decrypt group E2EE messages using the sender's SenderKey.
    // Own echoes (senderId == _myUserId) are decrypted with our own sender key
    // so the plaintext matches the optimistic placeholder and replaces it.
    if (!kIsWeb && _isGroupRoom && msg.isEncrypted && msg.content.isNotEmpty &&
        msg.iv != null && _currentRoomId != null) {
      final isOwnEcho = msg.senderId == _myUserId;
      final senderKey = isOwnEcho
          ? await _e2ee.loadGroupSenderKey(_currentRoomId!)
          : await _e2ee.loadPeerGroupSenderKey(_currentRoomId!, msg.senderId);
      debugPrint('[GroupE2EE] decrypt: msgId=${msg.id}'
          ' isOwnEcho=$isOwnEcho'
          ' isGroupRoom=$_isGroupRoom'
          ' keyLoaded=${senderKey != null}');
      if (senderKey != null) {
        try {
          final plaintext =
              await _e2ee.decrypt(senderKey, msg.content, msg.iv!);
          msg = msg.copyWith(content: plaintext, isEncrypted: false);
          debugPrint('[GroupE2EE] Decrypted OK msgId=${msg.id}');
        } catch (e) {
          debugPrint('[GroupE2EE] Decrypt failed for ${msg.id}: $e');
          msg = msg.copyWith(content: '', isEncrypted: false);
        }
      } else {
        debugPrint('[GroupE2EE] No sender key for ${msg.senderId} — will retry when key arrives');
        // Keep isEncrypted=true so _redecryptGroupMessages can decrypt when key arrives.
        if (!isOwnEcho) {
          _distributeSenderKeyToMember(msg.senderId).catchError((_) {});
        }
      }
    }

    // Decrypt E2EE messages — only in direct rooms, never in global/event/photo rooms,
    // and never on web (no E2EE key material available in the browser).
    final shouldDecrypt = !kIsWeb && _isDirectRoom && msg.isEncrypted && msg.content.isNotEmpty && msg.iv != null && _currentRoomId != null;
    debugPrint('[ChatRoomBloc] _onReceived decrypt-gate:'
        ' isDirectRoom=$_isDirectRoom'
        ' isEncrypted=${msg.isEncrypted}'
        ' hasContent=${msg.content.isNotEmpty}'
        ' hasIv=${msg.iv != null}'
        ' → willDecrypt=$shouldDecrypt');
    if (shouldDecrypt) {
      // Stale sender key — identity key no longer matches the server's current
      // bundle for this sender. Decline to decrypt: the message may have been
      // sent by an old/compromised key. Delete our session and rekey on next
      // send so both sides re-synchronise.
      if (msg.stale == true) {
        await _e2ee.deleteSessionKey(_currentRoomId!);
        _needsRekey = true;
        debugPrint('[E2EE] stale flag set for msg ${msg.id} — session cleared, rekey on next send');
        msg = msg.copyWith(content: '', isEncrypted: false);
      } else {
      try {
        Uint8List? sessionKey;
        bool alreadyDecrypted = false;

        // First message after X3DH carries the sender's ephemeral key and
        // identity key — use them to derive the shared session key.
        // IMPORTANT: skip X3DH for echoes of our own messages. The server
        // relays our encrypted message back to us with the same ephemeral_key
        // header. Running deriveReceivingKey against our own keys produces a
        // garbage key that overwrites the correct session key and breaks all
        // subsequent decryption in both directions.
        if (msg.ephemeralKey != null &&
            msg.ephemeralKey!.isNotEmpty &&
            msg.senderIdentityKey != null &&
            msg.senderIdentityKey!.isNotEmpty &&
            msg.senderId != _myUserId) {
          // First message of a new X3DH session from the other party.
          // senderSpkId tells us which of our SPKs the sender used; if it
          // differs from our current SPK, try the prev SPK first.
          await _e2ee.storeIdentityKey(msg.senderId, msg.senderIdentityKey!);
          final mySpkId = await _e2ee.currentSpkId();
          final tryPrevFirst = msg.senderSpkId != null &&
              mySpkId != null &&
              msg.senderSpkId != mySpkId;
          final x3dhResult = await _deriveAndDecryptX3DH(
            senderIdentityKey: msg.senderIdentityKey!,
            senderEphemeralKey: msg.ephemeralKey!,
            otpkId: msg.otpkId,
            ciphertext: msg.content,
            iv: msg.iv!,
            tryPrevSpkFirst: tryPrevFirst,
          );
          if (x3dhResult != null) {
            sessionKey = x3dhResult.$1;
            await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
            // CRITICAL: clear any pending proactive X3DH state.
            // If we had run proactive setup, _pendingEphemeralKey was set to an
            // ephemeral key that is associated with _our_ proactive session key
            // (K_proactive_ours), NOT with the session key we just derived from
            // the other side (K_derived). If we sent a message with
            // _pendingEphemeralKey as the header while encrypting with K_derived,
            // the receiver would derive K_proactive_ours from that header and
            // fail to decrypt. Clearing here ensures the first send after this
            // uses no header and just re-uses K_derived.
            _pendingEphemeralKey = null;
            _pendingOtpkId = null;
            _proactiveSessionKey = null;
            debugPrint('[E2EE] Receiver: session key derived via X3DH (otpkId: ${msg.otpkId}), proactive state cleared');
            msg = msg.copyWith(content: x3dhResult.$2, isEncrypted: false);
            alreadyDecrypted = true;
            // Re-decrypt any encrypted messages already in state (from REST
            // history) that arrived before the session key was established.
            await _redecryptEncryptedMessages(emit, sessionKey);
          } else {
            debugPrint('[E2EE] X3DH receive failed (both SPKs) for msg ${msg.id}');
            msg = msg.copyWith(content: '', isEncrypted: false);
            alreadyDecrypted = true;
          }
        } else {
          // Own echo or subsequent message — reuse the stored session key.
          sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
          final isOwnEcho = msg.senderId == _myUserId;
          final hasEphKey = msg.ephemeralKey != null && msg.ephemeralKey!.isNotEmpty;
          debugPrint('[E2EE] Receiver: reusing stored session key'
              ' | isOwnEcho=$isOwnEcho'
              ' | hasEphKey=$hasEphKey'
              ' | keyLoaded=${sessionKey != null}'
              ' | keyBytes=${sessionKey != null ? sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, "0")).join() : "null"}'
              ' | msgId=${msg.id}');
        }

        if (!alreadyDecrypted) {
          if (sessionKey != null) {
            final plaintext = await _e2ee.decrypt(sessionKey, msg.content, msg.iv!);
            debugPrint('[E2EE] Decrypted OK: "${plaintext.length > 30 ? plaintext.substring(0, 30) : plaintext}..."');
            msg = msg.copyWith(content: plaintext, isEncrypted: false);
          } else {
            debugPrint('[E2EE] No session key yet — cannot decrypt msg ${msg.id}');
            msg = msg.copyWith(content: '', isEncrypted: false);
          }
        }
      } catch (e) {
        debugPrint('[E2EE] Decrypt failed for msg ${msg.id}: $e');
        // MAC error on an ongoing message most likely means the sender used
        // a key from a previous session that arrived in-flight while we were
        // establishing a new one. Deleting the stored key here triggers
        // proactive X3DH → which stores another mismatched key → more MAC
        // errors → endless loop.
        //
        // Instead: keep the stored key (so subsequent messages from the other
        // side that DO use the correct key can still decrypt), but set
        // _needsRekey so the NEXT outbound message carries a fresh X3DH
        // header. That forces both sides to converge on a new shared key
        // without destroying the one that may still be valid.
        final isOngoing = msg.ephemeralKey == null || msg.ephemeralKey!.isEmpty;
        final isFromOther = msg.senderId != _myUserId;
        if (isOngoing && isFromOther) {
          _needsRekey = true;
          debugPrint('[E2EE] MAC error on ongoing message — scheduling rekey on next send (key kept)');
        }
        msg = msg.copyWith(content: '', isEncrypted: false);
      }
      } // end else (not stale)
    }

    // Find the optimistic placeholder this message is confirming (if any).
    final optimistic = state.messages.where((m) =>
        m.isLocal &&
        m.content == msg.content &&
        m.imageUrl == msg.imageUrl).firstOrNull;

    // If the server didn't echo is_video, inherit the flag from the optimistic
    // message so the cached version stays correct across sessions.
    if (optimistic != null && optimistic.isVideo && !msg.isVideo) {
      msg = msg.copyWith(isVideo: true);
    }

    // Remove matching optimistic placeholder.
    final updated = state.messages
        .where((m) => !(m.isLocal &&
            m.content == msg.content &&
            m.imageUrl == msg.imageUrl))
        .toList();

    final hasOptimistic = optimistic != null;
    debugPrint('[ChatRoomBloc] _onReceived: optimistic match=$hasOptimistic'
        ' (optimisticId=${optimistic?.id ?? "none"})'
        ' stateBeforeSize=${state.messages.length}'
        ' afterRemoveSize=${updated.length}');

    if (updated.any((m) => m.id == msg.id)) {
      debugPrint('[ChatRoomBloc] _onReceived: DUPLICATE — msgId=${msg.id} already in state, skipping insert+badge');
      return;
    }

    debugPrint('[ChatRoomBloc] _onReceived: emitting with msgId=${msg.id} hasOptimisticPlaceholder=$hasOptimistic finalListSize=${updated.length + 1}');
    emit(state.copyWith(messages: _sorted([msg, ...updated])));

    // Await the DB write so the sequence is: insert → mark-read → badge.
    // A fire-and-forget here races with close() → _bgService.resume(), which
    // unpauses the room so BgService can save new messages. If _markAsRead ran
    // after resume(), it would mark those freshly-saved messages as read and
    // permanently zero the unread badge.
    final roomId = _currentRoomId;
    await _cacheMessage(msg).catchError((_) {});
    // Tell the inbox what the last message in this room now is. The room is
    // paused while it's open, so ChatBackgroundService never sees this one —
    // without this the tile keeps the previous preview until the next sync.
    _bgService.reportOpenRoomMessage(msg);
    // Skip mark-read if the BLoC was closed while we were writing to the DB
    // (i.e. the user navigated away). close() already called _bgService.resume;
    // any message BgService saves between now and here must stay unread.
    if (!isClosed && roomId != null) {
      await _markAsRead(roomId).catchError((_) {});
      _bgService.onRoomRead?.call(roomId);
      // Ack this message so the sender sees their read receipt.
      if (msg.senderId != _myUserId && !msg.isLocal) {
        _ws.sendAck(roomId, msg.id);
      }
    }
    _bgService.onUnreadUpdate?.call();
  }

  /// Derives the session key and decrypts the first X3DH message from the
  /// other party, with a fallback to the archived previous SPK for messages
  /// that were sent during a rotation window.
  ///
  /// The OTPK private key is NOT deleted until the correct SPK is confirmed
  /// (via successful AES-GCM decryption), so both attempts have access to DH4.
  ///
  /// Returns a (sessionKey, plaintext) record on success, or null on failure.
  Future<(Uint8List, String)?> _deriveAndDecryptX3DH({
    required String senderIdentityKey,
    required String senderEphemeralKey,
    int? otpkId,
    required String ciphertext,
    required String iv,
    bool tryPrevSpkFirst = false,
  }) async {
    // Never delete the OTPK until the correct SPK is confirmed — both
    // attempts need access to DH4. Delete explicitly after success.

    if (!tryPrevSpkFirst) {
      // Standard path: try the current SPK first.
      try {
        final key = await _e2ee.deriveReceivingKey(
          senderIdentityKey: senderIdentityKey,
          senderEphemeralKey: senderEphemeralKey,
          consumedOtpkId: otpkId,
          deleteConsumedOtpk: false,
        );
        final plain = await _e2ee.decrypt(key, ciphertext, iv);
        if (otpkId != null) await _e2ee.deleteOtpk(otpkId);
        return (key, plain);
      } catch (_) {}
    }

    // Try the archived previous SPK (sender's senderSpkId hint, or current failed).
    try {
      final key = await _e2ee.deriveReceivingKey(
        senderIdentityKey: senderIdentityKey,
        senderEphemeralKey: senderEphemeralKey,
        consumedOtpkId: otpkId,
        usePrevSPK: true,
        deleteConsumedOtpk: false,
      );
      final plain = await _e2ee.decrypt(key, ciphertext, iv);
      if (otpkId != null) await _e2ee.deleteOtpk(otpkId);
      debugPrint('[E2EE] Decrypted using previous SPK (rotation window fallback)');
      return (key, plain);
    } catch (_) {}

    if (tryPrevSpkFirst) {
      // Prev SPK hinted but failed — fall back to the current SPK.
      try {
        final key = await _e2ee.deriveReceivingKey(
          senderIdentityKey: senderIdentityKey,
          senderEphemeralKey: senderEphemeralKey,
          consumedOtpkId: otpkId,
          deleteConsumedOtpk: false,
        );
        final plain = await _e2ee.decrypt(key, ciphertext, iv);
        if (otpkId != null) await _e2ee.deleteOtpk(otpkId);
        return (key, plain);
      } catch (e) {
        debugPrint('[E2EE] _deriveAndDecryptX3DH: all SPK attempts failed — $e');
        return null;
      }
    }

    debugPrint('[E2EE] _deriveAndDecryptX3DH: both SPKs failed');
    return null;
  }

  /// After the session key is established for the first time, go through
  /// any encrypted messages already in state (typically from the REST history
  /// fetch that runs in _onJoined before the WS connects) and decrypt them.
  Future<void> _redecryptEncryptedMessages(
    Emitter<ChatRoomState> emit,
    Uint8List sessionKey,
  ) async {
    final toDecrypt = state.messages
        .where((m) => m.isEncrypted && m.content.isNotEmpty && m.iv != null)
        .toList();
    if (toDecrypt.isEmpty) return;
    debugPrint('[E2EE] Re-decrypting ${toDecrypt.length} historical message(s)');

    final decryptedMap = <String, ChatMessage>{};
    for (final m in toDecrypt) {
      try {
        final plaintext = await _e2ee.decrypt(sessionKey, m.content, m.iv!);
        final updated = m.copyWith(content: plaintext, isEncrypted: false);
        decryptedMap[m.id] = updated;
        _cacheMessage(updated).catchError((_) {});
      } catch (e) {
        debugPrint('[E2EE] Re-decrypt failed for ${m.id}: $e');
        decryptedMap[m.id] = m.copyWith(content: '', isEncrypted: false);
      }
    }

    final updatedMessages = state.messages
        .map((m) => decryptedMap[m.id] ?? m)
        .toList();
    emit(state.copyWith(messages: _sorted(updatedMessages)));
  }

  /// Scans already-loaded history for an X3DH opener from the other party
  /// and, if found, derives and stores the session key before the WebSocket
  /// connects. This ensures [_onKeyBundlesReceived] finds an existing session
  /// key and skips the proactive X3DH setup (which would store a mismatched
  /// key), and re-decrypts any historically-encrypted messages in state.
  Future<void> _deriveKeyFromHistory(Emitter<ChatRoomState> emit) async {
    // If a session key already exists, don't re-derive — the OTPK is
    // single-use and was deleted after the first derivation, so a second pass
    // would produce a wrong key. But DO decrypt any encrypted messages that
    // just arrived from the REST history load and aren't yet in plaintext
    // (e.g. messages received while the app was closed and not yet cached).
    final existingKey = await _e2ee.loadSessionKey(_currentRoomId!);
    final encryptedInHistory = state.messages.where((m) => m.isEncrypted).length;
    final totalInHistory = state.messages.length;
    if (existingKey != null) {
      final kHex = existingKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[E2EE] _deriveKeyFromHistory: stored key found (keyPrefix=$kHex) — re-decrypting $encryptedInHistory/$totalInHistory encrypted msg(s)');
      await _redecryptEncryptedMessages(emit, existingKey);
      return;
    }

    debugPrint('[E2EE] _deriveKeyFromHistory: no stored key — scanning $totalInHistory history msg(s), $encryptedInHistory encrypted');

    // Messages are sorted newest-first; the first match is the most recent
    // X3DH opener, which establishes the current session.
    final opener = state.messages
        .where((m) =>
            m.isEncrypted &&
            m.ephemeralKey != null &&
            m.ephemeralKey!.isNotEmpty &&
            m.senderIdentityKey != null &&
            m.senderIdentityKey!.isNotEmpty &&
            m.senderId != _myUserId)
        .firstOrNull;
    if (opener == null) {
      // Log whether we skipped any openers from ourselves (we can't re-derive from those).
      final ownOpeners = state.messages.where((m) =>
          m.isEncrypted &&
          m.ephemeralKey != null &&
          m.ephemeralKey!.isNotEmpty &&
          m.senderId == _myUserId).length;
      debugPrint('[E2EE] _deriveKeyFromHistory: no opener from recipient found'
          ' (own openers in history: $ownOpeners) — proactive X3DH will run');
      return;
    }

    debugPrint('[E2EE] _deriveKeyFromHistory: found X3DH opener ${opener.id} (otpkId: ${opener.otpkId})');
    try {
      await _e2ee.storeIdentityKey(opener.senderId, opener.senderIdentityKey!);
      final x3dhResult = await _deriveAndDecryptX3DH(
        senderIdentityKey: opener.senderIdentityKey!,
        senderEphemeralKey: opener.ephemeralKey!,
        otpkId: opener.otpkId,
        ciphertext: opener.content,
        iv: opener.iv!,
      );
      if (x3dhResult == null) {
        debugPrint('[E2EE] _deriveKeyFromHistory: X3DH failed for opener ${opener.id}');
        return;
      }
      final sessionKey = x3dhResult.$1;
      await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
      _pendingEphemeralKey = null;
      _pendingOtpkId = null;
      _proactiveSessionKey = null;
      final kHex = sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[E2EE] _deriveKeyFromHistory: session key stored (keyPrefix=$kHex), proactive state cleared');
      await _redecryptEncryptedMessages(emit, sessionKey);
    } catch (e) {
      debugPrint('[E2EE] _deriveKeyFromHistory failed: $e');
    }
  }

  Future<void> _onLoadMore(
    ChatRoomLoadMoreRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (state.isLoadingMore || state.hasReachedEnd || _currentRoomId == null) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));

    final oldest = state.messages.isNotEmpty ? state.messages.last.id : null;

    try {
      final older = await _getMessages(_currentRoomId!, beforeId: oldest);
      emit(state.copyWith(
        isLoadingMore: false,
        messages: _sorted([...state.messages, ...older]),
        hasReachedEnd: older.length < ChatConfig.messagePageSize,
      ));
    } catch (_) {
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: 'Failed to load more.',
      ));
    }
  }

  /// Phase 6 — Session invalidation on room join.
  ///
  /// The server pushes participant bundles the moment the WS connects. We
  /// compare the incoming fingerprint ({identityKey, signedPreKeyId}) against
  /// what we cached from the last successful X3DH. If anything changed the
  /// recipient reinstalled or rotated their SPK — delete our session key so
  /// the next send runs a fresh X3DH. If nothing changed, cancel the
  /// precautionary rekey scheduled by _onJoined and reuse the stored key.
  ///
  /// The WS also carries OTPK data inline, so proactive X3DH (when no session
  /// key exists) runs without an extra REST call.
  Future<void> _onKeyBundlesReceived(
    _KeyBundlesReceived event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_isDirectRoom || _recipientId == null || _currentRoomId == null) return;

    final recipientData = event.bundles
        .where((b) => b['userId'] == _recipientId)
        .firstOrNull;
    if (recipientData == null) return;

    final bundle = _bundleFromWsData(recipientData);
    if (bundle == null) return;

    // Phase 6: compare against cached bundle fingerprint.
    final cached = await _e2ee.loadCachedBundle(_recipientId!);
    final keysChanged = cached == null ||
        cached['ik'] != bundle.identityKey ||
        (cached['spkId'] as int) != bundle.signedPreKeyId;

    if (keysChanged) {
      // Recipient rotated or reinstalled — invalidate the session.
      await _e2ee.deleteSessionKey(_currentRoomId!);
      await _e2ee.storeCachedBundle(
        _recipientId!,
        identityKey: bundle.identityKey,
        signedPreKeyId: bundle.signedPreKeyId,
      );
      debugPrint('[E2EE] key_bundles: keys changed for $_recipientId — session invalidated, fresh X3DH on next send');
      // _needsRekey remains true from _onJoined; fresh X3DH runs on first send.
      return;
    }

    // Keys unchanged — cancel the precautionary rekey.
    _needsRekey = false;

    final storedKey = await _e2ee.loadSessionKey(_currentRoomId!);
    if (storedKey == null) {
      debugPrint('[E2EE] key_bundles: keys unchanged, no session — proactive X3DH');
      await _setupE2EESession(emit, bundle: bundle);
    } else {
      final kHex = storedKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[E2EE] key_bundles: keys unchanged, existing session reused (keyPrefix=$kHex)');
      emit(state.copyWith(isE2EEReady: true));
    }
  }

  /// A participant published (or re-published) their E2EE keys.
  /// Apply the same invalidation logic as [_onKeyBundlesReceived]: compare
  /// against the cached bundle fingerprint. If keys changed, any active
  /// session on THIS device is invalid — the other party's key material
  /// changed and they can no longer decrypt messages encrypted with the old
  /// key. Setting [_needsRekey] forces a fresh X3DH with header on the next
  /// send, which is the only way to re-synchronise the session.
  Future<void> _onParticipantKeyAvailable(
    _ParticipantKeyAvailable event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_isDirectRoom ||
        _recipientId == null ||
        _currentRoomId == null ||
        event.userId != _recipientId) {
      return;
    }

    final bundle = _bundleFromWsData({
      'identityKey': event.identityKey,
      'signedPreKey': event.signedPreKey,
    });
    if (bundle == null) return;

    final cached = await _e2ee.loadCachedBundle(_recipientId!);
    final keysChanged = cached == null ||
        cached['ik'] != bundle.identityKey ||
        (cached['spkId'] as int) != bundle.signedPreKeyId;

    if (keysChanged) {
      await _e2ee.deleteSessionKey(_currentRoomId!);
      await _e2ee.storeCachedBundle(
        _recipientId!,
        identityKey: bundle.identityKey,
        signedPreKeyId: bundle.signedPreKeyId,
      );
      _needsRekey = true;
      debugPrint('[E2EE] participant_key_available: keys changed for ${event.userId} — session invalidated, fresh X3DH on next send');
      return;
    }

    // Keys unchanged — run proactive X3DH only if no session exists and no
    // rekey is already scheduled. Checking _pendingEphemeralKey guards against
    // concurrent duplicate events both attempting X3DH at the same time.
    if (_needsRekey ||
        _pendingEphemeralKey != null ||
        await _e2ee.loadSessionKey(_currentRoomId!) != null) {
      emit(state.copyWith(isE2EEReady: true));
      return;
    }

    debugPrint('[E2EE] participant_key_available: building proactive session (no OTPK)');
    await _setupE2EESession(emit, bundle: bundle);
  }

  /// A participant rotated their key bundle (server broadcast via key_rotation).
  /// Identical invalidation logic to [_onParticipantKeyAvailable].
  Future<void> _onKeyRotationReceived(
    _KeyRotationReceived event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_isDirectRoom ||
        _recipientId == null ||
        _currentRoomId == null ||
        event.userId != _recipientId) {
      return;
    }

    final bundle = _bundleFromWsData({
      'identityKey': event.identityKey,
      'signedPreKey': event.signedPreKey,
    });
    if (bundle == null) return;

    final cached = await _e2ee.loadCachedBundle(_recipientId!);
    final keysChanged = cached == null ||
        cached['ik'] != bundle.identityKey ||
        (cached['spkId'] as int) != bundle.signedPreKeyId;

    if (keysChanged) {
      await _e2ee.deleteSessionKey(_currentRoomId!);
      await _e2ee.storeCachedBundle(
        _recipientId!,
        identityKey: bundle.identityKey,
        signedPreKeyId: bundle.signedPreKeyId,
      );
      _needsRekey = true;
      debugPrint('[E2EE] key_rotation: keys changed for ${event.userId} — session invalidated, fresh X3DH on next send');
      return;
    }

    if (_needsRekey ||
        _pendingEphemeralKey != null ||
        await _e2ee.loadSessionKey(_currentRoomId!) != null) {
      emit(state.copyWith(isE2EEReady: true));
      return;
    }

    debugPrint('[E2EE] key_rotation: building proactive session (no OTPK)');
    await _setupE2EESession(emit, bundle: bundle);
  }

  /// Build a [RecipientKeyBundle] from a WS key-bundle map.
  /// Returns null if required fields are absent or malformed.
  RecipientKeyBundle? _bundleFromWsData(Map<String, dynamic> data) {
    try {
      final ik = data['identityKey'] as String?;
      final spkRaw = data['signedPreKey'];
      if (ik == null || spkRaw is! Map<String, dynamic>) return null;
      final otpkRaw = data['oneTimePreKey'];
      final otpk = otpkRaw is Map<String, dynamic> ? otpkRaw : null;
      return RecipientKeyBundle(
        identityKey: ik,
        signedPreKeyId: (spkRaw['keyId'] as num?)?.toInt() ?? 0,
        signedPreKey: spkRaw['publicKey'] as String,
        signedPreKeySignature: spkRaw['signature'] as String? ?? '',
        oneTimePreKeyId: (otpk?['keyId'] as num?)?.toInt(),
        oneTimePreKey: otpk?['publicKey'] as String?,
        registrationId: (data['registrationId'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Runs X3DH with [bundle] (or falls back to a REST fetch if omitted),
  /// stores the session key, caches the bundle fingerprint for Phase 6,
  /// and saves the X3DH header for the first outgoing message.
  Future<void> _setupE2EESession(
    Emitter<ChatRoomState> emit, {
    RecipientKeyBundle? bundle,
  }) async {
    try {
      final resolvedBundle = bundle ?? await _keyDs.fetchBundle(_recipientId!);
      if (resolvedBundle == null) return;
      final session = await _e2ee.createSendingSession(resolvedBundle);
      // Keep the proactive session key in memory ONLY — do NOT persist it.
      // Persisting it would cause incoming messages (encrypted by the other
      // party with their own session key) to fail decryption with a MAC error.
      // The key is written to secure storage the moment we actually send with it.
      _proactiveSessionKey = session.sessionKey;
      await _e2ee.storeCachedBundle(
        _recipientId!,
        identityKey: resolvedBundle.identityKey,
        signedPreKeyId: resolvedBundle.signedPreKeyId,
      );
      _pendingEphemeralKey = session.ephemeralPublicKey;
      _pendingOtpkId = session.otpkId;
      _pendingBundleSpkId = resolvedBundle.signedPreKeyId;
      final kHex = session.sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[E2EE] Proactive session ready in memory (otpkId: ${session.otpkId}, keyPrefix=$kHex)');
      emit(state.copyWith(isE2EEReady: true));
    } catch (e) {
      debugPrint('[E2EE] Proactive session setup failed: $e');
    }
  }

  void _publishBundleInBackground() {
    Future(() async {
      try {
        final PublishableKeyBundle bundle;
        if (!await _e2ee.hasKeys()) {
          debugPrint('[E2EE] No keys — generating new bundle');
          bundle = await _e2ee.generateKeys();
        } else {
          debugPrint('[E2EE] Keys exist — re-publishing current bundle');
          bundle = (await _e2ee.currentBundle())!;
        }
        await _keyDs.publishBundle(bundle);
        _e2ee.markBundlePublished();
        debugPrint('[E2EE] Bundle published OK (${bundle.oneTimePreKeys.length} OTPKs)');
        _replenishOtpksIfNeeded().catchError((_) {});

        // SPK rotation — check while already in the background.
        if (await _e2ee.needsSPKRotation()) {
          final rotated = await _e2ee.rotateSPK();
          await _keyDs.publishBundle(rotated);
          debugPrint('[E2EE] SPK rotated in background');
        }
      } catch (e) {
        debugPrint('[E2EE] Failed to publish bundle: $e');
      }
    });
  }

  Future<void> _replenishOtpksIfNeeded() async {
    try {
      final count = await _keyDs.prekeyCount();
      if (count < _otpkReplenishThreshold) {
        final needed = _otpkReplenishBatchSize - count;
        final otpks = await _e2ee.generateOtpks(needed);
        await _keyDs.topUpPrekeys(otpks);
        debugPrint('[E2EE] Topped up $needed OTPKs (was $count)');
      }
    } catch (e) {
      debugPrint('[E2EE] OTPK replenish failed: $e');
    }
  }

  // ── Edit / Delete handlers ────────────────────────────────────────────────

  Future<void> _onMessageEditRequested(
    ChatRoomMessageEditRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    // Optimistic: apply immediately.
    final now = DateTime.now();
    final updated = state.messages
        .map((m) => m.id == event.messageId
            ? m.copyWith(content: event.newContent, updatedAt: now)
            : m)
        .toList();
    emit(state.copyWith(messages: updated));

    try {
      await _editMessage(
          roomId: roomId,
          messageId: event.messageId,
          content: event.newContent);
      // Persist edit to local cache (fire-and-forget).
      _updateCachedMessage(event.messageId, event.newContent, now)
          .catchError((_) {});
    } catch (_) {
      // Revert to original content on failure.
      final reverted = state.messages
          .map((m) => m.id == event.messageId
              ? m.copyWith(clearUpdatedAt: true,
                  content: state.messages
                      .firstWhere((x) => x.id == event.messageId,
                          orElse: () => m)
                      .content)
              : m)
          .toList();
      emit(state.copyWith(
          messages: reverted, errorMessage: 'Could not edit message.'));
    }
  }

  Future<void> _onMessageDeleteRequested(
    ChatRoomMessageDeleteRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    // Optimistic: remove from list immediately.
    emit(state.copyWith(
      messages: state.messages.where((m) => m.id != event.messageId).toList(),
    ));

    try {
      await _deleteMessage(roomId: roomId, messageId: event.messageId);
      _deleteCachedMessage(event.messageId).catchError((_) {});
    } catch (_) {
      // Re-fetch messages to restore on failure.
      emit(state.copyWith(errorMessage: 'Could not delete message.'));
    }
  }

  // ── Forward ────────────────────────────────────────────────────────────────

  /// Rooms this bloc has recently forwarded into.
  ///
  /// The socket reports a refused send against the room it was aimed at, and
  /// the error listener only accepts frames for the room on screen — so a
  /// forward the server rejected used to vanish, leaving the user with a
  /// confirmation for a message that was never delivered. Entries are dropped
  /// after a few seconds; any error worth showing arrives immediately.
  final Set<String> _forwardTargets = {};

  void _onForwardRequested(
    ChatRoomForwardRequested event,
    Emitter<ChatRoomState> emit,
  ) {
    final msg = event.message;
    if (msg.isEncrypted) {
      // The body on screen is ciphertext this room's key opened; the target
      // room has a different one. Forwarding it would deliver noise.
      emit(state.copyWith(
          errorMessage: 'Encrypted messages cannot be forwarded.'));
      return;
    }
    if (!_ws.isConnected) {
      emit(state.copyWith(errorMessage: 'Not connected — try again in a moment.'));
      return;
    }

    _forwardTargets.add(event.targetRoomId);
    Timer(const Duration(seconds: 8), () {
      _forwardTargets.remove(event.targetRoomId);
    });
    // Sent over the shared socket with an explicit room_id rather than by
    // opening the target room: the connection already carries every room the
    // user is in, and the server checks membership on the frame. Nothing about
    // forwarding requires leaving the conversation you are reading.
    //
    // Plaintext even when the target is an E2EE DM — the key material for that
    // room belongs to its own bloc, which isn't running. The recipient sees a
    // readable message; what it costs is that this one copy isn't encrypted.
    _ws.send(
      msg.content.isEmpty ? null : msg.content,
      imageUrl: msg.imageUrl,
      isVideo: msg.isVideo,
      roomId: event.targetRoomId,
    );

    // Confirmed here rather than by the screen that opened the picker, so the
    // message is only claimed once the frame has actually gone out. Emitted and
    // immediately cleared so forwarding twice to the same room confirms twice
    // — a notice that is already on the state would not read as a change.
    final where =
        event.targetName.isNotEmpty ? ' to ${event.targetName}' : '';
    emit(state.copyWith(systemNotice: 'Forwarded$where'));
    emit(state.copyWith(clearSystemNotice: true));
  }

  // ── Pin ────────────────────────────────────────────────────────────────────

  /// Build the banner preview for [messageId] from what is already on screen.
  ///
  /// The server sends its own preview back over the socket, but that round trip
  /// is what makes an optimistic update worth having: the banner appears the
  /// moment the user taps Pin. Returns null when the message isn't loaded,
  /// which only leaves the banner to the WS event.
  PinnedMessage? _localPreviewFor(String messageId) {
    final msg = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (msg == null) return null;
    return PinnedMessage(
      id: msg.id,
      senderId: msg.senderId,
      senderName: msg.displayName,
      content: msg.content.isEmpty ? null : msg.content,
      imageUrl: msg.imageUrl,
      isVideo: msg.isVideo,
      isEncrypted: msg.isEncrypted,
      createdAt: msg.createdAt,
    );
  }

  Future<void> _onPinToggled(
    ChatRoomPinToggled event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    final room = state.room;
    if (room == null) {
      // No room object to update optimistically, but the request itself is
      // still valid — send it and let the message_pinned broadcast fill the
      // banner in. Returning here would make the control do nothing at all.
      try {
        await _pinMessage(roomId: roomId, messageId: event.messageId);
      } catch (e) {
        emit(state.copyWith(
          errorMessage: chatErrorText(e,
              fallback: event.messageId == null
                  ? 'Could not unpin message.'
                  : 'Could not pin message.'),
        ));
      }
      return;
    }

    final previous = room.pinnedMessage;
    final optimistic = event.messageId == null
        ? null
        : (_localPreviewFor(event.messageId!) ?? previous);
    emit(state.copyWith(
      room: event.messageId == null
          ? room.copyWith(clearPinnedMessage: true)
          : (optimistic != null
              ? room.copyWith(pinnedMessage: optimistic)
              : room),
    ));

    try {
      await _pinMessage(roomId: roomId, messageId: event.messageId);
    } catch (e) {
      // Put the previous pin back — the banner must not claim something the
      // server rejected (e.g. an admin-only room the user cannot pin in).
      final current = state.room;
      emit(state.copyWith(
        room: current == null
            ? current
            : (previous == null
                ? current.copyWith(clearPinnedMessage: true)
                : current.copyWith(pinnedMessage: previous)),
        errorMessage: chatErrorText(
          e,
          fallback: event.messageId == null
              ? 'Could not unpin message.'
              : 'Could not pin message.',
        ),
      ));
    }
  }

  void _onMessagePinned(_MessagePinned event, Emitter<ChatRoomState> emit) {
    final room = state.room;
    if (room == null) return;
    emit(state.copyWith(
      room: event.pinned == null
          ? room.copyWith(clearPinnedMessage: true)
          : room.copyWith(pinnedMessage: event.pinned),
    ));
  }

  void _onMessageEdited(_MessageEdited event, Emitter<ChatRoomState> emit) {
    final updated = state.messages
        .map((m) => m.id == event.messageId
            ? m.copyWith(content: event.content, updatedAt: event.updatedAt)
            : m)
        .toList();
    emit(state.copyWith(messages: updated));
    _updateCachedMessage(event.messageId, event.content, event.updatedAt)
        .catchError((_) {});
  }

  void _onMessageDeleted(_MessageDeleted event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      messages: state.messages.where((m) => m.id != event.messageId).toList(),
    ));
    _deleteCachedMessage(event.messageId).catchError((_) {});
  }

  void _onWsUserJoined(_WsUserJoined event, Emitter<ChatRoomState> emit) {
    final name = event.userName.isNotEmpty ? event.userName : event.userId;
    debugPrint('[ChatBloc] user_joined room=$_currentRoomId userId=${event.userId}'
        ' name="${event.userName}" role="${event.userRole}"');

    // Add the new member to the local participant list so _rekeyGroup can
    // include them and the participant count stays consistent.
    ChatRoom? updatedRoom = state.room;
    if (updatedRoom != null &&
        !updatedRoom.participants.any((p) => p.userId == event.userId)) {
      final newParticipant = ChatParticipant(
        userId: event.userId,
        userRole: event.userRole.isNotEmpty ? event.userRole : ChatConfig.roleClient,
        joinedAt: DateTime.now().toUtc(),
        userName: event.userName.isNotEmpty ? event.userName : null,
      );
      updatedRoom = updatedRoom.copyWith(
          participants: [...updatedRoom.participants, newParticipant]);
    }

    emit(state.copyWith(room: updatedRoom, systemNotice: '$name joined the group'));

    // The join frame may omit the user's name/role, and broadcast-stream frames
    // can be missed entirely while WS listeners are (re)attaching — so always
    // reconcile against the authoritative room list.
    _scheduleRoomReconcile();

    // Distribute our group sender key to the new joiner so they can decrypt
    // our past and future messages.
    if (_isGroupRoom && _currentRoomId != null) {
      _distributeSenderKeyToMember(event.userId).catchError((_) {});
    }
  }

  /// Debounced re-fetch of the room so the participant list/count always
  /// converges to server truth after a membership change, regardless of how
  /// complete (or whether) the triggering WS frame was.
  void _scheduleRoomReconcile() {
    _reconcileDebounce?.cancel();
    _reconcileDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!isClosed && _currentRoomId != null) {
        add(const _RoomReconcileRequested());
      }
    });
  }

  Future<void> _onRoomReconcile(
    _RoomReconcileRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      final fresh = await _getRoom(roomId);
      // Bail if the user navigated away or switched rooms while fetching.
      if (isClosed || _currentRoomId != roomId) return;
      final amIAdmin =
          fresh.participants.any((p) => p.userId == _myUserId && p.isAdmin);
      debugPrint('[ChatBloc] room reconciled — participants=${fresh.participants.length}');
      emit(state.copyWith(room: fresh, amIAdmin: amIAdmin));
    } catch (e) {
      debugPrint('[ChatBloc] room reconcile failed: $e');
    }
  }

  // ── Group admin handlers ───────────────────────────────────────────────────

  Future<void> _onGrantAdminRequested(
    ChatRoomGrantAdminRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      await _grantAdmin(roomId, event.userId);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Could not grant admin role.'));
    }
  }

  Future<void> _onRevokeAdminRequested(
    ChatRoomRevokeAdminRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      await _revokeAdmin(roomId, event.userId);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Could not revoke admin role.'));
    }
  }

  Future<void> _onUpdateSettingsRequested(
    ChatRoomUpdateSettingsRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    final prevRoom = state.room;

    // Optimistic update so the toggle / rename feels instant.
    ChatRoom? optimisticRoom = state.room;
    if (optimisticRoom != null) {
      if (event.adminOnly != null) {
        optimisticRoom = optimisticRoom.copyWith(adminOnly: event.adminOnly!);
      }
      if (event.name != null) {
        optimisticRoom = optimisticRoom.copyWith(name: event.name);
      }
      if (event.imageUrl != null) {
        // copyWith cannot express "clear", so an empty string is applied by
        // rebuilding the room rather than through it.
        optimisticRoom = event.imageUrl!.isEmpty
            ? ChatRoom(
                id: optimisticRoom.id,
                type: optimisticRoom.type,
                eventId: optimisticRoom.eventId,
                name: optimisticRoom.name,
                createdAt: optimisticRoom.createdAt,
                participants: optimisticRoom.participants,
                e2eStatus: optimisticRoom.e2eStatus,
                adminOnly: optimisticRoom.adminOnly,
                unreadCount: optimisticRoom.unreadCount,
                lastMessage: optimisticRoom.lastMessage,
              )
            : optimisticRoom.copyWith(imageUrl: event.imageUrl);
      }
    }
    emit(state.copyWith(room: optimisticRoom));

    try {
      await _updateRoomSettings(roomId,
          adminOnly: event.adminOnly,
          name: event.name,
          imageUrl: event.imageUrl);
    } catch (_) {
      emit(state.copyWith(
        room: prevRoom,
        errorMessage: 'Could not update room settings.',
      ));
    }
  }

  Future<void> _onKickRequested(
    ChatRoomKickRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      await _kickParticipant(roomId, event.userId);
    } catch (_) {
      emit(state.copyWith(errorMessage: 'Could not remove participant.'));
    }
  }

  Future<void> _onLeaveGroupRequested(
    ChatRoomLeaveGroupRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    emit(state.copyWith(isLeaving: true, clearError: true));
    try {
      await _leaveRoom(roomId);
      emit(state.copyWith(isLeaving: false, isDeleted: true));
    } catch (_) {
      emit(state.copyWith(isLeaving: false, errorMessage: 'Could not leave the group.'));
    }
  }

  Future<void> _onDeleteRequested(
    ChatRoomDeleteRequested event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    emit(state.copyWith(isDeleting: true, clearError: true));
    try {
      await _deleteRoom(roomId);
      emit(state.copyWith(isDeleting: false, isDeleted: true));
    } on ServerException catch (e) {
      final code = _parseStatusCode(e.message);
      final msg = code == 403
          ? 'Only admins can delete this group.'
          : code == 400
              ? 'Remove all other admins before deleting.'
              : 'Could not delete the group.';
      emit(state.copyWith(isDeleting: false, errorMessage: msg));
    } catch (_) {
      emit(state.copyWith(
          isDeleting: false, errorMessage: 'Could not delete the group.'));
    }
  }

  void _onRoomDeleted(_RoomDeleted event, Emitter<ChatRoomState> emit) {
    if (_currentRoomId != null) _clearRoomCache(_currentRoomId!).catchError((_) {});
    emit(state.copyWith(isDeleted: true));
  }

  // ── Group E2EE handlers ───────────────────────────────────────────────────

  Future<void> _onGroupSenderKeyReceived(
    _GroupSenderKeyReceived event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    try {
      // Get sender's IK from cache; fall back to fetching bundle.
      String? senderIk = await _e2ee.loadIdentityKey(event.senderId);
      if (senderIk == null) {
        final bundle = await _keyDs.fetchBundle(event.senderId);
        if (bundle == null) {
          debugPrint('[GroupE2EE] Cannot get IK for ${event.senderId} — skipping');
          return;
        }
        senderIk = bundle.identityKey;
        await _e2ee.storeIdentityKey(event.senderId, senderIk);
      }

      final key = await _e2ee.decryptSenderKeyFromSender(event.encryptedKey, senderIk);
      if (key != null) {
        // Check before storing so we can detect first-time receives.
        final isFirstReceive =
            await _e2ee.loadPeerGroupSenderKey(roomId, event.senderId) == null;
        await _e2ee.storePeerGroupSenderKey(roomId, event.senderId, key);
        debugPrint('[GroupE2EE] Stored sender key for ${event.senderId}');

        // Re-decrypt any encrypted messages from this sender already in state.
        await _redecryptGroupMessages(emit, event.senderId, key);

        // Bootstrap: on first receive, distribute our key back so they can
        // decrypt our messages (handles new-member join and initial setup).
        if (isFirstReceive) {
          final myKey = await _e2ee.loadGroupSenderKey(roomId);
          if (myKey != null) {
            try {
              final encKey = await _e2ee.encryptSenderKeyForRecipient(myKey, senderIk);
              await _keyDs.distributeGroupSenderKey(roomId, [
                GroupSenderKeyRecipient(userId: event.senderId, encryptedKey: encKey),
              ]);
              debugPrint('[GroupE2EE] Bootstrap: distributed our key to ${event.senderId}');
            } catch (_) {}
          }
        }
      } else {
        debugPrint('[GroupE2EE] decryptSenderKeyFromSender returned null for ${event.senderId}');
      }
    } catch (e) {
      debugPrint('[GroupE2EE] Failed to store sender key from ${event.senderId}: $e');
    }
  }

  Future<void> _onParticipantLeft(
    _ParticipantLeft event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (event.userId == _myUserId) return; // handled by _onLeaveGroupRequested
    final name = _participantName(event.userId);
    final updatedParticipants = state.room?.participants
        .where((p) => p.userId != event.userId)
        .toList();
    final updatedRoom = updatedParticipants != null
        ? state.room!.copyWith(participants: updatedParticipants)
        : state.room;
    emit(state.copyWith(
      room: updatedRoom,
      systemNotice: '$name left the group.',
    ));
    _scheduleRoomReconcile();

    // Re-key: the departed member must not decrypt future messages.
    if (_isGroupRoom && _currentRoomId != null) {
      _rekeyGroup(_currentRoomId!).catchError((_) {});
    }
  }

  void _onReadReceiptReceived(
    _ReadReceiptReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final upToId = event.upToMessageId;
    final singleId = event.messageId;
    final readerId = event.readerId;

    // Find the timestamp of the upTo message for bulk-ack range comparison.
    final upToMsg = upToId != null
        ? state.messages.where((m) => m.id == upToId).firstOrNull
        : null;

    final updated = state.messages.map((msg) {
      if (msg.readBy.contains(readerId)) return msg;
      final shouldMark = upToMsg != null
          ? !msg.createdAt.isAfter(upToMsg.createdAt)
          : singleId != null && msg.id == singleId;
      return shouldMark ? msg.copyWith(readBy: [...msg.readBy, readerId]) : msg;
    }).toList();

    emit(state.copyWith(messages: updated));
  }

  // ── Typing ────────────────────────────────────────────────────────────────

  /// How long an indicator survives without a refresh. The backstop for a
  /// sender who goes away without saying so — a killed app, a dropped socket,
  /// a build too old to send the idle stop. Comfortably longer than the
  /// announcer's send interval so a steady typist never flickers, and longer
  /// than its idle timeout so the sender's own stop is what normally clears it.
  static const _typingTimeout = Duration(seconds: 8);

  /// Owns the outgoing side: when to say we started, and — the part that was
  /// missing — when to say we stopped. See [TypingAnnouncer].
  late final TypingAnnouncer _typing = TypingAnnouncer(
    send: (isTyping) {
      final roomId = _currentRoomId;
      if (roomId == null || isClosed) return;
      _ws.sendTyping(roomId, isTyping: isTyping);
    },
  );

  final Map<String, Timer> _typingExpiryTimers = {};

  void _onTypingChanged(ChatRoomTypingChanged event, Emitter<ChatRoomState> emit) {
    if (event.isTyping) {
      _typing.markTyping();
    } else {
      _typing.markStopped();
    }
  }

  /// Announce that we are no longer typing — idempotent, so the several places
  /// that legitimately want to say it (going idle, sending, clearing the box,
  /// leaving the room) can all just call it.
  void _stopTyping() => _typing.markStopped();

  void _onTypingReceived(_TypingReceived event, Emitter<ChatRoomState> emit) {
    final updated = Map<String, String>.from(state.typingUsers);
    _typingExpiryTimers.remove(event.userId)?.cancel();

    if (event.isTyping) {
      updated[event.userId] = event.userName;
      // Refreshed on each frame from this user, so a continuous typist stays
      // shown while someone who vanishes mid-word disappears on their own.
      _typingExpiryTimers[event.userId] = Timer(_typingTimeout, () {
        if (!isClosed) add(_TypingExpired(event.userId));
      });
    } else {
      updated.remove(event.userId);
    }

    emit(state.copyWith(typingUsers: updated));
  }

  /// Their message arrived, so they are no longer typing it.
  ///
  /// Without this the indicator outlived the thing it was predicting: the
  /// message landed and "typing…" stayed underneath it until the expiry ran
  /// out, because a client that clears its composer programmatically after a
  /// send fires no `onChanged` and so never sent a stop frame.
  Map<String, String>? _typingCleared(String userId) {
    if (!state.typingUsers.containsKey(userId)) return null;
    _typingExpiryTimers.remove(userId)?.cancel();
    return Map<String, String>.from(state.typingUsers)..remove(userId);
  }

  void _onTypingExpired(_TypingExpired event, Emitter<ChatRoomState> emit) {
    _typingExpiryTimers.remove(event.userId)?.cancel();
    if (!state.typingUsers.containsKey(event.userId)) return;
    emit(state.copyWith(
      typingUsers: Map<String, String>.from(state.typingUsers)
        ..remove(event.userId),
    ));
  }

  // ── Mute ──────────────────────────────────────────────────────────────────

  Future<void> _onMuteToggled(
    ChatRoomMuteToggled event,
    Emitter<ChatRoomState> emit,
  ) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;

    // Optimistic: the switch should move under the thumb, not after a
    // round-trip. Reverted below if the server disagrees.
    emit(state.copyWith(isMuted: event.muted));
    try {
      final applied = await _setRoomMuted(roomId, event.muted);
      if (!isClosed && applied != event.muted) {
        emit(state.copyWith(isMuted: applied));
      }
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        isMuted: !event.muted,
        errorMessage: 'Could not change notifications for this chat.',
      ));
    }
  }

  // ── Group E2EE helpers ────────────────────────────────────────────────────

  /// On group room join: fetch all members' sender keys, then distribute ours.
  Future<void> _setupGroupE2EE(String roomId, Emitter<ChatRoomState> emit) async {
    try {
      final entries = await _keyDs.fetchGroupSenderKeys(roomId);
      for (final entry in entries) {
        if (entry.userId == _myUserId) continue;
        // Load sender IK from cache; fall back to fetching bundle.
        String? senderIk = await _e2ee.loadIdentityKey(entry.userId);
        if (senderIk == null) {
          final bundle = await _keyDs.fetchBundle(entry.userId);
          if (bundle == null) continue;
          senderIk = bundle.identityKey;
          await _e2ee.storeIdentityKey(entry.userId, senderIk);
        }
        final key = await _e2ee.decryptSenderKeyFromSender(entry.encryptedKey, senderIk);
        if (key != null) {
          await _e2ee.storePeerGroupSenderKey(roomId, entry.userId, key);
          debugPrint('[GroupE2EE] Stored peer sender key for ${entry.userId}');
          // Re-decrypt any already-loaded ciphertext messages from this sender.
          await _redecryptGroupMessages(emit, entry.userId, key);
        }
      }

      // Distributing our own sender key is what lets other people decrypt what
      // *we* send. With encryption off we send plaintext, so there is nothing
      // for them to decrypt and this is pure round-trips on every group open.
      //
      // Fetching and storing peers' keys above is a different matter and always
      // runs: it decrypts history, and messages from clients still on a build
      // with encryption enabled.
      if (!ChatConfig.e2eeEnabled) return;

      // Distribute our own sender key. Generate a new one if we don't have one.
      var myKey = await _e2ee.loadGroupSenderKey(roomId);
      if (myKey == null) {
        myKey = await _e2ee.generateSenderKey();
        await _e2ee.storeGroupSenderKey(roomId, myKey);
      }

      // Build recipient list using the cached IK (loaded above during decrypt loop).
      final recipients = <GroupSenderKeyRecipient>[];
      for (final entry in entries) {
        if (entry.userId == _myUserId) continue;
        final ikPub = await _e2ee.loadIdentityKey(entry.userId);
        if (ikPub == null) continue;
        try {
          final encryptedKey =
              await _e2ee.encryptSenderKeyForRecipient(myKey, ikPub);
          recipients.add(GroupSenderKeyRecipient(
              userId: entry.userId, encryptedKey: encryptedKey));
        } catch (_) {}
      }

      // Also distribute to active participants NOT returned by the GET endpoint
      // (bootstrap deadlock: both users join simultaneously → entries list is
      // empty for both → neither can distribute their key via the GET response).
      final entryIds = entries.map((e) => e.userId).toSet();
      final uncoveredParticipants = state.room?.participants
              .where((p) =>
                  p.userId != _myUserId &&
                  !p.isPending &&
                  !entryIds.contains(p.userId))
              .toList() ??
          [];
      for (final p in uncoveredParticipants) {
        String? ikPub = await _e2ee.loadIdentityKey(p.userId);
        if (ikPub == null) {
          final bundle = await _keyDs.fetchBundle(p.userId);
          if (bundle == null) continue;
          ikPub = bundle.identityKey;
          await _e2ee.storeIdentityKey(p.userId, ikPub);
        }
        try {
          final encryptedKey =
              await _e2ee.encryptSenderKeyForRecipient(myKey, ikPub);
          recipients.add(GroupSenderKeyRecipient(
              userId: p.userId, encryptedKey: encryptedKey));
        } catch (_) {}
      }

      if (recipients.isNotEmpty) {
        await _keyDs.distributeGroupSenderKey(roomId, recipients);
        debugPrint('[GroupE2EE] Distributed sender key to ${recipients.length} member(s)');
      }
    } catch (e) {
      debugPrint('[GroupE2EE] _setupGroupE2EE failed: $e');
    }
  }

  /// Generate a new sender key and distribute it to all current active members.
  /// Called after any member is removed or leaves (forward secrecy).
  Future<void> _rekeyGroup(String roomId) async {
    try {
      final newKey = await _e2ee.generateSenderKey();
      await _e2ee.storeGroupSenderKey(roomId, newKey);
      debugPrint('[GroupE2EE] Re-keyed: new sender key generated');

      final participants = state.room?.participants
          .where((p) => p.userId != _myUserId && !p.isPending)
          .toList() ?? [];

      if (participants.isEmpty) return;

      final recipients = <GroupSenderKeyRecipient>[];
      for (final p in participants) {
        final ikPub = await _e2ee.loadIdentityKey(p.userId);
        if (ikPub == null) continue;
        try {
          final encryptedKey =
              await _e2ee.encryptSenderKeyForRecipient(newKey, ikPub);
          recipients.add(GroupSenderKeyRecipient(
              userId: p.userId, encryptedKey: encryptedKey));
        } catch (_) {}
      }

      if (recipients.isNotEmpty) {
        await _keyDs.distributeGroupSenderKey(roomId, recipients);
        debugPrint('[GroupE2EE] Distributed re-keyed sender key to ${recipients.length} member(s)');
      }
    } catch (e) {
      debugPrint('[GroupE2EE] _rekeyGroup failed: $e');
    }
  }

  /// Encrypt [content] with our group sender key and send over WS.
  /// Falls back to plaintext if no sender key is available.
  Future<void> _encryptAndSendGroup({
    String? content,
    String? imageUrl,
    bool isVideo = false,
    String? replyToId,
  }) async {
    final roomId = _currentRoomId;
    final hasText = content != null && content.isNotEmpty;

    if (roomId == null || !hasText) {
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo,
          replyToId: replyToId, roomId: roomId);
      return;
    }

    final senderKey = await _e2ee.loadGroupSenderKey(roomId);
    if (senderKey == null) {
      debugPrint('[GroupE2EE] No sender key — sending plaintext');
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo,
          replyToId: replyToId, roomId: roomId);
      return;
    }

    try {
      final encrypted = await _e2ee.encrypt(senderKey, content);
      _ws.sendEncrypted(
        ciphertext: encrypted.ciphertext,
        iv: encrypted.iv,
        imageUrl: imageUrl,
        isVideo: isVideo,
        replyToId: replyToId,
        roomId: roomId,
      );
    } catch (e) {
      debugPrint('[GroupE2EE] Encrypt failed, sending plaintext: $e');
      _ws.send(content, imageUrl: imageUrl, isVideo: isVideo,
          replyToId: replyToId, roomId: roomId);
    }
  }

  /// Distributes our group sender key to [userId].
  /// Uses the cached identity key when available to avoid consuming an OTPK;
  /// falls back to fetching the bundle if the IK is not yet cached.
  Future<void> _distributeSenderKeyToMember(String userId) async {
    final roomId = _currentRoomId;
    if (roomId == null) return;
    final myKey = await _e2ee.loadGroupSenderKey(roomId);
    if (myKey == null) return;

    String? ikPub = await _e2ee.loadIdentityKey(userId);
    if (ikPub == null) {
      final bundle = await _keyDs.fetchBundle(userId);
      if (bundle == null) return;
      ikPub = bundle.identityKey;
      await _e2ee.storeIdentityKey(userId, ikPub);
    }

    try {
      final encryptedKey =
          await _e2ee.encryptSenderKeyForRecipient(myKey, ikPub);
      await _keyDs.distributeGroupSenderKey(
          roomId, [GroupSenderKeyRecipient(userId: userId, encryptedKey: encryptedKey)]);
      debugPrint('[GroupE2EE] Distributed sender key to $userId');
    } catch (e) {
      debugPrint('[GroupE2EE] Failed to distribute key to $userId: $e');
    }
  }

  /// Re-decrypts encrypted group messages from [senderId] that are already in
  /// state (e.g. loaded from REST history before the sender key arrived).
  Future<void> _redecryptGroupMessages(
    Emitter<ChatRoomState> emit,
    String senderId,
    Uint8List senderKey,
  ) async {
    final toDecrypt = state.messages
        .where((m) =>
            m.senderId == senderId &&
            m.isEncrypted &&
            m.content.isNotEmpty &&
            m.iv != null)
        .toList();
    if (toDecrypt.isEmpty) return;

    debugPrint('[GroupE2EE] Re-decrypting ${toDecrypt.length} message(s) from $senderId');
    final decryptedMap = <String, ChatMessage>{};
    for (final m in toDecrypt) {
      try {
        final plaintext = await _e2ee.decrypt(senderKey, m.content, m.iv!);
        final updated = m.copyWith(content: plaintext, isEncrypted: false);
        decryptedMap[m.id] = updated;
        _cacheMessage(updated).catchError((_) {});
      } catch (e) {
        debugPrint('[GroupE2EE] Re-decrypt failed for ${m.id}: $e');
        decryptedMap[m.id] = m.copyWith(content: '', isEncrypted: false);
      }
    }

    if (decryptedMap.isEmpty) return;
    emit(state.copyWith(
        messages:
            _sorted(state.messages.map((m) => decryptedMap[m.id] ?? m).toList())));
  }

  int? _parseStatusCode(String message) {
    final match = RegExp(r'Chat API error (\d{3})').firstMatch(message);
    return int.tryParse(match?.group(1) ?? '');
  }

  void _onAdminGranted(_AdminGranted event, Emitter<ChatRoomState> emit) {
    final updatedParticipants = state.room?.participants
        .map((p) => p.userId == event.userId ? p.copyWith(isAdmin: true) : p)
        .toList();
    final updatedRoom = updatedParticipants != null
        ? state.room!.copyWith(participants: updatedParticipants)
        : state.room;
    final nowIAmAdmin = event.userId == _myUserId ? true : state.amIAdmin;
    final name = _participantName(event.userId);
    emit(state.copyWith(
      room: updatedRoom,
      amIAdmin: nowIAmAdmin,
      systemNotice: '$name is now a group admin',
    ));
  }

  void _onAdminRevoked(_AdminRevoked event, Emitter<ChatRoomState> emit) {
    final updatedParticipants = state.room?.participants
        .map((p) => p.userId == event.userId ? p.copyWith(isAdmin: false) : p)
        .toList();
    final updatedRoom = updatedParticipants != null
        ? state.room!.copyWith(participants: updatedParticipants)
        : state.room;
    final nowIAmAdmin = event.userId == _myUserId ? false : state.amIAdmin;
    final name = _participantName(event.userId);
    emit(state.copyWith(
      room: updatedRoom,
      amIAdmin: nowIAmAdmin,
      systemNotice: '$name is no longer a group admin',
    ));
  }

  void _onRoomSettingsUpdated(
      _RoomSettingsUpdated event, Emitter<ChatRoomState> emit) {
    ChatRoom? updatedRoom = state.room;
    if (updatedRoom != null) {
      if (event.adminOnly != null) {
        updatedRoom = updatedRoom.copyWith(adminOnly: event.adminOnly!);
      }
      if (event.name != null) {
        updatedRoom = updatedRoom.copyWith(name: event.name);
      }
    }
    emit(state.copyWith(room: updatedRoom));
  }

  void _onParticipantRemoved(
      _ParticipantRemoved event, Emitter<ChatRoomState> emit) {
    if (event.userId == _myUserId) {
      if (_currentRoomId != null) _clearRoomCache(_currentRoomId!).catchError((_) {});
      emit(state.copyWith(
        systemNotice: 'You were removed from this group.',
        isConnected: false,
        isConnecting: false,
      ));
      return;
    }
    final name = _participantName(event.userId);
    final updatedParticipants = state.room?.participants
        .where((p) => p.userId != event.userId)
        .toList();
    final updatedRoom = updatedParticipants != null
        ? state.room!.copyWith(participants: updatedParticipants)
        : state.room;
    emit(state.copyWith(
      room: updatedRoom,
      systemNotice: '$name was removed from the group.',
    ));
    _scheduleRoomReconcile();

    // Re-key: the removed member must not decrypt future messages.
    if (_isGroupRoom && _currentRoomId != null) {
      _rekeyGroup(_currentRoomId!).catchError((_) {});
    }
  }

  /// Resolves a userId to its best available display name from the current
  /// participant list. Falls back gracefully so UUIDs never surface in notices.
  String _participantName(String userId) {
    final p = state.room?.participants
        .where((p) => p.userId == userId)
        .firstOrNull;
    return p?.displayName ?? 'A member';
  }

  void _onLeft(ChatRoomLeft event, Emitter<ChatRoomState> emit) {
    // Leaving the page is leaving the composer. This — not close() — is the
    // hook that reliably runs when the room is popped: the page dispatches
    // ChatRoomLeft from its dispose, while the bloc itself may outlive the
    // route. Without it, walking out of a DM mid-sentence left our indicator
    // lit on the other screen until the backstop expiry.
    _stopTyping();

    _otpkPollTimer?.cancel();
    _reconcileDebounce?.cancel();
    _wsConnectionSub?.cancel();
    _wsConnectionSub = null;
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
    _cancelWsSubscriptions();
    // Drop who we thought was typing too — otherwise re-entering the room
    // renders a stale indicator from before we left, with no frame coming to
    // clear it because the sender stopped long ago.
    emit(state.copyWith(
      isConnected: false,
      isConnecting: false,
      typingUsers: const {},
    ));
    // Do NOT disconnect the shared WS — it is owned by ChatBackgroundService.
    if (_currentRoomId != null) _bgService.resume(_currentRoomId!);
  }

  @override
  Future<void> close() {
    _otpkPollTimer?.cancel();
    _reconcileDebounce?.cancel();
    _wsConnectionSub?.cancel();
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
    // Tell the room we stopped: closing the page is leaving the composer, and
    // without this our indicator sits on everyone else's screen until it times
    // out. The socket outlives this bloc, so it will actually be delivered.
    //
    // Guarded on _typingAnnounced, not on the throttle clock: that one is
    // nulled every time a stop is sent *and* every time the composer empties,
    // so it read as "nothing to retract" in cases where the indicator was very
    // much still lit on the other screen.
    _stopTyping();
    _cancelWsSubscriptions();
    // Leaving the room: we are no longer reading it, so messages arriving from
    // here on should notify. The socket stays open (owned by
    // ChatBackgroundService), which is exactly why this has to be said out loud
    // rather than inferred from the connection.
    _ws.sendFocus(null);
    // Do NOT disconnect the shared WS — it is owned by ChatBackgroundService.
    if (_currentRoomId != null) _bgService.resume(_currentRoomId!);
    return super.close();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<ChatMessage> _sorted(List<ChatMessage> messages) {
    final seen = <String>{};
    final unique = messages.where((m) => seen.add(m.id)).toList();
    unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return unique;
  }

  /// Build a ReplyPreview from a known message id in the current list.
  ReplyPreview? _buildReplyPreview(String messageId) {
    try {
      final msg = state.messages.firstWhere((m) => m.id == messageId);
      return ReplyPreview(
        id: msg.id,
        senderName: msg.senderName.isNotEmpty ? msg.senderName : msg.senderRole,
        content: msg.content.isNotEmpty ? msg.content : null,
        imageUrl: msg.imageUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
