import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

part 'found_album_event.dart';
part 'found_album_state.dart';

/// Backs the album drill-down: every photo of one event, via
/// `GET /client/my-photos?eventId=<id>&groupBy=none`, paged.
///
/// This exists because the feed's albums only carry a `previewLimit`-sized
/// slice — opening an album has to fetch the rest rather than display the six
/// tiles it already had.
class FoundAlbumBloc extends Bloc<FoundAlbumEvent, FoundAlbumState> {
  FoundAlbumBloc({
    required GetFoundPhotosUseCase getFoundPhotosUseCase,
    required String eventId,
    FoundFilters filters = FoundFilters.none,
  })  : _getFound = getFoundPhotosUseCase,
        _filters = filters.copyWith(eventIds: {eventId}),
        super(const FoundAlbumState()) {
    // One event type on a sequential transformer — same reasoning as FoundBloc.
    on<FoundAlbumPhotosRequested>(_onRequested, transformer: sequential());
  }

  final GetFoundPhotosUseCase _getFound;

  /// The feed's active filters, narrowed to this one event. Carrying them
  /// through means an album opened under "Private only" shows the same set
  /// the user was just looking at.
  final FoundFilters _filters;

  static const pageSize = 30;

  Future<void> _onRequested(
      FoundAlbumPhotosRequested event, Emitter<FoundAlbumState> emit) async {
    if (event.loadMore && (!state.hasMore || state.isLoadingMore)) return;

    final nextPage = event.loadMore ? state.page + 1 : 1;
    emit(state.copyWith(
      isLoading: !event.loadMore,
      isLoadingMore: event.loadMore,
      clearError: true,
    ));

    try {
      final result = await _getFound.photos(
        filters: _filters,
        page: nextPage,
        limit: pageSize,
      );

      final photos = event.loadMore
          ? _merge(state.photos, result.photos)
          : result.photos;

      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        photos: photos,
        page: result.pagination.page,
        total: result.pagination.total,
        hasMore: result.pagination.hasNext,
      ));
    } on NetworkException catch (e) {
      emit(_failure(e.message));
    } on UnauthorizedException catch (e) {
      emit(_failure(e.message));
    } on ServerException catch (e) {
      emit(_failure(e.message));
    } catch (_) {
      emit(_failure('Failed to load this album.'));
    }
  }

  FoundAlbumState _failure(String message) => state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: message,
      );

  static List<Photo> _merge(List<Photo> existing, List<Photo> incoming) {
    final seen = existing.map((p) => p.id).toSet();
    return [...existing, ...incoming.where((p) => seen.add(p.id))];
  }
}
