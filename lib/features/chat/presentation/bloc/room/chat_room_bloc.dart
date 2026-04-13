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
import 'package:skidoo_app/models/chat/like_update.dart';
import 'package:skidoo_app/services/auth_service.dart';

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

  String? _currentRoomId;
  String _myUserId = '';
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
  })  : _getMessages = getRoomMessages,
        _getCachedMessages = getCachedMessages,
        _cacheMessage = cacheMessage,
        _markAsRead = markRoomAsRead,
        _uploadImage = uploadImage,
        _ws = wsService,
        _authService = authService,
        _bgService = bgService,
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

    List<ChatMessage> cached = [];
    try {
      cached = await _getCachedMessages(event.roomId);
    } catch (_) {}

    if (cached.isNotEmpty) {
      emit(ChatRoomState(
        messages: _sorted(cached),
        isConnecting: true,
        isSyncing: true,
        myUserId: _myUserId,
      ));
    } else {
      emit(ChatRoomState(
        isLoadingHistory: true,
        isConnecting: true,
        isSyncing: true,
        myUserId: _myUserId,
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
    // Auto-send a share URL that was staged before the WS was ready.
    final shareUrl = state.pendingShareUrl;
    if (shareUrl != null) {
      emit(state.copyWith(clearPendingShareUrl: true));
      _ws.send(null, imageUrl: shareUrl);
      final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final optimistic = ChatMessage(
        id: tempId,
        roomId: _currentRoomId ?? '',
        senderId: _myUserId,
        senderRole: ChatConfig.roleClient,
        content: '',
        imageUrl: shareUrl,
        createdAt: DateTime.now(),
        isLocal: true,
      );
      emit(state.copyWith(messages: _sorted([optimistic, ...state.messages])));
      _cacheMessage(optimistic).catchError((_) {});
    }
  }

  void _onUrlStaged(ChatRoomUrlStaged event, Emitter<ChatRoomState> emit) {
    if (_ws.isConnected) {
      // WS already up — send immediately.
      _ws.send(null, imageUrl: event.imageUrl);
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
    } else {
      // WS not ready yet — queue it; _onWsConnected will send it.
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
    final hasText = content != null && content.isNotEmpty;
    final hasImage = pendingPath != null;

    if (!hasText && !hasImage) return;

    final replyPreview =
        event.replyToId != null ? _buildReplyPreview(event.replyToId!) : null;

    if (hasImage) {
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
        // Restore the pending image so the user can retry.
        emit(state.copyWith(
          isUploadingImage: false,
          pendingImagePath: pendingPath,
          errorMessage: 'Failed to upload image.',
        ));
      }
    } else {
      // Text-only message — stays synchronous.
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
      _ws.send(content, replyToId: event.replyToId);
      _cacheMessage(optimistic).catchError((_) {});
    }
  }

  /// Stage the picked image — no upload yet.
  void _onImagePicked(
    ChatRoomImagePicked event,
    Emitter<ChatRoomState> emit,
  ) {
    emit(state.copyWith(pendingImagePath: event.filePath));
  }

  void _onImageCleared(
    ChatRoomImageCleared event,
    Emitter<ChatRoomState> emit,
  ) {
    emit(state.copyWith(clearPendingImage: true));
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

  void _onReceived(
    ChatRoomMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final msg = event.message;

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
