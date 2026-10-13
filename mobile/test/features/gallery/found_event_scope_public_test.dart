import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/data/datasources/found_remote_data_source.dart'
    show FoundAlbumsPage, FoundPagination, FoundPhotosPage;
import 'package:jperg_app/features/gallery/domain/repositories/found_repository.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_album_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';

/// Whether an event-scoped Found read brings the rest of the album with it.
///
/// The bug: open one of your photos in Found and the whole event folder
/// appeared. The feed's sections are an *unscoped* read, so each one counts
/// only the photos the person was recognised in — but tapping into one narrows
/// the same query by `eventId`, and the server reads an event scope as
/// permission to widen ("asked about one event, the answer is that event",
/// public photos included). A section saying 6 opened a viewer holding 200,
/// almost none of them of the person swiping.
///
/// The flag is [FoundFilters.includePublic], and the Found tab has to *send*
/// it: a missing one is the server's default, which is the widening.
class RecordingFoundRepository implements FoundRepository {
  FoundFilters? lastPhotoFilters;
  FoundFilters? lastAlbumFilters;

  static const _empty = FoundPagination();

  @override
  Future<FoundPhotosPage> getPhotos({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
  }) async {
    lastPhotoFilters = filters;
    return const FoundPhotosPage(photos: [], pagination: _empty);
  }

  @override
  Future<FoundAlbumsPage> getAlbums({
    FoundFilters filters = FoundFilters.none,
    int page = 1,
    int limit = 25,
    int previewLimit = 6,
  }) async {
    lastAlbumFilters = filters;
    return const FoundAlbumsPage(
      albums: [],
      pagination: _empty,
      totalPhotos: 0,
      totalEvents: 0,
    );
  }

  @override
  Future<FoundFilterOptions> getFilterOptions(FoundFilters filters) async =>
      FoundFilterOptions.fromJson(const {});
}

/// Runs one page of the bloc's query and hands back what the server was asked.
Future<FoundFilters> asked({
  required String? eventId,
  required FoundFilters filters,
}) async {
  final repository = RecordingFoundRepository();
  final bloc = FoundAlbumBloc(
    getFoundPhotosUseCase: GetFoundPhotosUseCase(repository),
    eventId: eventId,
    filters: filters,
  );
  addTearDown(bloc.close);

  bloc.add(const FoundAlbumPhotosRequested());
  await bloc.stream.firstWhere((s) => !s.isLoading);

  return repository.lastPhotoFilters!;
}

void main() {
  group('the Found tab asks about the person', () {
    test('the default is photos of you', () {
      expect(FoundFilters.none.includePublic, isFalse);
    });

    test('an event-scoped drill-down says so out loud', () {
      // The album grid and the results viewer. Silence here is what opened the
      // folder, so `false` has to be on the wire.
      const scoped = FoundFilters(eventIds: {'evt-1'});
      final query = scoped.toQueryParameters();

      expect(query['eventId'], ['evt-1']);
      expect(query['includePublic'], isFalse,
          reason: 'the section it was opened from counted matches only');
    });

    test('unscoped it is the server default and stays off the wire', () {
      // The feed itself. Nothing to disagree about: no event, no widening.
      expect(
        FoundFilters.none.toQueryParameters().containsKey('includePublic'),
        isFalse,
      );
    });

    test('narrowing to an event does not quietly widen the question',
        () async {
      // FoundAlbumBloc is the one place the scope is added, for both the album
      // grid and the viewer. It must carry the flag through untouched.
      final filters = await asked(eventId: 'evt-1', filters: FoundFilters.none);

      expect(filters.eventIds, {'evt-1'});
      expect(filters.includePublic, isFalse);
      expect(filters.toQueryParameters()['includePublic'], isFalse);
    });
  });

  group('a scanned event asks about the album', () {
    test('it opts in, and the server already agrees', () {
      // Scoped and widened is the server's own default, so there is nothing to
      // say — the point is that this selection means the folder on purpose.
      const scanned = FoundFilters(
        eventIds: {'PRAISE26'},
        status: FoundMatchStatus.all,
        includePublic: true,
      );

      expect(scanned.includePublic, isTrue);
      expect(scanned.toQueryParameters().containsKey('includePublic'), isFalse);
      // Both halves of a scan's question: unanswered matches, and the event's
      // public photos to show when there are none of them.
      expect(scanned.toQueryParameters()['status'], 'all');
    });

    test('and the bloc keeps the opt-in when it narrows to that event',
        () async {
      final filters = await asked(
        eventId: 'evt-1',
        filters: const FoundFilters(
          status: FoundMatchStatus.all,
          includePublic: true,
        ),
      );

      expect(filters.includePublic, isTrue);
      expect(filters.toQueryParameters().containsKey('includePublic'), isFalse);
    });
  });

  test('it is not a filter the user set', () {
    // Like `status` and `eventIds`: a property of the screen asking. It must
    // not light the badge on the Filters button, and must not make `isActive`
    // true — which would send the feed down its across-events path.
    const scanned = FoundFilters(includePublic: true);
    expect(scanned.activeCount, 0);
    expect(scanned.isActive, isFalse);
  });

  test('two selections differing only in it are not the same query', () {
    const mine = FoundFilters(eventIds: {'e1'});
    const album = FoundFilters(eventIds: {'e1'}, includePublic: true);
    expect(mine, isNot(album));
    expect(mine.hashCode, isNot(album.hashCode));
  });
}
