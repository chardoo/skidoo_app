import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/domain/repositories/search_repository.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:jperg_app/models/photos/Photo.dart';

// ── Fixtures ─────────────────────────────────────────────────────────────────

SearchEventRow event(int i) => SearchEventRow.fromJson({
      'id': 'evt-$i',
      'eventName': 'Reloaded $i',
      'photoCount': 108,
    });

SearchPhotographerRow photographer(int i) => SearchPhotographerRow.fromJson({
      'id': 'ph-$i',
      'name': 'Efo $i',
      'followerCount': 1024,
    });

Photo photo(int i) => Photo.fromMap({
      'id': 'pic-$i',
      'url': 'https://cdn/$i.jpg',
      'event': {'id': 'evt-1', 'eventName': 'Reloaded 1'},
    });

SearchPagination page({
  int page = 1,
  int total = 30,
  bool hasNext = true,
}) =>
    SearchPagination(
      page: page,
      limit: 25,
      total: total,
      totalPages: 2,
      hasNext: hasNext,
    );

/// Records the calls the bloc makes and answers with whatever the test set up.
class FakeSearchRepository implements SearchRepository {
  SearchAllResults allResult = SearchAllResults.empty;
  Object? allError;

  /// Answers keyed by the page number asked for.
  final Map<int, SearchSectionPage<SearchEventRow>> eventPages = {};

  /// Blocks the next `searchEvents` until completed, for interleaving tests.
  Completer<void>? gate;

  YouMayLikePage youMayLikeResult =
      const YouMayLikePage(photos: [], nextCursor: null);

  final calls = <String>[];

  @override
  Future<SearchAllResults> searchAll(String query) async {
    calls.add('all:$query');
    if (allError != null) throw allError!;
    return allResult;
  }

  @override
  Future<SearchSectionPage<SearchEventRow>> searchEvents(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
    calls.add('events:$query:$page');
    if (gate != null) await gate!.future;
    return eventPages[page] ??
        const SearchSectionPage(items: [], pagination: SearchPagination());
  }

  @override
  Future<SearchSectionPage<SearchPhotographerRow>> searchPhotographers(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
    calls.add('photographers:$query:$page');
    return const SearchSectionPage(items: [], pagination: SearchPagination());
  }

  @override
  Future<SearchSectionPage<SearchTagRow>> searchTags(
    String query, {
    int page = 1,
    int limit = 25,
  }) async {
    calls.add('tags:$query:$page');
    return const SearchSectionPage(items: [], pagination: SearchPagination());
  }

  @override
  Future<TagEventsPage> eventsForTag(String tag,
          {int page = 1, int limit = 25}) async =>
      TagEventsPage(
        tag: tag,
        label: '#$tag',
        postCount: 0,
        eventCount: 0,
        events: const [],
        pagination: const SearchPagination(),
      );

  @override
  Future<YouMayLikePage> youMayLike({
    int limit = 30,
    int cursor = 0,
    bool refresh = false,
  }) async {
    calls.add('yml:$cursor:$refresh');
    return youMayLikeResult;
  }

  @override
  Future<EventPhotosPage> eventPhotos(String eventId,
          {int page = 1, int limit = 30, String? around}) async =>
      const EventPhotosPage(
        event: SearchEventRow.empty,
        photos: [],
        pagination: SearchPagination(),
      );

  /// Only the deep-link resolver calls this; the bloc under test never does.
  @override
  Future<Photo> pictureById(String pictureId) async =>
      throw UnimplementedError();
}

