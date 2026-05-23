import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_rest_data_source.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:skidoo_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/models/chat/like_update.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'discovery_event.dart';
part 'discovery_state.dart';

const _pageSize = 20;

/// How long to keep a WS connection alive after a card leaves the viewport.
const _disconnectDelay = Duration(seconds: 30);

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final GetRandomImagesUseCase _getRandomImagesUseCase;
  final GetEventReactionsBatchUseCase _getReactionsBatch;
  final GetEventRoomUseCase _getEventRoom;
  final AuthService _authService;
  final ClientSavedDataSource _savedDs;

  // ── Per-event WebSocket sessions ──────────────────────────────────────────
  final Map<String, ChatWebSocketService> _activeSessions = {};
  final Map<String, StreamSubscription<LikeUpdate>> _likeSubscriptions = {};
  final Map<String, StreamSubscription> _inviteSubscriptions = {};
  final Map<String, Timer> _disconnectTimers = {};
  // Guards against duplicate concurrent connect attempts for the same event.
  final Set<String> _connecting = {};

  // Running skip counter — tracks total events fetched so the server returns
  // the correct next page regardless of how many the user has hidden locally.
  int _skip = 0;

  late final ChatBackgroundService _bgService;
  String? _currentUserId;

  late final FeedCacheService _feedCache;

  DiscoveryBloc({
    required GetRandomImagesUseCase getRandomImagesUseCase,
    required GetEventReactionsBatchUseCase getReactionsBatch,
    required GetEventRoomUseCase getEventRoom,
    required FeedCacheService feedCache,
  })  : _getRandomImagesUseCase = getRandomImagesUseCase,
        _getReactionsBatch = getReactionsBatch,
        _getEventRoom = getEventRoom,
        _authService = sl<AuthService>(),
        _savedDs = sl<ClientSavedDataSource>(),
        super(const DiscoveryState()) {
    _feedCache = feedCache;
    _bgService = sl<ChatBackgroundService>();
    on<DiscoveryLoadRequested>(_onLoadRequested);
    on<DiscoveryLoadMoreRequested>(_onLoadMoreRequested);
    on<DiscoveryReactionToggled>(_onReactionToggled);
    on<DiscoveryEventVisible>(_onEventVisible);
    on<DiscoveryEventHidden>(_onEventHidden);
    on<DiscoveryEventHideRequested>(_onHideRequested);
    on<DiscoveryEventHideCommitted>(_onHideCommitted);
    on<DiscoveryEventHideUndone>(_onHideUndone);
    on<_DiscoveryLikeUpdateReceived>(_onReactionUpdated);
    on<_DiscoveryReactionsPatchReceived>(_onReactionsPatchReceived);
    on<_DiscoveryHiddenIdsLoaded>(_onHiddenIdsLoaded);
    on<DiscoveryEventSaveToggled>(_onSaveToggled);
    on<_DiscoverySavedItemsLoaded>(_onSavedItemsLoaded);

    // Load current user ID once so we can identify own updates later.
    _authService.getUserId().then((id) {
      if (id.isNotEmpty) _currentUserId = id;
    });

    // Restore previously-hidden event IDs from local storage.
    SharedPreferences.getInstance().then((prefs) {
      final ids = prefs.getStringList(_hiddenIdsKey) ?? [];
      if (ids.isNotEmpty && !isClosed) {
        add(_DiscoveryHiddenIdsLoaded(ids.toSet()));
      }
    });

    // Load saved event IDs from the server in the background.
    _loadSavedItemsInBackground();
  }

  static const _hiddenIdsKey = 'discovery_hidden_event_ids';

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
    final ids = events.map((e) => e.id).toList();
    final reactions = await _getReactionsBatch(ids, userId);
    return events.map((e) {
      final r = reactions[e.id] ?? EventReaction.empty();
      return e.copyWith(
        likes: r.likes,
        dislikes: r.dislikes,
        userReaction: r.userReaction,
        clearReaction: r.userReaction == null,
      );
    }).toList();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _onLoadRequested(
      DiscoveryLoadRequested event, Emitter<DiscoveryState> emit) async {
    _skip = 0;

    // ── Fast path: show cached events before the network returns ─────────────
    // restore() is synchronous (SharedPreferences is already in memory).
    final cached = _feedCache.restore();
    if (cached.isNotEmpty) {
      debugPrint('[DiscoveryBloc] cache hit — ${cached.length} events shown instantly');
      emit(DiscoveryState(events: cached, hasMore: true));
    } else {
      emit(const DiscoveryState(isLoading: true));
    }

    // ── Slow path: fetch fresh data and replace ───────────────────────────────
    try {
      final userId = await _getUserId();
      final followed = FollowRepository.followedIds.toList();
      final events = await _getRandomImagesUseCase(
        take: _pageSize,
        skip: 0,
        userId: userId,
        followedPhotographerIds: followed.isEmpty ? null : followed,
      );
      _skip = _pageSize;
      FollowRepository.seedFollowed(
        events.where((e) => e.isFollowed).map((e) => e.photographerId),
      );
      // Persist fresh events so the next launch is fast too.
      unawaited(_feedCache.save(events));
      emit(DiscoveryState(
        events: events,
        currentUserId: userId,
        hasMore: events.isNotEmpty,
      ));
      if (userId != null && events.isNotEmpty) {
        _enrichInBackground(events, userId);
      }
    } on NetworkException {
      // Keep cached events on screen when offline — only hard-fail if empty.
      if (cached.isEmpty) {
        emit(const DiscoveryState(errorMessage: 'No internet connection.'));
      }
    } on ServerException catch (e) {
      debugPrint('[DiscoveryBloc] ServerException on load: $e');
      if (cached.isEmpty) {
        emit(const DiscoveryState(errorMessage: 'Server error. Please retry.'));
      }
    } catch (e, st) {
      debugPrint('[DiscoveryBloc] Unexpected error on load: $e\n$st');
      if (cached.isEmpty) {
        emit(const DiscoveryState(errorMessage: 'Something went wrong.'));
      }
    }
  }

  Future<void> _onLoadMoreRequested(
      DiscoveryLoadMoreRequested event, Emitter<DiscoveryState> emit) async {
    if (state.isLoadingMore) {
      debugPrint('[ForYouFeed] load-more skipped — already loading');
      return;
    }
    if (!state.hasMore) {
      debugPrint('[ForYouFeed] load-more skipped — no more events');
      return;
    }
    debugPrint(
      '[ForYouFeed] load-more START — currentCount=${state.events.length} skip=$_skip',
    );
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final userId = await _getUserId();
      final followed = FollowRepository.followedIds.toList();
      final more = await _getRandomImagesUseCase(
        take: _pageSize,
        skip: _skip,
        userId: userId,
        followedPhotographerIds: followed.isEmpty ? null : followed,
      );
      _skip += _pageSize;
      FollowRepository.seedFollowed(
        more.where((e) => e.isFollowed).map((e) => e.photographerId),
      );
      debugPrint(
        '[ForYouFeed] load-more DONE — fetched=${more.length} '
        'totalNow=${state.events.length + more.length} hasMore=${more.isNotEmpty}',
      );
      emit(state.copyWith(
        isLoadingMore: false,
        events: [...state.events, ...more],
        hasMore: more.isNotEmpty,
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
    }).catchError((Object e) {
      debugPrint('[DiscoveryBloc] _enrichInBackground error: $e');
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
      await ws.connectToRoom(room.id);
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

      // Forward group invites to the persistent relay so ChatRoomsBloc sees
      // them regardless of which WS instance the server delivers them through.
      _inviteSubscriptions[id]?.cancel();
      _inviteSubscriptions[id] = ws.groupInviteEvents.listen((event) {
        _bgService.reportGroupInvite(event.room);
      });
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
    _inviteSubscriptions[eventId]?.cancel();
    _inviteSubscriptions.remove(eventId);
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
        await ws.connectToRoom(room.id);
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

  // ── Hide event ────────────────────────────────────────────────────────────

  /// Step 1 — user taps hide. Collapses the card; undo is still available.
  void _onHideRequested(
    DiscoveryEventHideRequested event,
    Emitter<DiscoveryState> emit,
  ) {
    // If a different event was already pending, commit it before starting a new one.
    if (state.pendingHideEventId != null &&
        state.pendingHideEventId != event.eventId) {
      final prevId = state.pendingHideEventId!;
      final committed = {...state.hiddenEventIds, prevId};
      final filtered =
          state.events.where((e) => !committed.contains(e.id)).toList();
      emit(state.copyWith(
        hiddenEventIds: committed,
        events: filtered,
        clearPendingHide: true,
      ));
      SharedPreferences.getInstance().then(
        (p) => p.setStringList(_hiddenIdsKey, committed.toList()),
      );
    }
    emit(state.copyWith(pendingHideEventId: event.eventId));
  }

  /// Step 2a — undo window expired or user scrolled away. Remove + persist.
  Future<void> _onHideCommitted(
    DiscoveryEventHideCommitted event,
    Emitter<DiscoveryState> emit,
  ) async {
    // Guard: only commit if this event is still the pending one.
    if (state.pendingHideEventId != event.eventId) return;
    final updated = {...state.hiddenEventIds, event.eventId};
    final filtered =
        state.events.where((e) => !updated.contains(e.id)).toList();
    emit(state.copyWith(
      hiddenEventIds: updated,
      events: filtered,
      clearPendingHide: true,
    ));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hiddenIdsKey, updated.toList());
  }

  /// Step 2b — user tapped Undo. Restore the card.
  void _onHideUndone(
    DiscoveryEventHideUndone event,
    Emitter<DiscoveryState> emit,
  ) {
    emit(state.copyWith(clearPendingHide: true));
  }

  void _onHiddenIdsLoaded(
    _DiscoveryHiddenIdsLoaded event,
    Emitter<DiscoveryState> emit,
  ) {
    final filtered = state.events.where((e) => !event.ids.contains(e.id)).toList();
    emit(state.copyWith(hiddenEventIds: event.ids, events: filtered));
  }

  // ── Save / unsave ─────────────────────────────────────────────────────────

  void _loadSavedItemsInBackground() {
    _savedDs.listSaved(assetType: 'event').then((items) {
      if (isClosed) return;
      final recordIds = <String, String>{
        for (final i in items) i.assetId: i.savedItemId,
      };
      add(_DiscoverySavedItemsLoaded(recordIds));
    }).catchError((_) {
      // Silently ignore — saved indicators simply won't be pre-populated.
    });
  }

  void _onSavedItemsLoaded(
      _DiscoverySavedItemsLoaded event, Emitter<DiscoveryState> emit) {
    emit(state.copyWith(
      savedEventIds: event.recordIds.keys.toSet(),
      savedItemRecordIds: event.recordIds,
    ));
  }

  Future<void> _onSaveToggled(
      DiscoveryEventSaveToggled event, Emitter<DiscoveryState> emit) async {
    final isSaved = state.savedEventIds.contains(event.eventId);

    // Optimistic update
    final newSavedIds = Set<String>.from(state.savedEventIds);
    final newRecordIds = Map<String, String>.from(state.savedItemRecordIds);
    if (isSaved) {
      newSavedIds.remove(event.eventId);
      newRecordIds.remove(event.eventId);
    } else {
      newSavedIds.add(event.eventId);
    }
    emit(state.copyWith(
        savedEventIds: newSavedIds, savedItemRecordIds: newRecordIds));

    try {
      if (isSaved) {
        final recordId = state.savedItemRecordIds[event.eventId];
        if (recordId != null && recordId.isNotEmpty) {
          await _savedDs.unsaveById(recordId);
        } else {
          await _savedDs.unsaveByAsset(
              assetType: 'event', assetId: event.eventId);
        }
      } else {
        final saved = await _savedDs.saveItem(
            assetType: 'event', assetId: event.eventId);
        // Update record ID so unsave can use it later.
        final updated = Map<String, String>.from(state.savedItemRecordIds);
        updated[event.eventId] = saved.savedItemId;
        emit(state.copyWith(savedItemRecordIds: updated));
      }
    } catch (e) {
      debugPrint('[Discovery] Save toggle failed: $e');
      // Revert optimistic update on failure.
      final reverted = Set<String>.from(state.savedEventIds);
      final revertedIds = Map<String, String>.from(state.savedItemRecordIds);
      if (isSaved) {
        reverted.add(event.eventId);
      } else {
        reverted.remove(event.eventId);
        revertedIds.remove(event.eventId);
      }
      emit(state.copyWith(
          savedEventIds: reverted, savedItemRecordIds: revertedIds));
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
