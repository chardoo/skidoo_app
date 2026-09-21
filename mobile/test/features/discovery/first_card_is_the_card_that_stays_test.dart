import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:jperg_app/features/discovery/data/services/feed_cache_service.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:jperg_app/models/chat/like_update.dart';
import 'package:jperg_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:jperg_app/core/cache/hidden_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

EventDiscovery ev(String id, {List<String> pics = const []}) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'C',
      photographerId: 'c1',
      pictures: [
        for (final p in pics)
          EventPicture(id: p, url: 'u/$p', imageId: 'i$p', price: 1),
      ],
    );

class _Cache implements FeedCacheService {
  _Cache(this._cached, {bool handoff = false}) : _handoff = handoff;
  final List<EventDiscovery> _cached;
  bool _handoff;
  @override
  List<EventDiscovery> restore() => _cached;
  @override
  bool takeHandoff() {
    final was = _handoff;
    _handoff = false;
    return was;
  }

  @override
  Future<void> save(List<EventDiscovery> e,
      {bool warmedForLaunch = false}) async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Images implements GetRandomImagesUseCase {
  _Images(this._fresh);
  final List<EventDiscovery> _fresh;

  /// Every first-page request this saw. The launch must make exactly one.
  final calls = <int>[];

  @override
  Future<List<EventDiscovery>> call({
    int? take,
    int? skip,
    String? userId,
    List<String>? followedPhotographerIds,
  }) async {
    calls.add(skip ?? 0);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return _fresh;
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  Future<String> getUserId() async => 'me';
  @override
  Future<String> getToken() async => '';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Ws implements ChatWebSocketService {
  @override
  bool get isConnected => false;
  @override
  Stream<LikeUpdate> get likeUpdates => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Bg implements ChatBackgroundService {
  @override
  final ChatWebSocketService sharedWs = _Ws();
  @override
  Stream<bool> get connectionEvents => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Saved implements ClientSavedDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Repo implements ChatRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// What the reader is actually looking at: the post, and the photo of it the
/// card is showing. Both halves have to hold still, so both are watched.
String _showing(EventDiscovery e) =>
    e.pictures.isEmpty ? e.id : '${e.id}/${e.pictures.first.id}';

/// The first card must be the card that stays.
///
/// Four things could move it after the feed was already on screen, and all of
/// them arrived a second or so in — long enough for the reader to have started
/// looking at it:
///
///  1. The server's fresh order replacing the cached one. [DiscoveryBloc.keepFirst]
///     answers that, and is covered as a function in first_card_stays_put_test.
///  2. The hidden set, restored asynchronously at construction while the cache
///     painted synchronously — so a post the reader had hidden was drawn and
///     then taken away. If it was first, the card slid off on its own.
///  3. The photos *inside* the pinned post, which the server re-deals on every
///     first page — see [DiscoveryBloc.keepMediaOrder]. The post held its slot
///     and showed a different photograph, which to the reader is the same
///     complaint.
///  4. The reactions patch, a second round trip later, which used to swap in
///     the whole record it had fetched and so undid (1) and (3) a moment after
///     they were applied.
///
/// These drive the real bloc through a cold start and watch every state it
/// emits, which is the only way to see any of them: each is correct in every
/// individual emit and wrong only as a sequence.
/// The requests the last [firstCardSequence] made, by `skip`.
List<int> lastCallSkips = const [];

Future<List<String>> firstCardSequence({
  required List<EventDiscovery> cached,
  required List<EventDiscovery> fresh,
  List<String> hidden = const [],
  bool handoff = false,
}) async {
  SharedPreferences.setMockInitialValues(
      {'discovery_hidden_event_ids': hidden});
  HiddenEvents.debugReset();

  final images = _Images(fresh);
  final bloc = DiscoveryBloc(
    getRandomImagesUseCase: images,
    getReactionsBatch: GetEventReactionsBatchUseCase(_Repo()),
    getEventRoomsBatch: GetEventRoomsBatchUseCase(_Repo()),
    feedCache: _Cache(cached, handoff: handoff),
  );

  final firsts = <String>[];
  final sub = bloc.stream.listen((s) {
    if (s.events.isNotEmpty) firsts.add(_showing(s.events.first));
  });

  bloc.add(const DiscoveryLoadRequested());
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await sub.cancel();
  await bloc.close();
  lastCallSkips = images.calls;
  return firsts;
}

void main() {
  setUp(() async {
    // A reader who hid the post that is first in the cache.
    SharedPreferences.setMockInitialValues(
        {'discovery_hidden_event_ids': <String>['a']});
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthService>(_Auth());
    GetIt.I.registerSingleton<ChatBackgroundService>(_Bg());
    GetIt.I.registerSingleton<ClientSavedDataSource>(_Saved());
  });

  test('the server re-dealing does not move the card on screen', () async {
    // Cache shows a. The server now ranks it third.
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b'), ev('c')],
      fresh: [ev('b'), ev('c'), ev('a'), ev('d')],
    );

    expect(firsts, isNotEmpty);
    expect(firsts.toSet(), {'a'}, reason: 'the first card changed: $firsts');
  });

  test('a post the server dropped off the page still holds its slot', () async {
    // The case that was live on every launch and that the page-length
    // heuristic did not catch: the re-deal demotes the cached leader clean out
    // of the page, because demoting the previous leader is exactly what the
    // ranking is built to do.
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b')],
      fresh: [ev('c'), ev('d')],
    );

    expect(firsts, isNotEmpty);
    expect(firsts.toSet(), {'a'}, reason: 'the first card changed: $firsts');
  });

  test('the splash page is adopted instead of being re-dealt', () async {
    // The root of it. The splash fetches the first page, stores it and spends
    // the brand animation decoding its top card's photograph; the bloc then
    // asked for the first page again, and `skip == 0` is a fresh deal
    // server-side. One launch, one first-page request.
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b')],
      fresh: [ev('c'), ev('d')],
      handoff: true,
    );

    expect(firsts.toSet(), {'a'}, reason: 'the first card changed: $firsts');
    expect(lastCallSkips, isEmpty,
        reason: 'the splash had already fetched this page');
  });

  test('a hidden post is never the first card, not even briefly', () async {
    // The reader hid 'a'. It used to be painted from cache and removed a
    // moment later, so the feed opened on a post and then slid off it.
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b'), ev('c')],
      fresh: [ev('b'), ev('c'), ev('d')],
      hidden: ['a'],
    );

    expect(firsts, isNotEmpty);
    expect(firsts.toSet(), {'b'}, reason: 'the first card changed: $firsts');
  });

  test('the photo on the first card does not change either', () async {
    // The post holds its slot, and the server re-dealt its album — which is
    // the thing the reader was actually looking at.
    final firsts = await firstCardSequence(
      cached: [ev('a', pics: ['p3', 'p1', 'p2']), ev('b')],
      fresh: [ev('a', pics: ['p1', 'p2', 'p3']), ev('b')],
    );

    expect(firsts, isNotEmpty);
    expect(firsts.toSet(), {'a/p3'}, reason: 'the first card changed: $firsts');
  });

  test('and the reactions patch does not put it back', () async {
    // The patch lands a second round trip after the feed, carrying the
    // server's own copy of every event. Swapping those in wholesale undid the
    // pin — the post moved back and the photo with it, seconds after launch.
    final firsts = await firstCardSequence(
      cached: [ev('a', pics: ['p3', 'p1']), ev('b')],
      fresh: [ev('b'), ev('a', pics: ['p1', 'p3'])],
    );

    expect(firsts, isNotEmpty);
    expect(firsts.toSet(), {'a/p3'}, reason: 'the first card changed: $firsts');
  });

  test('and the hidden post is gone from the feed entirely', () async {
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b')],
      fresh: [ev('a'), ev('b')],
      hidden: ['a'],
    );

    expect(firsts, everyElement('b'));
  });
}
