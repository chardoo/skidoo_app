import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/cache/hidden_events.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart'
    show WsRoomHolder;
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show EventReaction;
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/models/chat/like_update.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';

part 'discovery_event.dart';
part 'discovery_state.dart';

const _pageSize = 20;

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final GetRandomImagesUseCase _getRandomImagesUseCase;
  final GetEventReactionsBatchUseCase _getReactionsBatch;
  final GetEventRoomsBatchUseCase _getEventRoomsBatch;
  final AuthService _authService;
  final ClientSavedDataSource _savedDs;

  // Room cache populated by the batch prefetch — keyed by event ID.
  final Map<String, ChatRoom> _roomCache = {};

  // ── Debounced fallback room-fetch queue ───────────────────────────────────
  // When individual cards need a room that wasn't prefetched, we collect their
  // IDs for 80 ms then fire ONE batched request instead of N parallel singles.
  final Set<String> _roomFetchQueue = {};
  final Map<String, List<Completer<void>>> _roomFetchCompleters = {};
  Timer? _roomFetchTimer;

  // Tracks rooms already subscribed on the shared WS this session.
  // When the WS reconnects, this set is cleared so rooms re-subscribe.
  final Set<String> _subscribedRoomIds = {};

  // Listens to like_update frames from the shared WS.
  StreamSubscription<LikeUpdate>? _likeUpdateSub;
  StreamSubscription<bool>? _wsConnectionSub;

  // Tracks all in-flight prefetch work so cache-miss paths can await it
  // instead of immediately firing a redundant single-ID batch call.
  Future<void>? _prefetchFuture;

  // Running skip counter — tracks total events fetched so the server returns
  // the correct next page regardless of how many the user has hidden locally.
  int _skip = 0;

  late final ChatBackgroundService _bgService;
  String? _currentUserId;

  late final FeedCacheService _feedCache;

  DiscoveryBloc({
    required GetRandomImagesUseCase getRandomImagesUseCase,
    required GetEventReactionsBatchUseCase getReactionsBatch,
    required GetEventRoomsBatchUseCase getEventRoomsBatch,
    required FeedCacheService feedCache,
  })  : _getRandomImagesUseCase = getRandomImagesUseCase,
        _getReactionsBatch = getReactionsBatch,
        _getEventRoomsBatch = getEventRoomsBatch,
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

    _setupLikeListener();
    _wsConnectionSub = _bgService.connectionEvents.listen((connected) {
      if (connected && !isClosed) {
        _subscribedRoomIds.clear(); // server resets subscriptions on reconnect
        _setupLikeListener();
      }
    });
    on<DiscoveryEventHideCommitted>(_onHideCommitted);
    on<DiscoveryEventHideUndone>(_onHideUndone);
    on<_DiscoveryLikeUpdateReceived>(_onReactionUpdated);
    on<_DiscoveryReactionsPatchReceived>(_onReactionsPatchReceived);
    on<_DiscoveryHiddenIdsLoaded>(_onHiddenIdsLoaded);
    on<DiscoveryEventSaveToggled>(_onSaveToggled);
    on<DiscoveryCommentAdded>(_onCommentAdded);
    on<_DiscoverySavedItemsLoaded>(_onSavedItemsLoaded);

    // Load current user ID once so we can identify own updates later.
    _authService.getUserId().then((id) {
      if (id.isNotEmpty) _currentUserId = id;
    });

    // Restore previously-hidden event IDs. Through [HiddenEvents] rather than
    // straight from SharedPreferences, so this bloc and the Following feed
    // read and write one set instead of two that drift — hiding here has to
    // mean hidden there. Same storage key as before, so existing hides stand.
    HiddenEvents.load().then((ids) {
      if (ids.isNotEmpty && !isClosed) {
        add(_DiscoveryHiddenIdsLoaded(ids));
      }
    });

    // Load saved event IDs from the server in the background.
    _loadSavedItemsInBackground();
  }

  void _setupLikeListener() {
    _likeUpdateSub?.cancel();
    _likeUpdateSub = _bgService.sharedWs.likeUpdates.listen((update) {
      if (!isClosed) add(_DiscoveryLikeUpdateReceived(update));
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

  /// Queues [eventId] for a debounced batch room fetch and returns a Future
  /// that resolves once the batch completes. Multiple calls within 80 ms are
  /// coalesced into one request instead of firing one request per ID.
  Future<void> _enqueueRoomFetch(String eventId) {
    _roomFetchQueue.add(eventId);
    _roomFetchTimer?.cancel();
    _roomFetchTimer = Timer(
      const Duration(milliseconds: 80),
      _flushRoomFetchQueue,
    );
    final completer = Completer<void>();
    (_roomFetchCompleters[eventId] ??= []).add(completer);
    return completer.future;
  }

  Future<void> _flushRoomFetchQueue() async {
    if (_roomFetchQueue.isEmpty) return;
    final ids = _roomFetchQueue.toList();
    _roomFetchQueue.clear();
    final completers = Map.of(_roomFetchCompleters);
    _roomFetchCompleters.clear();

    for (var i = 0; i < ids.length; i += 20) {
      final chunk = ids.sublist(i, (i + 20).clamp(0, ids.length));
      try {
        final map = await _getEventRoomsBatch(chunk);
        _roomCache.addAll(map);
      } catch (e) {
        debugPrint('[DiscoveryBloc] fallback batch error: $e');
      }
      for (final id in chunk) {
        for (final c in completers[id] ?? <Completer<void>>[]) {
          if (!c.isCompleted) c.complete();
        }
      }
    }
  }

  /// The server's counts for [events], one entry per event asked about.
  ///
  /// An event the batch said nothing about gets [EventReaction.empty] rather
  /// than being left out: silence means no reactions, and a card restored from
  /// cache can be carrying a count that is no longer true.
  Future<Map<String, EventReaction>> _enrichWithReactions(
    List<EventDiscovery> events,
    String userId,
  ) async {
    final ids = events.map((e) => e.id).toList();
    // Server allows max 50 IDs per reactions batch call — chunk sequentially.
    final Map<String, EventReaction> reactions = {};
    for (var i = 0; i < ids.length; i += 50) {
      final chunk = ids.sublist(i, (i + 50).clamp(0, ids.length));
      try {
        final partial = await _getReactionsBatch(chunk, userId);
        reactions.addAll(partial);
      } catch (e) {
        debugPrint('[DiscoveryBloc] reactions batch error: $e');
      }
    }
    return {for (final id in ids) id: reactions[id] ?? EventReaction.empty()};
  }

  /// Batch-fetches rooms for [events] and stores them in [_roomCache].
  /// Chunks are sent sequentially (not all in parallel) so we don't flood
  /// the server with simultaneous requests on large feed pages.
  void _prefetchRooms(List<EventDiscovery> events) {
    if (events.isEmpty) return;
    if (_currentUserId == null) return; // unauthenticated — skip
    final ids = events.map((e) => e.id).toList();

    // Build a sequential chain: each chunk waits for the previous to finish.
    Future<void> chain = Future<void>.value();
    for (var i = 0; i < ids.length; i += 20) {
      final chunk = ids.sublist(i, (i + 20).clamp(0, ids.length));
      chain = chain.then((_) async {
        try {
          final map = await _getEventRoomsBatch(chunk);
          _roomCache.addAll(map);
          debugPrint(
            '[DiscoveryBloc] prefetched ${map.length} rooms '
            '(cache=${_roomCache.length})',
          );
        } catch (e) {
          debugPrint('[DiscoveryBloc] room prefetch error: $e');
        }
      });
    }
    // Chain onto any prior prefetch so _prefetchFuture always represents
    // all outstanding room-fetch work (initial load + load-more pages).
    _prefetchFuture =
        (_prefetchFuture ?? Future<void>.value()).then((_) => chain);
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _onLoadRequested(
      DiscoveryLoadRequested event, Emitter<DiscoveryState> emit) async {
    _skip = 0;

    // A reload starts a fresh DiscoveryState rather than a copyWith, so every
    // emit below has to carry the hidden set forward by hand. Leaving it out
    // reset it to empty and un-hid everything the user had hidden — the reason
    // hidden posts kept coming back after a refresh or a restart.
    //
    // Read at each emit rather than captured once: the set is restored from
    // SharedPreferences asynchronously at construction, so on a cold start it
    // can land in the middle of the fetch below. A value captured up here
    // would still be the empty one and would overwrite it.
    //
    // ── Settle what is hidden before anything is drawn ───────────────────────
    //
    // The hidden set is restored asynchronously at construction, and the cache
    // below paints synchronously — so on a cold start the feed showed posts
    // the reader had hidden and took them away again a moment later. If the
    // first cached post was one of them, the card they opened the app to slid
    // away on its own, which is the same complaint [keepFirst] exists to
    // answer, arriving by a different route.
    //
    // Awaited rather than raced: this reads SharedPreferences, which the app
    // has already loaded by the time a feed is asked for, so it costs a
    // microtask and not a frame. Anything that decides *what* the first card
    // is has to be settled before that card is on screen.
    final hidden = await HiddenEvents.load();
    if (hidden.isNotEmpty && hidden != state.hiddenEventIds) {
      emit(state.copyWith(hiddenEventIds: hidden));
    }

    // ── Fast path: show cached events before the network returns ─────────────
    // restore() is synchronous (SharedPreferences is already in memory).
    final cached = _feedCache.restore();
    // Asked before the emit below and only once — the flag is consumed by
    // whoever reads it first, and on a user-initiated reload it is spent
    // rather than honoured: a pull to refresh is a request for a new deal, and
    // adopting a page fetched at launch would answer it with the feed they
    // already had. See [FeedCacheService.takeHandoff].
    final handedOver = _feedCache.takeHandoff() && !event.userInitiated;

    if (cached.isNotEmpty) {
      debugPrint(
          '[DiscoveryBloc] cache hit — ${cached.length} events shown instantly');
      emit(DiscoveryState(
        events: withoutHidden(cached, state.hiddenEventIds),
        hasMore: true,
        hiddenEventIds: state.hiddenEventIds,
      ));
    } else {
      emit(DiscoveryState(
          isLoading: true, hiddenEventIds: state.hiddenEventIds));
    }

    // ── The splash already fetched this page ─────────────────────────────────
    //
    // Adopt it rather than asking for the first page again. The second request
    // is not a cheaper version of the first: `skip == 0` rebuilds the ranking
    // server-side, so it comes back dealt differently on purpose, and the card
    // it displaces is the one the splash spent the brand animation decoding.
    //
    // `_skip` is set from what was actually stored, not from what the splash
    // asked for — the cache keeps the first `_maxEvents` and the rest were
    // never written, so paging has to resume where the stored page ends or
    // load-more opens a gap.
    if (handedOver && cached.isNotEmpty) {
      debugPrint(
          '[DiscoveryBloc] adopting the splash page — no second first-page fetch');
      _skip = cached.length;
      final userId = await _getUserId();
      // Everything the fetch below would have done with its answer, done with
      // this one instead. Seeding the follow set matters as much here as
      // there: it is what the follow badges on these very cards read from,
      // and skipping it drew every card as not-followed.
      FollowRepository.seedFollowed(
        cached.where((e) => e.isFollowed).map((e) => e.photographerId),
      );
      emit(state.copyWith(currentUserId: userId, hasMore: true));
      if (userId != null) _enrichInBackground(cached, userId);
      _prefetchRooms(cached);
      return;
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
      // Persist fresh events so the next launch is fast too. Saved as the
      // server ranked them, not as they are about to be shown — the pin below
      // is about this moment on screen, and baking it into the cache would pin
      // the same post at the top for ever.
      unawaited(_feedCache.save(events));
      emit(DiscoveryState(
        events: withoutHidden(
          keepFirst(
            events,
            // Only what is already on screen is protected, and only when the
            // reader did not ask for a new deal. The post itself, not its id:
            // the photo showing on it is part of what must not move.
            onScreen: event.userInitiated || state.events.isEmpty
                ? null
                : state.events.first,
          ),
          state.hiddenEventIds,
        ),
        currentUserId: userId,
        // Measured on what the server actually returned: a page that happens
        // to be entirely hidden still means there is more behind it.
        hasMore: events.isNotEmpty,
        hiddenEventIds: state.hiddenEventIds,
      ));
      if (userId != null && events.isNotEmpty) {
        _enrichInBackground(events, userId);
      }
      _prefetchRooms(events);
    } on NetworkException {
      // Keep cached events on screen when offline — only hard-fail if empty.
      if (cached.isEmpty) {
        emit(DiscoveryState(
            errorMessage: 'No internet connection.',
            hiddenEventIds: state.hiddenEventIds));
      }
    } on ServerException catch (e) {
      debugPrint('[DiscoveryBloc] ServerException on load: $e');
      if (cached.isEmpty) {
        emit(DiscoveryState(
            errorMessage: 'Server error. Please retry.',
            hiddenEventIds: state.hiddenEventIds));
      }
    } catch (e, st) {
      debugPrint('[DiscoveryBloc] Unexpected error on load: $e\n$st');
      if (cached.isEmpty) {
        emit(DiscoveryState(
            errorMessage: 'Something went wrong.',
            hiddenEventIds: state.hiddenEventIds));
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
        // Filtered on the way in: a hidden event the server happens to return
        // on a later page would otherwise walk straight back into the feed,
        // and an event already in the list would arrive as a second page
        // carrying the same key — which a PageView does not survive.
        //
        // The second case is [keepFirst]'s doing and is the ordinary path, not
        // a defensive one: a post kept on top *because* the ranking demoted it
        // off page one is, by construction, waiting on some later page.
        events: [
          ...state.events,
          ...withoutSeen(withoutHidden(more, state.hiddenEventIds),
              state.events),
        ],
        hasMore: more.isNotEmpty,
      ));
      // Patch reactions in background.
      if (userId != null && more.isNotEmpty) {
        _enrichInBackground(more, userId);
      }
      _prefetchRooms(more);
    } on NetworkException {
      emit(state.copyWith(
          isLoadingMore: false, errorMessage: 'No internet connection.'));
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
    _enrichWithReactions(events, userId).then((reactions) {
      if (!isClosed) add(_DiscoveryReactionsPatchReceived(reactions));
    }).catchError((Object e) {
      debugPrint('[DiscoveryBloc] _enrichInBackground error: $e');
    });
  }

  /// Patch already-visible events with server-authoritative reaction counts.
  ///
  /// The counts land on the events as they stand, rather than those events
  /// being replaced by the copies the fetch came back holding — see
  /// [_DiscoveryReactionsPatchReceived]. The list on screen has already been
  /// through [keepFirst] and [withoutHidden], and those decisions have to
  /// survive a patch about likes.
  void _onReactionsPatchReceived(
      _DiscoveryReactionsPatchReceived event, Emitter<DiscoveryState> emit) {
    if (state.events.isEmpty) return;
    final patched = state.events.map((e) {
      final r = event.reactions[e.id];
      if (r == null) return e;
      return e.copyWith(
        likes: r.likes,
        dislikes: r.dislikes,
        userReaction: r.userReaction,
        clearReaction: r.userReaction == null,
      );
    }).toList();
    emit(state.copyWith(events: patched));
  }

  // ── Visibility lifecycle ──────────────────────────────────────────────────

  Future<void> _onEventVisible(
      DiscoveryEventVisible event, Emitter<DiscoveryState> emit) async {
    if (_currentUserId == null) return; // unauthenticated — skip
    final id = event.eventId;

    // Already subscribed on the shared WS — nothing to do.
    if (_subscribedRoomIds.contains(id)) return;

    try {
      // Prefer the batch-prefetched cache. If the prefetch is still in-flight
      // (card became visible before the HTTP response landed), wait for it so
      // we avoid firing a redundant single-ID batch call.
      ChatRoom? room = _roomCache[id];
      if (room == null) {
        await _prefetchFuture;
        room = _roomCache[id];
      }
      if (room == null) {
        // Use the debounced queue — coalesces concurrent single-card fetches
        // into one batched request instead of N parallel single-ID requests.
        await _enqueueRoomFetch(id);
        room = _roomCache[id];
      }
      if (room == null || isClosed) return;

      // Subscribe on the single shared connection — no new WS opened.
      _bgService.sharedWs.subscribeRoom(room.id, holder: WsRoomHolder.feed);
      _subscribedRoomIds.add(id);
    } on ServerException catch (e) {
      // 504 / upstream timeout — server is slow, not a client bug. Skip silently.
      debugPrint(
          '[DiscoveryBloc] _onEventVisible: chat API error for $id — ${e.message}');
    } catch (e) {
      debugPrint(
          '[DiscoveryBloc] _onEventVisible: unexpected error for $id — $e');
    }
  }

  void _onEventHidden(
      DiscoveryEventHidden event, Emitter<DiscoveryState> emit) {
    // Scrolled off screen: stop the room's events. There is no connection to
    // tear down — the WS is shared and stays open — but the subscription on it
    // is per room, and a card the user has scrolled past is not one they are
    // reading. Left alone, a session's worth of scrolling ends up holding a
    // channel for every event that ever crossed the viewport, which is the
    // accumulation the server side of this stopped doing on connect.
    //
    // Cheap to undo: scrolling back re-subscribes from [_onEventVisible], and
    // the counts on a card are rendered from the feed response, not from
    // whatever arrived over the socket while it was out of sight.
    final id = event.eventId;
    if (!_subscribedRoomIds.remove(id)) return;
    final room = _roomCache[id];
    if (room != null)
      _bgService.sharedWs.unsubscribeRoom(room.id, holder: WsRoomHolder.feed);
  }

  // ── Real-time like_update from another device ─────────────────────────────

  void _onReactionUpdated(
      _DiscoveryLikeUpdateReceived event, Emitter<DiscoveryState> emit) {
    final update = event.update;
    final isOwnAction = update.senderId == _currentUserId;

    // An echo about a post this bloc does not carry is still worth keeping: it
    // is the server confirming what somebody just did in Following, or someone
    // else liking a post they are looking at there.
    final current = state.reactionFor(update.eventId);
    if (current == null && !isOwnAction) return;

    // Always use the server-authoritative counts.
    // Only change userReaction if this update came from the current user.
    final reaction = isOwnAction
        ? (update.liked
            ? 'like'
            : update.disliked
                ? 'dislike'
                : null)
        : current?.userReaction;

    emit(state.withReaction(
      update.eventId,
      EventReactionState(
        likes: update.likes,
        dislikes: update.dislikes,
        userReaction: reaction,
      ),
    ));
  }

  // ── Comment added by the current user ─────────────────────────────────────

  void _onCommentAdded(
      DiscoveryCommentAdded event, Emitter<DiscoveryState> emit) {
    final idx = state.events.indexWhere((e) => e.id == event.eventId);
    if (idx == -1) return;
    final current = state.events[idx];
    final updated = List<EventDiscovery>.from(state.events);
    updated[idx] = current.copyWith(commentCount: current.commentCount + 1);
    emit(state.copyWith(events: updated));
  }

  // ── Reaction toggled by the current user ──────────────────────────────────

  /// Record a reaction through REST, for when the socket is not an option.
  ///
  /// Puts the optimistic state back only if this fails too — at that point
  /// nothing anywhere has the like and leaving the heart filled would be a
  /// lie. Anything the server does record is confirmed by the usual echo.
  Future<void> _sendReactionOverRest(
    String eventId,
    String action,
    EventReactionState previous,
    Emitter<DiscoveryState> emit,
  ) async {
    // "unlike" and "undislike" clear it, which the endpoint spells as no
    // reaction at all rather than as a verb of its own.
    final reaction = switch (action) {
      'like' => 'like',
      'dislike' => 'dislike',
      _ => null,
    };
    try {
      await sl<SetEventReactionUseCase>()(eventId, reaction);
    } catch (e) {
      debugPrint('[DiscoveryBloc] reaction REST failed for $eventId: $e');
      if (!isClosed) emit(state.withReaction(eventId, previous));
    }
  }

  Future<void> _onReactionToggled(
    DiscoveryReactionToggled event,
    Emitter<DiscoveryState> emit,
  ) async {
    // Not "is it in the Feed tab's list" any more. A post in Following is just
    // as real, and this used to give up on one — see [EventReactionState].
    final toggle = state.toggleReaction(
      event.eventId,
      isLike: event.isLike,
      snapshot: event.snapshot,
    );
    if (toggle == null) return;

    final current = toggle.previous;
    final action = toggle.action;

    emit(toggle.state);

    // The profile's Liked tab holds its grid rather than refetching on every
    // visit, so this is what tells it an event joined or left the list.
    AppCacheSignals.likes.bump();

    // No socket, no room lookup: go straight to REST.
    //
    // The note that used to sit here said web keeps the optimistic update only
    // — which is to say the like was never recorded anywhere. That is also
    // what happened on mobile whenever the connection was down, because
    // everything below assumes a live socket and the only other outcome was to
    // undo the like. Asking whether the socket can carry it is cheaper than
    // resolving a room to discover it cannot.
    if (!_bgService.sharedWs.isConnected) {
      await _sendReactionOverRest(event.eventId, action, current, emit);
      return;
    }

    // Resolve the room (needed for room_id in the WS payload).
    ChatRoom? room = _roomCache[event.eventId];
    if (room == null) {
      await _prefetchFuture;
      room = _roomCache[event.eventId];
    }
    if (room == null) {
      await _enqueueRoomFetch(event.eventId);
      room = _roomCache[event.eventId];
    }
    if (room == null) {
      // No room to route through — so take the other road rather than undoing
      // what the reader just did.
      //
      // Reactions travel over the chat socket keyed to a room. That is fine
      // for a post this bloc fetched, because it prefetches their rooms; it is
      // not fine for anything else. **A post in Following is never in that
      // cache** — that feed fetches its own list — so liking there resolved no
      // room and the like was silently thrown away. Same for a post whose room
      // does not exist yet, and for web, where socket reactions are not
      // supported at all.
      //
      // `POST /chat/events/{id}/reaction` exists for exactly this and needs no
      // room; its own docstring says so. The app could only ever *read* over
      // REST until now.
      await _sendReactionOverRest(event.eventId, action, current, emit);
      return;
    }

    // Send on the single shared connection. The global _likeUpdateSub
    // receives the server echo and calls _onReactionUpdated to confirm.
    final ws = _bgService.sharedWs;
    switch (action) {
      case 'like':
        ws.sendLike(event.eventId, roomId: room.id);
      case 'unlike':
        ws.sendUnlike(event.eventId, roomId: room.id);
      case 'dislike':
        ws.sendDislike(event.eventId, roomId: room.id);
      case 'undislike':
        ws.sendUndislike(event.eventId, roomId: room.id);
    }
  }

  // ── Hide event ────────────────────────────────────────────────────────────

  /// The event a still-undoable hide took off the list, with the position it
  /// held, so Undo can put it back exactly where it was rather than at the top.
  (int, EventDiscovery)? _undoHide;

  /// Step 1 — user taps hide. The card goes **now**.
  ///
  /// It used to only set [DiscoveryState.pendingHideEventId] and leave the list
  /// alone, on the assumption that something downstream would collapse the
  /// card. Nothing does — the Explore page's `buildWhen` doesn't even rebuild
  /// on that field — so the post sat there untouched until the undo window
  /// closed several seconds later, and hiding looked like a button that did
  /// nothing. The field is still the marker that says a hide is undoable.
  void _onHideRequested(
    DiscoveryEventHideRequested event,
    Emitter<DiscoveryState> emit,
  ) {
    // Starting a new hide settles whichever one was still undoable.
    var hidden = state.hiddenEventIds;
    final previous = state.pendingHideEventId;
    if (previous != null && previous != event.eventId) {
      hidden = {...hidden, previous};
      _persistHidden(hidden);
    }

    final events = [...state.events];
    final index = events.indexWhere((e) => e.id == event.eventId);
    _undoHide = index < 0 ? null : (index, events.removeAt(index));

    emit(state.copyWith(
      events: events,
      hiddenEventIds: hidden,
      pendingHideEventId: event.eventId,
    ));
  }

  /// Step 2a — the undo window closed. The card is already gone from the list;
  /// this is what makes it stay gone, here and on every later fetch.
  Future<void> _onHideCommitted(
    DiscoveryEventHideCommitted event,
    Emitter<DiscoveryState> emit,
  ) async {
    // Guard: only commit if this event is still the pending one.
    if (state.pendingHideEventId != event.eventId) return;
    _undoHide = null;
    final updated = {...state.hiddenEventIds, event.eventId};
    emit(state.copyWith(
      hiddenEventIds: updated,
      events: withoutHidden(state.events, updated),
      clearPendingHide: true,
    ));
    await HiddenEvents.replace(updated);
  }

  /// Step 2b — user tapped Undo. Put the card back where it was.
  void _onHideUndone(
    DiscoveryEventHideUndone event,
    Emitter<DiscoveryState> emit,
  ) {
    final restore = _undoHide;
    _undoHide = null;
    if (restore == null) {
      emit(state.copyWith(clearPendingHide: true));
      return;
    }
    final (index, hiddenEvent) = restore;
    // A load-more may have landed during the undo window, so the old index is
    // a hint, not a guarantee.
    final events = [...state.events]
      ..insert(index.clamp(0, state.events.length), hiddenEvent);
    emit(state.copyWith(events: events, clearPendingHide: true));
  }

  void _onHiddenIdsLoaded(
    _DiscoveryHiddenIdsLoaded event,
    Emitter<DiscoveryState> emit,
  ) {
    emit(state.copyWith(
      hiddenEventIds: event.ids,
      events: withoutHidden(state.events, event.ids),
    ));
  }

  /// The fresh list, with the post the reader is currently looking at left
  /// where it is.
  ///
  /// The feed paints from cache the instant the app opens and replaces that
  /// with the server's answer a second or two later. Those two lists used to
  /// agree, because the ranking was deterministic — so the replacement was
  /// invisible. It is not deterministic any more: the top of the feed rotates
  /// on purpose, and the impression log demotes whatever led last time. The
  /// card restored from cache *is* whatever led last time, so it is precisely
  /// the one the server will move — and the reader watches the post they just
  /// opened the app to slide away.
  ///
  /// So on a cold start the first card stays first and the rest of the fresh
  /// order follows it. The rotation still happens; it just is not applied to
  /// the thing under the reader's thumb. A pull to refresh is an explicit
  /// request for a new deal and is left alone.
  ///
  /// A post absent from the fresh page is pinned anyway, and that is the part
  /// that took two goes to get right. Pinning used to give up whenever
  /// `indexWhere` came back -1, on the reasoning that a post not in the fresh
  /// list is gone and inventing a row for it would put a dead card on top.
  /// That reasoning had the common case backwards: the demotion this function
  /// exists to defend against is the very thing that pushes a post off the
  /// page. The recommender's impression damping (`SHOWN_MAX_PENALTY`, 0.6 in
  /// `recommender/app/pipeline/scorer.py`) is aimed squarely at whatever led
  /// the previous rebuild — which is precisely the card restored from cache —
  /// so the pin stood down at the one moment it was written for.
  ///
  /// A short page was tried as the tell for "really gone" and is not one: with
  /// a catalogue smaller than a page every absence looks final, which is the
  /// case the reader hits most. So absence is now read as demotion, full stop.
  /// The genuinely-gone case is not left unhandled — it is handled where it
  /// can be known rather than guessed, by [FeedCacheService.removeEvent] when
  /// opening the album 404s — and it costs at most the one card already on
  /// screen, for one session, since the next launch's cache is written from
  /// the server's order and no longer contains it.
  ///
  /// [onScreen] is the post *as it is on screen*, not just its id, because
  /// holding its slot turned out to be only half the job — see
  /// [keepMediaOrder].
  // Not @visibleForTesting: the Following feed applies the same rule through
  // the same helper, which is the point of it being one.
  static List<EventDiscovery> keepFirst(
    List<EventDiscovery> fresh, {
    required EventDiscovery? onScreen,
  }) {
    if (onScreen == null || fresh.isEmpty) return fresh;
    final at = fresh.indexWhere((e) => e.id == onScreen.id);
    if (at < 0) {
      // Demoted off the page rather than out of the feed: keep the card the
      // reader is on, with the fresh order behind it. It is the copy already
      // on screen, so nothing about it changes as it is kept — the reactions
      // patch still lands on it, and [_onLoadMoreRequested] drops the
      // duplicate if a later page turns it up again.
      return [onScreen, ...fresh];
    }

    final pinned = keepMediaOrder(fresh[at], onScreen);
    // Already first *and* dealing its photos the same way — nothing to rebuild.
    if (identical(pinned, fresh.first)) return fresh;
    return [pinned, ...fresh.where((e) => e.id != onScreen.id)];
  }

  /// [fresh], still showing the photo the reader is actually looking at.
  ///
  /// Holding the post's slot is only half of "nothing moves under the reader".
  /// The photos *inside* a card are dealt by the server too, seeded off the
  /// feed snapshot — and the first page of a feed rebuilds that snapshot every
  /// time it is asked for (`skip == 0` always regenerates in main's
  /// `random-images`, which reseeds `picture_seed`). So the fresh copy of the
  /// pinned post arrives with its pictures freshly shuffled, while the card
  /// keeps its widget key and its carousel index across the swap: same post,
  /// same slot, a different photograph a second after launch. To the reader
  /// that is the same complaint [keepFirst] exists to answer, arriving one
  /// level down.
  ///
  /// So the arrangement on screen is carried over: every picture still served
  /// keeps its place, and anything the server has added since is appended in
  /// the server's own order rather than dropped. The picture *records* are the
  /// fresh ones throughout — a new price, a like counted, a comment closed all
  /// still land. Only the order is the reader's.
  ///
  /// Returns [fresh] itself when the order already agrees, so [keepFirst] can
  /// tell "nothing to do" from "rebuilt" by identity.
  @visibleForTesting
  static EventDiscovery keepMediaOrder(
    EventDiscovery fresh,
    EventDiscovery onScreen,
  ) {
    // One picture cannot be out of order, and neither can none.
    if (onScreen.pictures.length < 2 || fresh.pictures.length < 2) return fresh;

    final byId = {for (final p in fresh.pictures) p.id: p};
    final taken = <String>{};
    final ordered = <EventPicture>[];
    for (final was in onScreen.pictures) {
      final now = byId[was.id];
      if (now != null && taken.add(was.id)) ordered.add(now);
    }
    // Nothing in common — a different album behind the same id, or a cache
    // written before these records carried ids. The server's order is all
    // there is to go on.
    if (ordered.isEmpty) return fresh;
    for (final p in fresh.pictures) {
      if (!taken.contains(p.id)) ordered.add(p);
    }

    final unchanged = ordered.length == fresh.pictures.length &&
        Iterable<int>.generate(ordered.length)
            .every((i) => ordered[i].id == fresh.pictures[i].id);
    return unchanged ? fresh : fresh.copyWith(pictures: ordered);
  }

  /// [events] minus everything the user has hidden.
  ///
  /// Applied wherever events enter the state, not just where one was tapped.
  /// A hide that filtered only the list in front of you came straight back on
  /// the next fetch, which is the other half of "hiding doesn't work".
  @visibleForTesting
  static List<EventDiscovery> withoutHidden(
    List<EventDiscovery> events,
    Set<String> hidden,
  ) =>
      hidden.isEmpty
          ? events
          : events.where((e) => !hidden.contains(e.id)).toList();

  /// [incoming] minus everything already in [existing].
  ///
  /// Two pages of a PageView cannot carry the same key, and the feed keys its
  /// cards by event id — so an event arriving twice is not a cosmetic repeat,
  /// it is a build-time throw. The snapshot the server pages through is stable
  /// while it lives, but it is rebuilt on every first page and it expires on
  /// its own clock, so a card can legitimately turn up on two pages of what
  /// the reader experiences as one scroll.
  // Shared with the Following feed, for the same reason as [keepFirst].
  static List<EventDiscovery> withoutSeen(
    List<EventDiscovery> incoming,
    List<EventDiscovery> existing,
  ) {
    if (existing.isEmpty || incoming.isEmpty) return incoming;
    final seen = {for (final e in existing) e.id};
    return incoming.where((e) => !seen.contains(e.id)).toList();
  }

  void _persistHidden(Set<String> ids) {
    HiddenEvents.replace(ids).ignore();
  }

  // ── Save / unsave ─────────────────────────────────────────────────────────

  void _loadSavedItemsInBackground() {
    _authService.getToken().then((token) {
      if (token.isEmpty || isClosed) return;
      _savedDs.listSaved(assetType: 'event').then((items) {
        if (isClosed) return;
        final recordIds = <String, String>{
          for (final i in items) i.assetId: i.savedItemId,
        };
        add(_DiscoverySavedItemsLoaded(recordIds));
      }).catchError((_) {
        // Silently ignore — saved indicators simply won't be pre-populated.
      });
    }).catchError((_) {});
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

    // Same for the Bookmarked tab and the Saved screen — neither refetches on
    // its own any more.
    AppCacheSignals.saves.bump();

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
        final saved =
            await _savedDs.saveItem(assetType: 'event', assetId: event.eventId);
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
    _likeUpdateSub?.cancel();
    _wsConnectionSub?.cancel();
    _roomFetchTimer?.cancel();
    // Complete any pending completers so callers don't leak.
    for (final list in _roomFetchCompleters.values) {
      for (final c in list) {
        if (!c.isCompleted) c.complete();
      }
    }
    _roomFetchCompleters.clear();
    return super.close();
  }
}
