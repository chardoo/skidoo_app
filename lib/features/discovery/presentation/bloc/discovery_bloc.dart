import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/models/chat/like_update.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'discovery_event.dart';
part 'discovery_state.dart';

const _pageSize = 10;

/// How long to keep a WS connection alive after a card leaves the viewport.
const _disconnectDelay = Duration(seconds: 30);

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final GetRandomImagesUseCase _getRandomImagesUseCase;
  final GetEventReactionUseCase _getEventReaction;
  final GetEventRoomUseCase _getEventRoom;
  final AuthService _authService;

  // ── Per-event WebSocket sessions ──────────────────────────────────────────
  final Map<String, ChatWebSocketService> _activeSessions = {};
  final Map<String, StreamSubscription<LikeUpdate>> _likeSubscriptions = {};
  final Map<String, Timer> _disconnectTimers = {};
  // Guards against duplicate concurrent connect attempts for the same event.
  final Set<String> _connecting = {};

  String? _currentUserId;

  DiscoveryBloc({
    required GetRandomImagesUseCase getRandomImagesUseCase,
    required GetEventReactionUseCase getEventReaction,
    required GetEventRoomUseCase getEventRoom,
  })  : _getRandomImagesUseCase = getRandomImagesUseCase,
        _getEventReaction = getEventReaction,
        _getEventRoom = getEventRoom,
        _authService = sl<AuthService>(),
        super(const DiscoveryState()) {
    on<DiscoveryLoadRequested>(_onLoadRequested);
    on<DiscoveryLoadMoreRequested>(_onLoadMoreRequested);
    on<DiscoveryReactionToggled>(_onReactionToggled);
    on<DiscoveryEventVisible>(_onEventVisible);
    on<DiscoveryEventHidden>(_onEventHidden);
    on<_DiscoveryLikeUpdateReceived>(_onReactionUpdated);
    on<_DiscoveryReactionsPatchReceived>(_onReactionsPatchReceived);

    // Load current user ID once so we can identify own updates later.
    _authService.getUserId().then((id) {
      if (id.isNotEmpty) _currentUserId = id;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _getUserId() async {
    if (_currentUserId != null) return _currentUserId;
    try {
      final id = await _authService.getUserId();
      if (id.isNotEmpty) {
        _currentUserId = id;
        return id;
      }
    } catch (_) {}
    return null;
  }

  Future<List<EventDiscovery>> _enrichWithReactions(
    List<EventDiscovery> events,
    String userId,
  ) async {
    final futures = events.map(
      (e) => _getEventReaction(e.id, userId).catchError((_) => EventReaction.empty()),
    );
    final reactions = await Future.wait(futures);
    return List.generate(events.length, (i) {
      final r = reactions[i];
      return events[i].copyWith(
        likes: r.likes,
        dislikes: r.dislikes,
        userReaction: r.userReaction,
        clearReaction: r.userReaction == null,
      );
    });
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _onLoadRequested(
      DiscoveryLoadRequested event, Emitter<DiscoveryState> emit) async {
    emit(const DiscoveryState(isLoading: true));
    try {
      final userId = await _getUserId();
      final events = await _getRandomImagesUseCase(
        take: _pageSize,
        userId: userId,
      );
      // ✅ Show events immediately — don't wait for reactions.
      emit(DiscoveryState(events: events, currentUserId: userId));
      // Enrich reactions in background and patch state once ready.
      if (userId != null && events.isNotEmpty) {
        _enrichInBackground(events, userId);
      }
    } on NetworkException {
      emit(const DiscoveryState(errorMessage: 'No internet connection.'));
    } on ServerException catch (e) {
      debugPrint('[DiscoveryBloc] ServerException on load: $e');
      emit(const DiscoveryState(errorMessage: 'Server error. Please retry.'));
    } catch (e, st) {
      debugPrint('[DiscoveryBloc] Unexpected error on load: $e\n$st');
      emit(const DiscoveryState(errorMessage: 'Something went wrong.'));
    }
  }

  Future<void> _onLoadMoreRequested(
      DiscoveryLoadMoreRequested event, Emitter<DiscoveryState> emit) async {
    if (state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final userId = await _getUserId();
      final more = await _getRandomImagesUseCase(
        take: _pageSize,
        userId: userId,
      );
      // ✅ Append events immediately.
      emit(state.copyWith(
        isLoadingMore: false,
        events: [...state.events, ...more],
      ));
      // Patch reactions in background.
      if (userId != null && more.isNotEmpty) {
        _enrichInBackground(more, userId);
      }
    } on NetworkException {
      emit(state.copyWith(isLoadingMore: false, errorMessage: 'No internet connection.'));
    } on ServerException catch (e) {
      debugPrint('[DiscoveryBloc] ServerException on loadMore: $e');
      emit(state.copyWith(isLoadingMore: false));
    } catch (e, st) {
      debugPrint('[DiscoveryBloc] Unexpected error on loadMore: $e\n$st');
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Fire-and-forget: fetch reactions for [events] then dispatch a patch event.
  void _enrichInBackground(List<EventDiscovery> events, String userId) {
    _enrichWithReactions(events, userId).then((enriched) {
      if (!isClosed) add(_DiscoveryReactionsPatchReceived(enriched));
    }).catchError((_) {
      // Reactions failed — events are already visible, so silently skip.
    });
  }

  /// Patch already-visible events with server-authoritative reaction counts.
  void _onReactionsPatchReceived(
      _DiscoveryReactionsPatchReceived event, Emitter<DiscoveryState> emit) {
    if (state.events.isEmpty) return;
    final byId = {for (final e in event.enriched) e.id: e};
    final patched = state.events.map((e) => byId[e.id] ?? e).toList();
    emit(state.copyWith(events: patched));
  }

  // ── Visibility lifecycle ──────────────────────────────────────────────────

  Future<void> _onEventVisible(
      DiscoveryEventVisible event, Emitter<DiscoveryState> emit) async {
    final id = event.eventId;

    // Cancel any pending disconnect timer — user is back on this card.
    _disconnectTimers[id]?.cancel();
    _disconnectTimers.remove(id);

    // Already connected or connection in progress — nothing to do.
    if ((_activeSessions[id]?.isConnected ?? false) || _connecting.contains(id)) {
      return;
    }

    _connecting.add(id);
    try {
      final room = await _getEventRoom(id);
      // Bloc might have been closed while we were awaiting.
      if (isClosed) return;

      final ws = ChatWebSocketService(_authService);
      await ws.connect(room.id);
      if (isClosed) {
        ws.disconnect();
        return;
      }

      _activeSessions[id] = ws;

      // Subscribe and forward updates into the BLoC event stream.
      final sub = ws.likeUpdates.listen((update) {
        if (!isClosed) add(_DiscoveryLikeUpdateReceived(update));
      });
      _likeSubscriptions[id]?.cancel();
      _likeSubscriptions[id] = sub;
    } catch (_) {
      // Network/auth failure — silently skip; no WS for this card.
    } finally {
      _connecting.remove(id);
    }
  }

  void _onEventHidden(
      DiscoveryEventHidden event, Emitter<DiscoveryState> emit) {
    final id = event.eventId;

    // Cancel any existing timer and start a fresh one.
    _disconnectTimers[id]?.cancel();
    _disconnectTimers[id] = Timer(_disconnectDelay, () {
      _tearDownSession(id);
    });
  }

  void _tearDownSession(String eventId) {
    _likeSubscriptions[eventId]?.cancel();
    _likeSubscriptions.remove(eventId);
    _activeSessions[eventId]?.disconnect();
    _activeSessions.remove(eventId);
    _disconnectTimers.remove(eventId);
  }

  // ── Real-time like_update from another device ─────────────────────────────

  void _onReactionUpdated(
      _DiscoveryLikeUpdateReceived event, Emitter<DiscoveryState> emit) {
    final update = event.update;
    final idx = state.events.indexWhere((e) => e.id == update.eventId);
    if (idx == -1) return;

    final current = state.events[idx];
    final isOwnAction = update.senderId == _currentUserId;

    // Always use the server-authoritative counts.
    // Only change userReaction if this update came from the current user.
    final reaction = isOwnAction
        ? (update.liked ? 'like' : update.disliked ? 'dislike' : null)
        : current.userReaction;

    final updated = List<EventDiscovery>.from(state.events);
    updated[idx] = current.copyWith(
      likes: update.likes,
      dislikes: update.dislikes,
      userReaction: reaction,
      clearReaction: reaction == null && isOwnAction,
    );
    emit(state.copyWith(events: updated));
  }

  // ── Reaction toggled by the current user ──────────────────────────────────

  Future<void> _onReactionToggled(
    DiscoveryReactionToggled event,
    Emitter<DiscoveryState> emit,
  ) async {
    final idx = state.events.indexWhere((e) => e.id == event.eventId);
    if (idx == -1) return;

    final current = state.events[idx];

    final String action;
    if (event.isLike) {
      action = current.userReaction == 'like' ? 'unlike' : 'like';
    } else {
      action = current.userReaction == 'dislike' ? 'undislike' : 'dislike';
    }

    // Optimistic update
    int newLikes = current.likes;
    int newDislikes = current.dislikes;
    String? newReaction;

    switch (action) {
      case 'like':
        newLikes++;
        if (current.userReaction == 'dislike') newDislikes--;
        newReaction = 'like';
      case 'unlike':
        newLikes = (newLikes - 1).clamp(0, 999999999);
        newReaction = null;
      case 'dislike':
        newDislikes++;
        if (current.userReaction == 'like') newLikes--;
        newReaction = 'dislike';
      case 'undislike':
        newDislikes = (newDislikes - 1).clamp(0, 999999999);
        newReaction = null;
    }

    final optimistic = List<EventDiscovery>.from(state.events);
    optimistic[idx] = current.copyWith(
      likes: newLikes,
      dislikes: newDislikes,
      userReaction: newReaction,
      clearReaction: newReaction == null,
    );
    emit(state.copyWith(events: optimistic));

    // Use the persistent session if available, otherwise open a temp one.
    final existingWs = _activeSessions[event.eventId];
    final bool useTemp = existingWs == null || !existingWs.isConnected;

    try {
      ChatWebSocketService ws;
      if (useTemp) {
        final room = await _getEventRoom(event.eventId);
        ws = ChatWebSocketService(_authService);
        await ws.connect(room.id);
      } else {
        ws = existingWs;
      }

      // Subscribe before sending to avoid missing the echo.
      final updateFuture = ws.likeUpdates
          .where((u) => u.eventId == event.eventId)
          .first
          .timeout(const Duration(seconds: 5));

      switch (action) {
        case 'like':
          ws.sendLike(event.eventId);
        case 'unlike':
          ws.sendUnlike(event.eventId);
        case 'dislike':
          ws.sendDislike(event.eventId);
        case 'undislike':
          ws.sendUndislike(event.eventId);
      }

      final update = await updateFuture;
      if (useTemp) ws.disconnect();

      // Confirm with server data (the persistent listener handles the same
      // update for other devices; this path handles the current user's echo).
      final confirmedIdx =
          state.events.indexWhere((e) => e.id == event.eventId);
      if (confirmedIdx != -1) {
        final confirmedReaction =
            update.liked ? 'like' : update.disliked ? 'dislike' : null;
        final confirmed = List<EventDiscovery>.from(state.events);
        confirmed[confirmedIdx] = confirmed[confirmedIdx].copyWith(
          likes: update.likes,
          dislikes: update.dislikes,
          userReaction: confirmedReaction,
          clearReaction: confirmedReaction == null,
        );
        emit(state.copyWith(events: confirmed));
      }
    } catch (_) {
      // Revert optimistic update on failure.
      final revertIdx =
          state.events.indexWhere((e) => e.id == event.eventId);
      if (revertIdx != -1) {
        final reverted = List<EventDiscovery>.from(state.events);
        reverted[revertIdx] = current;
        emit(state.copyWith(events: reverted));
      }
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  @override
  Future<void> close() {
    for (final id in _activeSessions.keys.toList()) {
      _tearDownSession(id);
    }
    for (final t in _disconnectTimers.values) {
      t.cancel();
    }
    _disconnectTimers.clear();
    return super.close();
  }
}
