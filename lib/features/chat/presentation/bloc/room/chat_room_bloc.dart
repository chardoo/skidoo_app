import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart'
    show ChatWebSocketService, WsKeyBundlesEvent, WsParticipantKeyAvailable;
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/models/chat/like_update.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/services/e2ee_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_key_datasource.dart';

part 'chat_room_event.dart';
part 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetRoomMessagesUseCase _getMessages;
  final GetCachedMessagesUseCase _getCachedMessages;
  final CacheMessageUseCase _cacheMessage;
  final MarkRoomAsReadUseCase _markAsRead;
  final UploadChatImageUseCase _uploadImage;
  final ChatWebSocketService _ws;
  final AuthService _authService;
  final ChatBackgroundService _bgService;
  final E2eeService _e2ee;
  final ChatKeyDataSource _keyDs;

  String? _currentRoomId;
  String _myUserId = '';

  // E2EE state
  bool _isDirectRoom = false;
  String? _recipientId;          // other party's userId in a DM room
  bool _keysPublished = false;   // whether we've published our bundle this session
  // Stored after proactive X3DH so the first encrypted message carries the
  // correct X3DH header without re-doing the handshake.
  String? _pendingEphemeralKey;
  int? _pendingOtpkId;

  StreamSubscription<ChatMessage>? _wsMsgSub;
  StreamSubscription<LikeUpdate>? _wsLikeSub;
  StreamSubscription<PictureLikeUpdate>? _wsPicLikeSub;
  StreamSubscription<WsKeyBundlesEvent>? _wsKeyBundlesSub;
  StreamSubscription<WsParticipantKeyAvailable>? _wsParticipantKeySub;
  Timer? _reconnectTimer;
  Timer? _otpkPollTimer;
  int _reconnectAttempts = 0;
  static const int _otpkReplenishThreshold = 10;
  static const int _otpkReplenishBatchSize = 100;
  DateTime? _lastConnectedAt;
  static const int _maxReconnectAttempts = 5;

  ChatRoomBloc({
    required GetRoomMessagesUseCase getRoomMessages,
    required GetCachedMessagesUseCase getCachedMessages,
    required CacheMessageUseCase cacheMessage,
    required MarkRoomAsReadUseCase markRoomAsRead,
    required UploadChatImageUseCase uploadImage,
    required ChatWebSocketService wsService,
    required AuthService authService,
    required ChatBackgroundService bgService,
    required E2eeService e2eeService,
    required ChatKeyDataSource keyDataSource,
  })  : _getMessages = getRoomMessages,
        _getCachedMessages = getCachedMessages,
        _cacheMessage = cacheMessage,
        _markAsRead = markRoomAsRead,
        _uploadImage = uploadImage,
        _ws = wsService,
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
    on<_WsFailed>(_onWsFailed);
    on<_WsDropped>(_onWsDropped);
    on<_WsGaveUp>(_onWsGaveUp);
    on<_LikeUpdateReceived>(_onLikeUpdateReceived);
    on<_PictureLikeUpdateReceived>(_onPictureLikeUpdateReceived);
    on<_KeyBundlesReceived>(_onKeyBundlesReceived);
    on<_ParticipantKeyAvailable>(_onParticipantKeyAvailable);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onJoined(
    ChatRoomJoined event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    _reconnectAttempts = 0;
    _bgService.pause(event.roomId);

    final isDm = event.room?.type == RoomType.direct;

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

    // ── Emit cached messages IMMEDIATELY ──────────────────────────────────────
    // The user sees existing messages before the WS connects or any network
    // call completes. This is the first and most important state transition.
    emit(ChatRoomState(
      messages: cached.isNotEmpty ? _sorted(cached) : const [],
      isLoadingHistory: cached.isEmpty,
      isConnecting: true,
      isSyncing: true,
      myUserId: _myUserId,
      pendingShareUrl: event.shareUrl,
    ));

    // ── E2EE setup (DM only) — runs after the emit, never blocks it ───────────
    if (isDm) {
      _isDirectRoom = true;
      _pendingEphemeralKey = null;
      _pendingOtpkId = null;
      _recipientId = event.room!.participants
          .where((p) => p.userId != _myUserId)
          .map((p) => p.userId)
          .firstOrNull;
      debugPrint('[E2EE] DM — recipientId: $_recipientId');

      // Publish bundle in the background — never await, never block the UI.
      if (!_keysPublished) {
        _publishBundleInBackground();
      }

      _otpkPollTimer?.cancel();
      _otpkPollTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => _replenishOtpksIfNeeded(),
      );
    } else {
      _isDirectRoom = false;
      _recipientId = null;
    }

    _connectWsInBackground(event.roomId);

    try {
      final fresh = await _getMessages(event.roomId);
      await _markAsRead(event.roomId);
      _bgService.onUnreadUpdate?.call();

      final knownIds = state.messages.map((m) => m.id).toSet();
      final incoming = fresh.where((m) => !knownIds.contains(m.id)).toList();
      final merged = _sorted([...state.messages, ...incoming]);

      emit(state.copyWith(
        messages: merged,
        isLoadingHistory: false,
        isSyncing: false,
        clearError: true,
        // pendingShareUrl is preserved via copyWith (not cleared here)
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingHistory: false,
        isSyncing: false,
        errorMessage:
            state.messages.isEmpty ? 'Could not load messages.' : null,
      ));
    }
  }

  void _connectWsInBackground(String roomId) {
    debugPrint('[ChatBloc] _connectWsInBackground called for room: $roomId');
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _ws.connect(roomId).then((_) {
      if (isClosed) return;

      _wsMsgSub = _ws.messages.listen(
        (msg) {
          if (!isClosed) add(ChatRoomMessageReceived(msg));
        },
        onDone: () {
          if (!isClosed) add(const _WsDropped());
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

      debugPrint('[ChatBloc] WS connected successfully');
      if (!isClosed) add(const _WsConnected());
    }).catchError((e) {
      debugPrint('[ChatBloc] WS connect error: $e');
      if (!isClosed) add(_WsFailed(e.toString()));
    });
  }

  void _onWsConnected(_WsConnected event, Emitter<ChatRoomState> emit) {
    _lastConnectedAt = DateTime.now();
    _reconnectTimer?.cancel();
    emit(state.copyWith(
      isConnected: true,
      isConnecting: false,
      clearError: true,
    ));
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
      createdAt: DateTime.now(),
      isLocal: true,
    );
    emit(state.copyWith(messages: _sorted([optimistic, ...state.messages])));
    _cacheMessage(optimistic).catchError((_) {});

    if (_ws.isConnected) {
      // WS already up — send immediately.
      _ws.send(null, imageUrl: event.imageUrl);
    } else {
      // WS not ready yet — store URL; _onWsConnected will send it.
      emit(state.copyWith(pendingShareUrl: event.imageUrl));
    }
  }

  void _onWsFailed(_WsFailed event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnected: false,
      isConnecting: false,
      errorMessage: 'Chat connection failed. Messages may be delayed.',
    ));
    _scheduleReconnect();
  }

  void _onWsDropped(_WsDropped event, Emitter<ChatRoomState> emit) {
    final connectedFor = _lastConnectedAt == null
        ? null
        : DateTime.now().difference(_lastConnectedAt!);
    if (connectedFor == null || connectedFor.inSeconds < 3) {
      _reconnectAttempts++;
      debugPrint(
          '[ChatBloc] WS dropped immediately (attempt $_reconnectAttempts)');
    } else {
      _reconnectAttempts = 1;
    }
    emit(state.copyWith(
      isConnected: false,
      isConnecting: _reconnectAttempts < _maxReconnectAttempts,
    ));
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_currentRoomId == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (!isClosed) add(const _WsGaveUp());
      return;
    }

    _reconnectTimer?.cancel();
    final delay = Duration(seconds: _backoffSeconds(_reconnectAttempts));
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () {
      if (!isClosed && _currentRoomId != null) {
        _connectWsInBackground(_currentRoomId!);
      }
    });
  }

  void _onWsGaveUp(_WsGaveUp event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnecting: false,
      isConnected: false,
      errorMessage: 'Connection lost. Pull down to refresh.',
    ));
  }

  int _backoffSeconds(int attempt) =>
      attempt == 0 ? 2 : (2 << attempt).clamp(2, 30);

  Future<void> _onSent(
    ChatRoomMessageSent event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_ws.isConnected) {
      emit(state.copyWith(
          errorMessage: 'Not connected — please wait or retry.'));
      return;
    }

    final content = event.content?.trim();
    final pendingPath = state.pendingImagePath;
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
        createdAt: DateTime.now(),
        isLocal: true,
      );
      emit(state.copyWith(
        messages: _sorted([optimistic, ...state.messages]),
        clearPendingShareUrl: true,
        clearReply: true,
      ));
      _ws.send(hasText ? content : null,
          imageUrl: pendingUrl, replyToId: event.replyToId);
      _cacheMessage(optimistic).catchError((_) {});
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
        final imageUrl = await _uploadImage(File(pendingPath));
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
          createdAt: DateTime.now(),
          isLocal: true,
        );

        emit(state.copyWith(
          isUploadingImage: false,
          messages: _sorted([optimistic, ...state.messages]),
        ));

        _ws.send(
          hasText ? content : null,
          imageUrl: imageUrl,
          replyToId: event.replyToId,
        );
        _cacheMessage(optimistic).catchError((_) {});
      } catch (_) {
        // Restore the pending media so the user can retry.
        emit(state.copyWith(
          isUploadingImage: false,
          pendingImagePath: pendingPath,
          pendingIsVideo: pendingIsVideo,
          errorMessage: pendingIsVideo ? 'Failed to upload video.' : 'Failed to upload image.',
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
        createdAt: DateTime.now(),
        isLocal: true,
      );

      emit(state.copyWith(
        messages: _sorted([optimistic, ...state.messages]),
        clearReply: true,
      ));

      // Encrypt the message for direct (DM) rooms.
      debugPrint('[E2EE] send — isDirectRoom: $_isDirectRoom, recipientId: $_recipientId');
      if (_isDirectRoom && _recipientId != null) {
        try {
          // Reuse cached session key if available; otherwise perform X3DH.
          var sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
          String? ephemeralKey;
          String? myIdentityKey;
          int? otpkId;
          if (sessionKey == null) {
            debugPrint('[E2EE] No session key — fetching recipient bundle for $_recipientId');
            final recipientBundle = await _keyDs.fetchBundle(_recipientId!);
            if (recipientBundle == null) {
              debugPrint('[E2EE] Recipient has no bundle — sending plaintext');
              _ws.send(content, replyToId: event.replyToId);
              _cacheMessage(optimistic).catchError((_) {});
              return;
            }
            debugPrint('[E2EE] Got recipient bundle — running X3DH');
            final session = await _e2ee.createSendingSession(recipientBundle);
            sessionKey = session.sessionKey;
            ephemeralKey = session.ephemeralPublicKey;
            otpkId = session.otpkId;
            myIdentityKey = await _e2ee.identityPublicKey();
            await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
            debugPrint('[E2EE] Session established (otpkId: $otpkId)');
          } else if (_pendingEphemeralKey != null) {
            // Session was pre-established by _setupE2EESession — use its
            // X3DH header for the first encrypted message, then clear it.
            ephemeralKey = _pendingEphemeralKey;
            otpkId = _pendingOtpkId;
            myIdentityKey = await _e2ee.identityPublicKey();
            _pendingEphemeralKey = null;
            _pendingOtpkId = null;
            debugPrint('[E2EE] Using pre-established session (proactive X3DH)');
          } else {
            debugPrint('[E2EE] Reusing cached session key');
          }
          final encrypted = await _e2ee.encrypt(sessionKey, content);
          debugPrint('[E2EE] Encrypted OK (session: ${ephemeralKey != null ? "new X3DH" : "cached"}) — sending over WS');
          _ws.sendEncrypted(
            ciphertext: encrypted.ciphertext,
            iv: encrypted.iv,
            ephemeralKey: ephemeralKey,
            senderIdentityKey: myIdentityKey,
            otpkId: otpkId,
            replyToId: event.replyToId,
          );
        } catch (e) {
          debugPrint('[E2EE] Encrypt failed, sending plaintext: $e');
          _ws.send(content, replyToId: event.replyToId);
        }
      } else {
        debugPrint('[E2EE] Not a DM or no recipient — sending plaintext');
        _ws.send(content, replyToId: event.replyToId);
      }

      _cacheMessage(optimistic).catchError((_) {});
    }
  }

  /// Stage the picked image/video — no upload yet.
  void _onImagePicked(
    ChatRoomImagePicked event,
    Emitter<ChatRoomState> emit,
  ) {
    emit(state.copyWith(
      pendingImagePath: event.filePath,
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
      _ws.sendUnlike(event.eventId);
    } else {
      _ws.sendLike(event.eventId);
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
      _ws.sendPictureUnlike(event.pictureId);
    } else {
      _ws.sendPictureLike(event.pictureId);
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

    // Decrypt E2EE messages — only in direct rooms, never in global/event/photo rooms.
    // The server stores the ciphertext in the `content` field when is_encrypted=true
    // (there is no separate `ciphertext` field in the forwarded/echoed message).
    if (_isDirectRoom &&
        msg.isEncrypted &&
        msg.content.isNotEmpty &&
        msg.iv != null &&
        _currentRoomId != null) {
      try {
        Uint8List? sessionKey;
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
          await _e2ee.storeIdentityKey(msg.senderId, msg.senderIdentityKey!);
          sessionKey = await _e2ee.deriveReceivingKey(
            senderIdentityKey: msg.senderIdentityKey!,
            senderEphemeralKey: msg.ephemeralKey!,
            consumedOtpkId: msg.otpkId,
          );
          await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
          debugPrint('[E2EE] Receiver: derived session key via X3DH (otpkId: ${msg.otpkId})');
        } else {
          // Own echo or subsequent message — reuse the stored session key.
          sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
          debugPrint('[E2EE] Receiver: reusing cached session key (own echo or cont. msg)');
        }
        if (sessionKey != null) {
          // Content field carries the base64url ciphertext when is_encrypted=true.
          final plaintext = await _e2ee.decrypt(sessionKey, msg.content, msg.iv!);
          debugPrint('[E2EE] Decrypted OK: "${plaintext.length > 30 ? plaintext.substring(0, 30) : plaintext}..."');
          msg = msg.copyWith(content: plaintext, isEncrypted: false);
        } else {
          debugPrint('[E2EE] No session key available — showing empty message');
          msg = msg.copyWith(content: '', isEncrypted: false);
        }
      } catch (e) {
        debugPrint('[E2EE] Decrypt failed for msg ${msg.id}: $e');
        msg = msg.copyWith(content: '', isEncrypted: false);
      }
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

    if (updated.any((m) => m.id == msg.id)) return;

    emit(state.copyWith(messages: _sorted([msg, ...updated])));
    _cacheMessage(msg).catchError((_) {});

    if (_currentRoomId != null) {
      _markAsRead(_currentRoomId!).then((_) {
        _bgService.onUnreadUpdate?.call();
      }).catchError((_) {});
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

  /// Server sent key bundles for all DM participants on room join.
  /// The WS payload carries IK + SPK inline — build the bundle from it
  /// directly and run X3DH without any REST call. OTPK (DH4) is optional
  /// per the X3DH spec; we skip it here and accept slightly weaker forward
  /// secrecy for the proactive session setup.
  Future<void> _onKeyBundlesReceived(
    _KeyBundlesReceived event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (!_isDirectRoom || _recipientId == null || _currentRoomId == null) return;
    if (await _e2ee.loadSessionKey(_currentRoomId!) != null) {
      emit(state.copyWith(isE2EEReady: true));
      return;
    }

    final recipientData = event.bundles
        .where((b) => b['userId'] == _recipientId)
        .firstOrNull;
    if (recipientData == null) return;

    final bundle = _bundleFromWsData(recipientData);
    if (bundle == null) return;

    debugPrint('[E2EE] key_bundles: building session from WS payload (no OTPK)');
    await _setupE2EESession(emit, bundle: bundle);
  }

  /// A participant who previously had no E2EE keys just published them.
  /// Same approach — use the inline IK + SPK from the WS event.
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
    if (await _e2ee.loadSessionKey(_currentRoomId!) != null) {
      emit(state.copyWith(isE2EEReady: true));
      return;
    }

    final bundle = _bundleFromWsData({
      'identityKey': event.identityKey,
      'signedPreKey': event.signedPreKey,
    });
    if (bundle == null) return;

    debugPrint('[E2EE] participant_key_available: building session from WS payload (no OTPK)');
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
      );
    } catch (_) {
      return null;
    }
  }

  /// Runs X3DH with [bundle] (or falls back to a REST fetch if omitted),
  /// stores the session key, and caches the X3DH header for the first message.
  Future<void> _setupE2EESession(
    Emitter<ChatRoomState> emit, {
    RecipientKeyBundle? bundle,
  }) async {
    try {
      final resolvedBundle = bundle ?? await _keyDs.fetchBundle(_recipientId!);
      if (resolvedBundle == null) return;
      final session = await _e2ee.createSendingSession(resolvedBundle);
      await _e2ee.storeSessionKey(_currentRoomId!, session.sessionKey);
      _pendingEphemeralKey = session.ephemeralPublicKey;
      _pendingOtpkId = session.otpkId;
      debugPrint('[E2EE] Session pre-established (otpkId: ${session.otpkId})');
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
        _keysPublished = true;
        debugPrint('[E2EE] Bundle published OK (${bundle.oneTimePreKeys.length} OTPKs)');
        _replenishOtpksIfNeeded().catchError((_) {});
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

  void _onLeft(ChatRoomLeft event, Emitter<ChatRoomState> emit) {
    _reconnectTimer?.cancel();
    _otpkPollTimer?.cancel();
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _ws.disconnect();
    emit(state.copyWith(isConnected: false, isConnecting: false));
    if (_currentRoomId != null) _bgService.resume(_currentRoomId!);
  }

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _otpkPollTimer?.cancel();
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _ws.disconnect();
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
