import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/utils/gallery_refresh_signal.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';

part 'found_event.dart';
part 'found_state.dart';

/// Owns the Found tab's server state: pages of face-match albums from
/// `GET /client/my-photos?groupBy=event`, and the filter selection they were
/// fetched with.
///
/// The filter selection lives here rather than in the widget because filtering
/// is a server concern — changing a chip is a refetch from page 1, not a
/// re-render of loaded rows.
///
/// Refresh, filter-change and load-more are deliberately ONE event type on a
/// [sequential] transformer. Separate event types would be processed
/// concurrently by bloc's default transformer, so a filter change landing
/// mid-page-fetch could append the old filter's page 2 onto the new filter's
/// page 1.
class FoundBloc extends Bloc<FoundEvent, FoundState> {
  FoundBloc({required GetFoundPhotosUseCase getFoundPhotosUseCase})
      : _getFound = getFoundPhotosUseCase,
        super(const FoundState()) {
    on<FoundPhotosRequested>(_onPhotosRequested, transformer: sequential());
    // Reload when a purchase / free-save changes what the user owns — the
    // recognition list itself doesn't change, but `isPurchased` does.
    GalleryRefreshSignal.revision.addListener(_onRefreshSignal);
  }

  final GetFoundPhotosUseCase _getFound;

  /// Events per page. Photos per album come from `previewLimit` instead.
  static const pageSize = 25;

  /// Matches the six-tile preview grid in the design.
  static const previewLimit = 6;

  /// Photos per album once a filter is applied.
  ///
  /// Filtered sections drop the album framing and lay the matches out in one
  /// grid, so six tiles would hide most of a result the user just asked to see
  /// — an event with 17 matches would render 6. Asking for more keeps the grid
  /// honest without pulling whole albums for all 25 events on a page; anything
  /// past this still surfaces as the "+N" tile into the album page.
  static const filteredPreviewLimit = 18;

  static int previewLimitFor(FoundFilters filters) =>
      filters.isActive ? filteredPreviewLimit : previewLimit;

  void _onRefreshSignal() {
    if (!isClosed) add(const FoundPhotosRequested());
  }

  @override
  Future<void> close() {
    GalleryRefreshSignal.revision.removeListener(_onRefreshSignal);
    return super.close();
  }

  Future<void> _onPhotosRequested(
      FoundPhotosRequested event, Emitter<FoundState> emit) async {
    if (event.loadMore && (!state.hasMore || state.isLoadingMore)) return;

    final filters = event.filters ?? state.filters;
    final nextPage = event.loadMore ? state.page + 1 : 1;

    // The albums this tab last showed, straight off disk, so a cold open —
    // and an offline one — starts with content instead of a spinner. Only for
    // an unfiltered first load: a filter change must not be answered with the
    // unfiltered list, and a "load more" already has the earlier pages.
    final cached = (!event.loadMore && event.filters == null && state.albums.isEmpty)
        ? _restoreAlbums()
        : const <FoundAlbum>[];

    emit(state.copyWith(
      filters: filters,
      // Nothing to wait for when there is already something to read.
      isLoading: !event.loadMore && cached.isEmpty,
      isLoadingMore: event.loadMore,
      clearError: true,
      // A filter change replaces the list; keeping the old albums on screen
      // under a spinner would show results that no longer match the chips.
      albums: cached.isNotEmpty
          ? cached
          : (event.loadMore || event.filters == null ? null : const []),
    ));

    try {
      final result = await _getFound.albums(
        filters: filters,
        page: nextPage,
        limit: pageSize,
        previewLimit: previewLimitFor(filters),
      );

      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        albums: event.loadMore
            ? _merge(state.albums, result.albums)
            : result.albums,
        page: result.pagination.page,
        totalPhotos: result.totalPhotos,
        clearTotalPhotos: result.totalPhotos == null,
        totalEvents: result.totalEvents,
        hasMore: result.pagination.hasNext,
      ));
    } on NetworkException catch (e) {
      emit(_failure(e.message));
    } on BadRequestException catch (e) {
      emit(_failure(e.message));
    } on UnauthorizedException catch (e) {
      emit(_failure(e.message));
    } on ServerException catch (e) {
      emit(_failure(e.message));
    } catch (_) {
      emit(_failure('Failed to load your found photos.'));
    }
  }

  /// A failed refresh keeps whatever is on screen.
  ///
  /// The error is still reported, but the albums stay: with no connection the
  /// restored list is the only thing this tab has, and replacing it with an
  /// error message would undo the caching it was just restored from. The
  /// message reads as "could not refresh" rather than "nothing here".
  FoundState _failure(String message) => state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: message,
      );

  /// The last unfiltered first page, parsed with the same constructor the
  /// network response uses. Empty when there is no cache, or it is unreadable.
  List<FoundAlbum> _restoreAlbums() {
    try {
      final rows = sl<DiskCache>(instanceName: kFoundAlbumsCache).restore();
      if (rows.isEmpty) return const [];
      final albums = <FoundAlbum>[];
      for (final row in rows) {
        try {
          final album = FoundAlbum.fromJson(row);
          if (album.photos.isNotEmpty) albums.add(album);
        } catch (_) {
          // One bad row is not worth losing the rest of the tab.
        }
      }
      return albums;
    } catch (_) {
      return const [];
    }
  }

  /// Dedupes on append: a new match between two page fetches shifts the
  /// server's window, which would otherwise repeat an event.
  static List<FoundAlbum> _merge(
      List<FoundAlbum> existing, List<FoundAlbum> incoming) {
    final seen = existing.map((a) => a.id).toSet();
    return [
      ...existing,
      ...incoming.where((a) => seen.add(a.id)),
    ];
  }
}
