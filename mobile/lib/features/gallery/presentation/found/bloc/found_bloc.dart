import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/utils/gallery_refresh_signal.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';

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

    emit(state.copyWith(
      filters: filters,
      isLoading: !event.loadMore,
      isLoadingMore: event.loadMore,
      clearError: true,
      // A filter change replaces the list; keeping the old albums on screen
      // under a spinner would show results that no longer match the chips.
      albums: event.loadMore || event.filters == null ? null : const [],
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

  FoundState _failure(String message) => state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: message,
      );

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
