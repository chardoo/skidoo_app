import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart'
    show ChatWebSocketService, WsKeyBundlesEvent, WsKeyRotationEvent, WsParticipantKeyAvailable;
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
    on<_KeyRotationReceived>(_onKeyRotationReceived);
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
      _pendingBundleSpkId = null;
      // Default to re-key; _onKeyBundlesReceived cancels this if keys match cache.
      _needsRekey = true;
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
    } catch (e) {
      emit(state.copyWith(
        isLoadingHistory: false,
        isSyncing: false,
        errorMessage:
            state.messages.isEmpty ? 'Could not load messages.' : null,
      ));
    } finally {
      // Connect WS only after history is fully processed: the stored session
      // key is now correct, so _onKeyBundlesReceived will skip proactive setup.
      _connectWsInBackground(event.roomId);
    }
  }

  void _connectWsInBackground(String roomId) {
    debugPrint('[ChatBloc] _connectWsInBackground called for room: $roomId');
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _wsKeyRotationSub?.cancel();
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

      _wsKeyRotationSub = _ws.keyRotationEvents.listen(
        (event) {
          if (!isClosed) {
            add(_KeyRotationReceived(
                event.userId, event.identityKey, event.signedPreKey,
                registrationId: event.registrationId));
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
      debugPrint('[E2EE] send — isDirectRoom: $_isDirectRoom, recipientId: $_recipientId, needsRekey: $_needsRekey');
      if (_isDirectRoom && _recipientId != null) {
        try {
          var sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
          String? ephemeralKey;
          String? myIdentityKey;
          int? otpkId;
          int? bundleSpkId; // SPK ID from recipient bundle used in X3DH

          if (_needsRekey) {
            // Establish a fresh X3DH session. _needsRekey is true when keys
            // changed (detected by _onKeyBundlesReceived) or when no WS
            // key_bundles event has arrived yet (safe default from _onJoined).
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
              debugPrint('[E2EE] Re-key complete (otpkId: $otpkId)');
            } else if (sessionKey == null) {
              debugPrint('[E2EE] Re-key: no bundle and no key — sending plaintext');
              _ws.send(content, replyToId: event.replyToId);
              _cacheMessage(optimistic).catchError((_) {});
              return;
            } else {
              debugPrint('[E2EE] Re-key: no bundle — reusing existing key (degraded)');
            }
          } else if (sessionKey == null) {
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
            bundleSpkId = recipientBundle.signedPreKeyId;
            myIdentityKey = await _e2ee.identityPublicKey();
            await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
            await _e2ee.storeCachedBundle(
              _recipientId!,
              identityKey: recipientBundle.identityKey,
              signedPreKeyId: recipientBundle.signedPreKeyId,
            );
            debugPrint('[E2EE] Session established (otpkId: $otpkId)');
          } else if (_pendingEphemeralKey != null) {
            // Session was pre-established by _setupE2EESession — use its
            // X3DH header for the first encrypted message, then clear it.
            ephemeralKey = _pendingEphemeralKey;
            otpkId = _pendingOtpkId;
            bundleSpkId = _pendingBundleSpkId;
            myIdentityKey = await _e2ee.identityPublicKey();
            _pendingEphemeralKey = null;
            _pendingOtpkId = null;
            _pendingBundleSpkId = null;
            debugPrint('[E2EE] Using pre-established session (proactive X3DH)');
          } else {
            debugPrint('[E2EE] Reusing cached session key');
          }
          final keyHex = sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          final encrypted = await _e2ee.encrypt(sessionKey, content);
          debugPrint('[E2EE] Encrypted OK (session: ${ephemeralKey != null ? "new X3DH" : "cached"}, keyPrefix=$keyHex) — sending over WS');
          _ws.sendEncrypted(
            ciphertext: encrypted.ciphertext,
            iv: encrypted.iv,
            ephemeralKey: ephemeralKey,
            senderIdentityKey: myIdentityKey,
            otpkId: otpkId,
            senderSpkId: bundleSpkId,
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
        // MAC error on an ongoing message (no X3DH header, not our own echo)
        // means the stored session key doesn't match the sender's. Wipe it and
        // schedule a rekey so the next outbound message carries a fresh X3DH
        // header — the sender derives the new session key from that header and
        // both sides re-synchronise automatically.
        final isOngoing = msg.ephemeralKey == null || msg.ephemeralKey!.isEmpty;
        final isFromOther = msg.senderId != _myUserId;
        if (isOngoing && isFromOther && _currentRoomId != null) {
          await _e2ee.deleteSessionKey(_currentRoomId!);
          _needsRekey = true;
          debugPrint('[E2EE] MAC error on ongoing message — session cleared, rekey on next send');
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

    if (updated.any((m) => m.id == msg.id)) return;

    emit(state.copyWith(messages: _sorted([msg, ...updated])));
    _cacheMessage(msg).catchError((_) {});

    if (_currentRoomId != null) {
      _markAsRead(_currentRoomId!).then((_) {
        _bgService.onUnreadUpdate?.call();
      }).catchError((_) {});
    }
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
    // Skip if a session key already exists. Re-deriving would attempt to use
    // the OTPK private key, which is single-use and deleted after the first
    // derivation. A second pass silently omits DH4 (the catch in
    // deriveReceivingKey swallows the missing-key error) and produces a
    // mismatched key that overwrites the correct stored key.
    if (await _e2ee.loadSessionKey(_currentRoomId!) != null) return;

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
    if (opener == null) return;

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

    if (await _e2ee.loadSessionKey(_currentRoomId!) == null) {
      debugPrint('[E2EE] key_bundles: keys unchanged, no session — proactive X3DH');
      await _setupE2EESession(emit, bundle: bundle);
    } else {
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
      await _e2ee.storeSessionKey(_currentRoomId!, session.sessionKey);
      await _e2ee.storeCachedBundle(
        _recipientId!,
        identityKey: resolvedBundle.identityKey,
        signedPreKeyId: resolvedBundle.signedPreKeyId,
      );
      _pendingEphemeralKey = session.ephemeralPublicKey;
      _pendingOtpkId = session.otpkId;
      _pendingBundleSpkId = resolvedBundle.signedPreKeyId;
      final kHex = session.sessionKey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      debugPrint('[E2EE] Session pre-established (otpkId: ${session.otpkId}, keyPrefix=$kHex)');
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

  void _onLeft(ChatRoomLeft event, Emitter<ChatRoomState> emit) {
    _reconnectTimer?.cancel();
    _otpkPollTimer?.cancel();
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _wsKeyBundlesSub?.cancel();
    _wsParticipantKeySub?.cancel();
    _wsKeyRotationSub?.cancel();
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
    _wsKeyRotationSub?.cancel();
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
