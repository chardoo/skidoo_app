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

EventDiscovery ev(String id) => EventDiscovery(
      id: id,
      eventName: 'Event $id',
      photographerName: 'C',
      photographerId: 'c1',
      pictures: const [],
    );

class _Cache implements FeedCacheService {
  _Cache(this._cached);
  final List<EventDiscovery> _cached;
  @override
  List<EventDiscovery> restore() => _cached;
  @override
  Future<void> save(List<EventDiscovery> e) async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Images implements GetRandomImagesUseCase {
  _Images(this._fresh);
  final List<EventDiscovery> _fresh;
  @override
  Future<List<EventDiscovery>> call({
    int? take,
    int? skip,
    String? userId,
    List<String>? followedPhotographerIds,
  }) async {
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

/// The first card must be the card that stays.
///
/// Two things could move it after the feed was already on screen, and both
/// arrived a second or so in — long enough for the reader to have started
/// looking at it:
///
///  1. The server's fresh order replacing the cached one. [DiscoveryBloc.keepFirst]
///     answers that, and is covered as a function in first_card_stays_put_test.
///  2. The hidden set, restored asynchronously at construction while the cache
///     painted synchronously — so a post the reader had hidden was drawn and
///     then taken away. If it was first, the card slid off on its own.
///
/// These drive the real bloc through a cold start and watch every state it
/// emits, which is the only way to see either: both are correct in each
/// individual emit and wrong only as a sequence.
Future<List<String>> firstCardSequence({
  required List<EventDiscovery> cached,
  required List<EventDiscovery> fresh,
  List<String> hidden = const [],
}) async {
  SharedPreferences.setMockInitialValues(
      {'discovery_hidden_event_ids': hidden});
  HiddenEvents.debugReset();

  final bloc = DiscoveryBloc(
    getRandomImagesUseCase: _Images(fresh),
    getReactionsBatch: GetEventReactionsBatchUseCase(_Repo()),
    getEventRoomsBatch: GetEventRoomsBatchUseCase(_Repo()),
    feedCache: _Cache(cached),
  );

  final firsts = <String>[];
  final sub = bloc.stream.listen((s) {
    if (s.events.isNotEmpty) firsts.add(s.events.first.id);
  });

  bloc.add(const DiscoveryLoadRequested());
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await sub.cancel();
  await bloc.close();
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

  test('and the hidden post is gone from the feed entirely', () async {
    final firsts = await firstCardSequence(
      cached: [ev('a'), ev('b')],
      fresh: [ev('a'), ev('b')],
      hidden: ['a'],
    );

    expect(firsts, everyElement('b'));
  });
}
