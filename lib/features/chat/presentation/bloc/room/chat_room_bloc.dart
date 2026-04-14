import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
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
  String? _recipientId;        // other party's userId in a DM room
  bool _keysPublished = false; // whether we've published our bundle this session

  StreamSubscription<ChatMessage>? _wsMsgSub;
  StreamSubscription<LikeUpdate>? _wsLikeSub;
  StreamSubscription<PictureLikeUpdate>? _wsPicLikeSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
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
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onJoined(
    ChatRoomJoined event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    _reconnectAttempts = 0;

    _bgService.pause(event.roomId);

    if (_myUserId.isEmpty) {
      _myUserId = await _authService.getUserId();
    }

    // Initialise E2EE for direct rooms.
    if (event.room != null && event.room!.type == RoomType.direct) {
      _isDirectRoom = true;
      _recipientId = event.room!.participants
          .where((p) => p.userId != _myUserId)
          .map((p) => p.userId)
          .firstOrNull;

      // Generate and publish key bundle once — only if keys don't exist yet.
      if (!_keysPublished) {
        try {
          if (!await _e2ee.hasKeys()) {
            final bundle = await _e2ee.generateKeys();
            await _keyDs.publishBundle(bundle);
          }
          _keysPublished = true;
        } catch (e) {
          debugPrint('[E2EE] Failed to publish key bundle: $e');
        }
      }
    } else {
      _isDirectRoom = false;
      _recipientId = null;
    }

    List<ChatMessage> cached = [];
    try {
      cached = await _getCachedMessages(event.roomId);
    } catch (_) {}

    // Stage the share URL immediately so it appears in the input bar as soon
    // as the page opens — the user decides when (and whether) to send it.
    if (cached.isNotEmpty) {
      emit(ChatRoomState(
        messages: _sorted(cached),
        isConnecting: true,
        isSyncing: true,
        myUserId: _myUserId,
        pendingShareUrl: event.shareUrl,
      ));
    } else {
      emit(ChatRoomState(
        isLoadingHistory: true,
        isConnecting: true,
        isSyncing: true,
        myUserId: _myUserId,
        pendingShareUrl: event.shareUrl,
      ));
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
      if (_isDirectRoom && _recipientId != null) {
        try {
          // Reuse cached session key if available; otherwise perform X3DH.
          var sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
          String? ephemeralKey;
          String? myIdentityKey;
          if (sessionKey == null) {
            final recipientBundle = await _keyDs.fetchBundle(_recipientId!);
            final session = await _e2ee.createSendingSession(recipientBundle);
            sessionKey = session.sessionKey;
            ephemeralKey = session.ephemeralPublicKey;
            // Include our identity key so the receiver can complete X3DH.
            myIdentityKey = await _e2ee.identityPublicKey();
            await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
          }
          final encrypted = await _e2ee.encrypt(sessionKey, content);
          _ws.sendEncrypted(
            ciphertext: encrypted.ciphertext,
            iv: encrypted.iv,
            ephemeralKey: ephemeralKey ?? '',
            senderIdentityKey: myIdentityKey,
            replyToId: event.replyToId,
          );
        } catch (e) {
          debugPrint('[E2EE] Encrypt failed, sending plaintext: $e');
          _ws.send(content, replyToId: event.replyToId);
        }
      } else {
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

    // Decrypt E2EE messages in direct rooms.
    if (msg.isEncrypted &&
        msg.ciphertext != null &&
        msg.iv != null &&
        _currentRoomId != null) {
      try {
        Uint8List? sessionKey;
        // First message after X3DH carries the sender's ephemeral key and
        // identity key — use them to derive the shared session key.
        if (msg.ephemeralKey != null &&
            msg.ephemeralKey!.isNotEmpty &&
            msg.senderIdentityKey != null &&
            msg.senderIdentityKey!.isNotEmpty) {
          // Cache the sender's identity key for future reference.
          await _e2ee.storeIdentityKey(msg.senderId, msg.senderIdentityKey!);
          sessionKey = await _e2ee.deriveReceivingKey(
            senderIdentityKey: msg.senderIdentityKey!,
            senderEphemeralKey: msg.ephemeralKey!,
            consumedOtpkId: null,
          );
          // Cache it so subsequent messages can reuse the key.
          await _e2ee.storeSessionKey(_currentRoomId!, sessionKey);
        } else {
          sessionKey = await _e2ee.loadSessionKey(_currentRoomId!);
        }
        if (sessionKey != null) {
          final plaintext =
              await _e2ee.decrypt(sessionKey, msg.ciphertext!, msg.iv!);
          msg = msg.copyWith(content: plaintext, isEncrypted: false);
        }
      } catch (e) {
        debugPrint('[E2EE] Decrypt failed for msg ${msg.id}: $e');
        // Show the message as-is with an indicator rather than crashing.
        msg = msg.copyWith(content: '🔒 (encrypted message)', isEncrypted: false);
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

  void _onLeft(ChatRoomLeft event, Emitter<ChatRoomState> emit) {
    _reconnectTimer?.cancel();
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
    _ws.disconnect();
    emit(state.copyWith(isConnected: false, isConnecting: false));
    if (_currentRoomId != null) _bgService.resume(_currentRoomId!);
  }

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _wsMsgSub?.cancel();
    _wsLikeSub?.cancel();
    _wsPicLikeSub?.cancel();
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
