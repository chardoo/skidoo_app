import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/models/photos/Photo.dart';

part 'event_photos_event.dart';
part 'event_photos_state.dart';

/// The grid behind an event row — `GET /client/events/{eventId}/photos`.
///
/// Visibility is the server's call and matches the face-search stream: public
/// photos for everyone, every photo for an owner, plus any private photo the
/// viewer is recognised in. Nothing is filtered here.
class EventPhotosBloc extends Bloc<EventPhotosEvent, EventPhotosState> {
  EventPhotosBloc({
    required SearchUseCase searchUseCase,
    required this.eventId,
  })  : _search = searchUseCase,
        super(const EventPhotosState()) {
    on<EventPhotosRequested>(_onRequested, transformer: restartable());
    on<EventPhotosMoreRequested>(_onMoreRequested, transformer: droppable());
  }

  final SearchUseCase _search;

  /// The event id **or** its access code — the endpoint accepts either.
  final String eventId;

  static const _limit = 30;

  Future<void> _onRequested(
      EventPhotosRequested event, Emitter<EventPhotosState> emit) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _fetch(page: 1, more: false, emit: emit, around: event.around);
  }

  Future<void> _onMoreRequested(
      EventPhotosMoreRequested event, Emitter<EventPhotosState> emit) async {
    if (!state.hasNext || state.isLoadingMore || state.isLoading) return;
    final page = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));
    await _fetch(page: page, more: true, emit: emit);
  }

  Future<void> _fetch({
    required int page,
    required bool more,
    required Emitter<EventPhotosState> emit,
    String? around,
  }) async {
    try {
      final result = await _search.eventPhotos(
        eventId,
        page: page,
        limit: _limit,
        around: around,
      );
      if (emit.isDone) return;
      // With `around` the server chose the page, so the cursor is whatever it
      // says it gave us — not what we asked for. Getting this wrong would make
      // the next scroll re-request a page already on screen.
      page = around == null ? page : result.pagination.page;
      // A refresh that landed while this page was in flight already reset the
      // list; appending to it now would duplicate its first page.
      if (more && state.page != page - 1) {
        emit(state.copyWith(isLoadingMore: false));
        return;
      }
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        event: result.event,
        photos: more ? [...state.photos, ...result.photos] : result.photos,
        page: page,
        hasNext: result.pagination.hasNext,
        total: result.pagination.total,
        clearError: true,
      ));
    } catch (error) {
      if (emit.isDone) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        // Paging failures keep the grid and stay quiet — the next scroll
        // retries. Only a failed first page has nothing else to show.
        errorMessage: more
            ? null
            : switch (error) {
                NotFoundException e => e.message,
                NetworkException e => e.message,
                ServerException e => e.message,
                UnauthorizedException e => e.message,
                _ => 'Could not load photos.',
              },
      ));
    }
  }
}