/// Past the bloc's 320 ms debounce with room for the fake's microtasks.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 500));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSearchRepository repo;
  late SearchBloc bloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo = FakeSearchRepository();
    bloc = SearchBloc(searchUseCase: SearchUseCase(repo));
  });

  tearDown(() => bloc.close());

  // ── Querying ───────────────────────────────────────────────────────────────

  group('query', () {
    test('debounces so only the query the user paused on is fetched', () async {
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 1},
        'total': 1,
        'events': [
          {'id': 'evt-1', 'eventName': 'Reloaded 1'}
        ],
      });

      bloc
        ..add(const SearchRequested.query('R'))
        ..add(const SearchRequested.query('Re'))
        ..add(const SearchRequested.query('Reloaded'));
      await settle();

      expect(repo.calls, ['all:Reloaded']);
      expect(bloc.state.query, 'Reloaded');
      expect(bloc.state.status, SearchStatus.success);
    });

    test('a query chosen whole is fetched without waiting', () async {
      // A recent search tapped, the keyboard's search key, a code from the
      // unlock sheet. The debounce is there to wait out the next keystroke and
      // there is not going to be one — waiting anyway is a third of a second
      // in which the tap looks like it missed.
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 1},
        'total': 1,
        'events': [
          {'id': 'evt-1', 'eventName': 'Amalitech'}
        ],
      });

      bloc.add(const SearchRequested.now('Amalitech'));
      // Well inside the 320 ms a typed query would still be waiting out.
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(repo.calls, ['all:Amalitech']);
      expect(bloc.state.status, SearchStatus.success);
    });

    test('a typed query is still made to wait', () async {
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 0},
        'total': 0,
      });

      bloc.add(const SearchRequested.query('Amalitech'));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(repo.calls, isEmpty,
          reason: 'typing one letter must not fetch on that letter');
      await settle();
      expect(repo.calls, ['all:Amalitech']);
    });

    test('typing after a chosen query still cancels it', () async {
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 0},
        'total': 0,
      });

      // Immediate does not mean uninterruptible: the handler is restartable,
      // so a keystroke landing on top of a tapped recent still wins.
      bloc
        ..add(const SearchRequested.now('Amalitech'))
        ..add(const SearchRequested.query('Amalitech Graduation'));
      await settle();

      expect(bloc.state.query, 'Amalitech Graduation');
      expect(repo.calls.last, 'all:Amalitech Graduation');
    });

    test('total 0 is the empty state and offers no chips', () async {
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 0, 'photographers': 0, 'tags': 0},
        'total': 0,
      });

      bloc.add(const SearchRequested.query('Vnzbd'));
      await settle();

      expect(bloc.state.isEmptyResult, isTrue);
      expect(bloc.state.visibleTypes, isEmpty);
    });

    test('opens on the leftmost section that matched', () async {
      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 0, 'photographers': 5, 'tags': 4},
        'total': 9,
        'photographers': [
          {'id': 'ph-1', 'name': 'Efo'}
        ],
      });

      bloc.add(const SearchRequested.query('Efo'));
      await settle();

      expect(bloc.state.activeType, SearchResultType.photographers);
      expect(bloc.state.visibleTypes,
          [SearchResultType.photographers, SearchResultType.tags]);
    });

    test('a failure keeps the query so retry has something to send', () async {
      repo.allError = const NetworkException();

      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();

      expect(bloc.state.status, SearchStatus.failure);
      expect(bloc.state.errorMessage, 'No internet connection.');
      expect(bloc.state.query, 'Reloaded');
    });

    test('clearing returns to the idle screen but keeps the grid', () async {
      repo.youMayLikeResult =
          YouMayLikePage(photos: [photo(1)], nextCursor: 30);
      bloc.add(const SearchYouMayLikeRequested());
      await settle();

      repo.allResult = SearchAllResults.fromJson(const {
        'counts': {'events': 1},
        'total': 1,
        'events': [
          {'id': 'evt-1'}
        ],
      });
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();

      bloc.add(const SearchCleared());
      await settle();

      expect(bloc.state.isIdle, isTrue);
      expect(bloc.state.total, 0);
      // Reloading the grid on every ✕ would reshuffle it under the user.
      expect(bloc.state.youMayLike, hasLength(1));
      expect(bloc.state.youMayLikeCursor, 30);
    });
  });

  // ── Paging a section ───────────────────────────────────────────────────────

  group('section paging', () {
    setUp(() {
      // The `type=all` preview: 10 of 30 events.
      repo.allResult = SearchAllResults(
        query: 'Reloaded',
        counts: const SearchCounts(events: 30),
        total: 30,
        events: [for (var i = 0; i < 10; i++) event(i)],
        photographers: const [],
        tags: const [],
      );
      repo.eventPages[1] = SearchSectionPage(
        items: [for (var i = 0; i < 25; i++) event(i)],
        pagination: page(page: 1, hasNext: true),
      );
      repo.eventPages[2] = SearchSectionPage(
        items: [for (var i = 25; i < 30; i++) event(i)],
        pagination: page(page: 2, hasNext: false),
      );
    });

    test('page 1 replaces the preview instead of duplicating it', () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      expect(bloc.state.events.items, hasLength(10));
      expect(bloc.state.events.needsFirstPage, isTrue);

      bloc.add(const SearchSectionMoreRequested(
          'Reloaded', SearchResultType.events));
      await settle();

      // 25, not 35 — page 1 is a superset of the ten already on screen.
      expect(bloc.state.events.items, hasLength(25));
      expect(bloc.state.events.page, 1);
    });

    test('later pages append and paging stops at the end', () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      bloc.add(const SearchSectionMoreRequested(
          'Reloaded', SearchResultType.events));
      await settle();
      bloc.add(const SearchSectionMoreRequested(
          'Reloaded', SearchResultType.events));
      await settle();

      expect(bloc.state.events.items, hasLength(30));
      expect(bloc.state.events.hasNext, isFalse);
      expect(bloc.state.events.canLoadMore, isFalse);
    });

    test('a burst of scroll events fetches one page, not one per frame',
        () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      repo.calls.clear();

      // The regression this guards is the whole reason paging is a separate
      // `droppable` event: under `restartable` each of these would cancel the
      // fetch the one before it started, and no page would ever arrive.
      repo.gate = Completer<void>();
      for (var i = 0; i < 10; i++) {
        bloc.add(const SearchSectionMoreRequested(
            'Reloaded', SearchResultType.events));
      }
      await settle();
      expect(repo.calls, ['events:Reloaded:1']);

      repo.gate!.complete();
      await settle();
      expect(bloc.state.events.items, hasLength(25));
    });

    test('a page for a query the user moved on from is never requested',
        () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      repo.calls.clear();

      bloc.add(
          const SearchSectionMoreRequested('Relo', SearchResultType.events));
      await settle();

      expect(repo.calls, isEmpty);
    });

    test('a page that outlives its query is discarded', () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();

      // Hold page 1 open, start it, then let a new query land first.
      repo.gate = Completer<void>();
      bloc.add(const SearchSectionMoreRequested(
          'Reloaded', SearchResultType.events));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      repo.allResult = SearchAllResults(
        query: 'Genesis',
        counts: const SearchCounts(events: 1),
        total: 1,
        events: [event(99)],
        photographers: const [],
        tags: const [],
      );
      bloc.add(const SearchRequested.query('Genesis'));
      await settle();

      repo.gate!.complete();
      await settle();

      expect(bloc.state.query, 'Genesis');
      // The 25 stale rows must not have replaced Genesis's single result.
      expect(bloc.state.events.items, hasLength(1));
      expect(bloc.state.events.items.single.id, 'evt-99');
    });

    test('switching chips tops up a section the preview cut short', () async {
      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      repo.calls.clear();

      bloc.add(
          const SearchRequested.type('Reloaded', SearchResultType.events));
      await settle();

      expect(bloc.state.activeType, SearchResultType.events);
      expect(repo.calls, ['events:Reloaded:1']);
    });

    test('switching to a section already complete fetches nothing', () async {
      repo.allResult = SearchAllResults(
        query: 'Reloaded',
        counts: const SearchCounts(events: 2, photographers: 2),
        total: 4,
        events: [event(0), event(1)],
        photographers: [photographer(0), photographer(1)],
        tags: const [],
      );

      bloc.add(const SearchRequested.query('Reloaded'));
      await settle();
      repo.calls.clear();

      bloc.add(const SearchRequested.type(
          'Reloaded', SearchResultType.photographers));
      await settle();

      expect(bloc.state.activeType, SearchResultType.photographers);
      expect(repo.calls, isEmpty);
    });
  });

  // ── You may like ───────────────────────────────────────────────────────────

  group('you may like', () {
    test('loads once and is not refetched on a revisit', () async {
      repo.youMayLikeResult =
          YouMayLikePage(photos: [photo(1), photo(2)], nextCursor: 30);

      bloc.add(const SearchYouMayLikeRequested());
      await settle();
      bloc.add(const SearchYouMayLikeRequested());
      await settle();

      expect(repo.calls, ['yml:0:false']);
      expect(bloc.state.youMayLike, hasLength(2));
    });

    test('the refresh button asks for a new snapshot', () async {
      repo.youMayLikeResult = YouMayLikePage(photos: [photo(1)], nextCursor: 30);
      bloc.add(const SearchYouMayLikeRequested());
      await settle();

      repo.youMayLikeResult = YouMayLikePage(photos: [photo(9)], nextCursor: 30);
      bloc.add(const SearchYouMayLikeRequested(refresh: true));
      await settle();

      expect(repo.calls, ['yml:0:false', 'yml:0:true']);
      expect(bloc.state.youMayLike.single.id, 'pic-9');
    });

    test('paging appends by cursor and stops when the set runs out', () async {
      repo.youMayLikeResult = YouMayLikePage(photos: [photo(1)], nextCursor: 30);
      bloc.add(const SearchYouMayLikeRequested());
      await settle();

      repo.youMayLikeResult =
          YouMayLikePage(photos: [photo(2)], nextCursor: null);
      bloc.add(const SearchYouMayLikeMoreRequested());
      await settle();

      expect(repo.calls.last, 'yml:30:false');
      expect(bloc.state.youMayLike, hasLength(2));
      // A null cursor is the end of the snapshot, not an error.
      expect(bloc.state.youMayLikeCursor, isNull);
      expect(bloc.state.canLoadMoreYouMayLike, isFalse);

      bloc.add(const SearchYouMayLikeMoreRequested());
      await settle();
      expect(repo.calls.last, 'yml:30:false');
    });
  });

  // ── Recent searches ────────────────────────────────────────────────────────

  group('recents', () {
    test('newest first, de-duplicated case-insensitively', () async {
      bloc
        ..add(const SearchRecentSaved('Praise Reloaded'))
        ..add(const SearchRecentSaved('Telecel Music Awards'))
        ..add(const SearchRecentSaved('praise reloaded'));
      await settle();

      expect(bloc.state.recents, ['praise reloaded', 'Telecel Music Awards']);
    });

    test('the ✕ removes one row and leaves the rest', () async {
      bloc
        ..add(const SearchRecentSaved('A'))
        ..add(const SearchRecentSaved('B'));
      await settle();

      bloc.add(const SearchRecentRemoved('A'));
      await settle();

      expect(bloc.state.recents, ['B']);
    });

    test('survives a restart — they live on the device', () async {
      bloc.add(const SearchRecentSaved('Praise Reloaded'));
      await settle();
      await bloc.close();

      final revived = SearchBloc(searchUseCase: SearchUseCase(repo))
        ..add(const SearchRecentsRequested());
      await settle();

      expect(revived.state.recents, ['Praise Reloaded']);
      await revived.close();
    });
  });
}
