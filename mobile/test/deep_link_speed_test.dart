import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/domain/repositories/search_repository.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/features/search/presentation/bloc/event_photos_bloc.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What a deep link waits for before the screen it points at appears.
///
/// The routing was never the slow part. The time went on a splash the link had
/// to sit behind, a Home rebuilt from scratch under it, and — for a shared
/// photo — one request per thirty photos until the album reached it. These pin
/// the three.

// ── A parked link announces itself ───────────────────────────────────────────
//
// The splash reads this to cut its brand beat and feed warm-up short: someone
// who tapped a link is not waiting to look at the feed.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a link waiting to open is visible to the splash', () {
    tearDown(() => DeepLinkService.isWaiting.value = false);

    test('parking a link raises the flag', () async {
      final service = DeepLinkService(isSignedIn: () async => true);
      expect(DeepLinkService.isWaiting.value, isFalse);

      await service.follow(const DeepLink(DeepLinkKind.event, id: 'e1'));

      expect(DeepLinkService.isWaiting.value, isTrue,
          reason: 'the splash has nothing else to tell it to hurry');
    });

    test('it notifies rather than only being readable', () async {
      final service = DeepLinkService(isSignedIn: () async => true);
      var fired = 0;
      void listener() => fired++;
      DeepLinkService.isWaiting.addListener(listener);

      await service.follow(const DeepLink(DeepLinkKind.picture, id: 'p1'));

      expect(fired, 1,
          reason: 'a splash already waiting must be woken, not polled');
      DeepLinkService.isWaiting.removeListener(listener);
    });

    test('a URL with no screen behind it raises nothing', () async {
      final service = DeepLinkService(isSignedIn: () async => true);

      await service.handle(Uri.parse('https://jperg.com/privacy'));

      expect(DeepLinkService.isWaiting.value, isFalse,
          reason: 'a website page must not cut the splash short');
    });
  });

  // ── The album opens on the page holding the photo ──────────────────────────

  group('a shared photo does not page its way down the album', () {
    late _FakeRepo repo;
    late EventPhotosBloc bloc;

    setUp(() {
      repo = _FakeRepo();
      bloc = EventPhotosBloc(
        searchUseCase: SearchUseCase(repo),
        eventId: 'evt-1',
      );
    });

    tearDown(() => bloc.close());

    test('the first request asks for the page the photo is on', () async {
      bloc.add(const EventPhotosRequested(around: 'pic-17'));
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls.single, 'photos:page=1:around=pic-17');
    });

    test('the cursor becomes the page the server actually returned', () async {
      // Asked for page 1 with `around`; the server answers with page 2.
      repo.pageToReturn = 2;
      bloc.add(const EventPhotosRequested(around: 'pic-17'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.page, 2,
          reason: 'the next scroll must ask for 3, not for 2 again');

      bloc.add(const EventPhotosMoreRequested());
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls.last, 'photos:page=3:around=null');
    });

    test('an ordinary album open still starts at page one', () async {
      bloc.add(const EventPhotosRequested());
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls.single, 'photos:page=1:around=null');
      expect(bloc.state.page, 1);
    });
  });
}

/// Records what was asked for and answers with a page of one photo.
class _FakeRepo implements SearchRepository {
  final calls = <String>[];
  int pageToReturn = 1;

  @override
  Future<EventPhotosPage> eventPhotos(
    String eventId, {
    int page = 1,
    int limit = 30,
    String? around,
  }) async {
    calls.add('photos:page=$page:around=$around');
    return EventPhotosPage(
      event: SearchEventRow.empty,
      photos: [
        Photo.fromMap({'id': 'pic-17', 'url': 'https://cdn/17.jpg'}),
      ],
      pagination: SearchPagination(
        page: around == null ? page : pageToReturn,
        limit: limit,
        total: 100,
        totalPages: 4,
        hasNext: true,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}
