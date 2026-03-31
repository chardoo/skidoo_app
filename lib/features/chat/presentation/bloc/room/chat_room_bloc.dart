import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'chat_room_event.dart';
part 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetRoomMessagesUseCase _getMessages;
  final GetCachedMessagesUseCase _getCachedMessages;
  final CacheMessageUseCase _cacheMessage;
  final MarkRoomAsReadUseCase _markAsRead;
  final ChatWebSocketService _ws;
  final AuthService _authService;
  final ChatBackgroundService _bgService;

  String? _currentRoomId;
  String _myUserId = '';
  StreamSubscription<ChatMessage>? _wsSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  DateTime? _lastConnectedAt;
  static const int _maxReconnectAttempts = 5;

  ChatRoomBloc({
    required GetRoomMessagesUseCase getRoomMessages,
    required GetCachedMessagesUseCase getCachedMessages,
    required CacheMessageUseCase cacheMessage,
    required MarkRoomAsReadUseCase markRoomAsRead,
    required ChatWebSocketService wsService,
    required AuthService authService,
    required ChatBackgroundService bgService,
  })  : _getMessages = getRoomMessages,
        _getCachedMessages = getCachedMessages,
        _cacheMessage = cacheMessage,
        _markAsRead = markRoomAsRead,
        _ws = wsService,
        _authService = authService,
        _bgService = bgService,
        super(const ChatRoomState()) {
    on<ChatRoomJoined>(_onJoined);
    on<ChatRoomMessageSent>(_onSent);
    on<ChatRoomMessageReceived>(_onReceived);
    on<ChatRoomLoadMoreRequested>(_onLoadMore);
    on<ChatRoomLeft>(_onLeft);
    on<_WsConnected>(_onWsConnected);
    on<_WsFailed>(_onWsFailed);
    on<_WsDropped>(_onWsDropped);
    on<_WsGaveUp>(_onWsGaveUp);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  Future<void> _onJoined(
    ChatRoomJoined event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    _reconnectAttempts = 0;

    // Hand off the connection to this bloc; background service stops listening.
    _bgService.pause(event.roomId);

    // Cache userId once so _onSent never has to await it.
    if (_myUserId.isEmpty) {
      _myUserId = await _authService.getUserId();
    }

    // 1. Load cache instantly — skip full-screen loader when cache exists.
    List<ChatMessage> cached = [];
    try {
      cached = await _getCachedMessages(event.roomId);
    } catch (_) {}

    if (cached.isNotEmpty) {
      // Show cached content immediately; thin sync bar instead of blocker.
      emit(ChatRoomState(
        messages: _sorted(cached),
        isConnecting: true,
        isSyncing: true,
      ));
    } else {
      emit(const ChatRoomState(
        isLoadingHistory: true,
        isConnecting: true,
        isSyncing: true,
      ));
    }

    // 2. Kick off WS in the background — does NOT block history loading.
    _connectWsInBackground(event.roomId);

    // 3. Fetch fresh from API, diff against cache, merge new messages in.
    try {
      final fresh = await _getMessages(event.roomId);
      await _markAsRead(event.roomId);
      // Notify rooms list immediately so the badge clears without a page reload.
      _bgService.onUnreadUpdate?.call();

      // Only add messages not already in the displayed set so the list doesn't
      // visually "reset" — existing messages stay in place, new ones slide in.
      final knownIds = state.messages.map((m) => m.id).toSet();
      final incoming = fresh.where((m) => !knownIds.contains(m.id)).toList();

      // Merge: keep any still-pending optimistic messages + confirmed messages.
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
        errorMessage: state.messages.isEmpty ? 'Could not load messages.' : null,
      ));
    }
  }

  /// Connects to the WebSocket without blocking the BLoC handler.
  void _connectWsInBackground(String roomId) {
    debugPrint('[ChatBloc] _connectWsInBackground called for room: $roomId');
    _wsSub?.cancel();
    _ws.connect(roomId).then((_) {
      if (isClosed) return;
      _wsSub = _ws.messages.listen(
        (msg) {
          if (!isClosed) add(ChatRoomMessageReceived(msg));
        },
        onDone: () {
          // Server closed the socket unexpectedly — try to reconnect.
          if (!isClosed) add(const _WsDropped());
        },
        onError: (_) {
          if (!isClosed) add(const _WsDropped());
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

  void _onWsFailed(_WsFailed event, Emitter<ChatRoomState> emit) {
    emit(state.copyWith(
      isConnected: false,
      isConnecting: false,
      errorMessage: 'Chat connection failed. Messages may be delayed.',
    ));
    _scheduleReconnect();
  }

  void _onWsDropped(_WsDropped event, Emitter<ChatRoomState> emit) {
    // If the connection lasted less than 3 seconds, count it as a failed attempt.
    final connectedFor = _lastConnectedAt == null
        ? null
        : DateTime.now().difference(_lastConnectedAt!);
    if (connectedFor == null || connectedFor.inSeconds < 3) {
      _reconnectAttempts++;
      debugPrint('[ChatBloc] WS dropped immediately (attempt $_reconnectAttempts)');
    } else {
      // Stable connection that dropped — reset counter for fresh backoff.
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

  /// Exponential backoff: 2, 4, 8, 16, 30 seconds (capped).
  int _backoffSeconds(int attempt) =>
      attempt == 0 ? 2 : (2 << attempt).clamp(2, 30);

  void _onSent(
    ChatRoomMessageSent event,
    Emitter<ChatRoomState> emit,
  ) {
    if (!_ws.isConnected) {
      emit(state.copyWith(
          errorMessage: 'Not connected — please wait or retry.'));
      return;
    }

    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      roomId: _currentRoomId ?? '',
      senderId: _myUserId,
      senderRole: ChatConfig.roleClient,
      content: event.content,
      createdAt: DateTime.now(),
      isLocal: true,
    );

    // Emit first — message appears on the next frame, no async delay.
    emit(state.copyWith(messages: _sorted([optimistic, ...state.messages])));
    _ws.send(event.content);
    // Cache in the background — fire and forget.
    _cacheMessage(optimistic).catchError((_) {});
  }

  void _onReceived(
    ChatRoomMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final msg = event.message;

    // Remove matching optimistic message.
    final updated = state.messages
        .where((m) => !(m.isLocal && m.content == msg.content))
        .toList();

    // Avoid duplicates.
    if (updated.any((m) => m.id == msg.id)) return;

    emit(state.copyWith(messages: _sorted([msg, ...updated])));

    // Persist confirmed message and clean up the optimistic placeholder.
    _cacheMessage(msg).catchError((_) {});

    // Mark incoming message as read immediately (user is in the room).
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
    _wsSub?.cancel();
    _ws.disconnect();
    emit(state.copyWith(isConnected: false, isConnecting: false));
    // Return the connection to the background service.
    if (_currentRoomId != null) _bgService.resume(_currentRoomId!);
  }

  @override
  Future<void> close() {
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _ws.disconnect();
    // Return the connection to the background service.
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
}
