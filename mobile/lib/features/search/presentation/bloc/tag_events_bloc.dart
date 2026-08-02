import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/domain/usecases/search_usecase.dart';

part 'tag_events_event.dart';
part 'tag_events_state.dart';

/// The events behind one tag row — `GET /client/search/tags/{tag}`.
class TagEventsBloc extends Bloc<TagEventsEvent, TagEventsState> {
  TagEventsBloc({
    required SearchUseCase searchUseCase,
    required this.tag,
  })  : _search = searchUseCase,
        super(const TagEventsState()) {
    on<TagEventsRequested>(_onRequested, transformer: restartable());
    on<TagEventsMoreRequested>(_onMoreRequested, transformer: droppable());
  }

  final SearchUseCase _search;

  /// With or without the leading `#` — the data source strips it.
  final String tag;

  static const _limit = 25;

  Future<void> _onRequested(
      TagEventsRequested event, Emitter<TagEventsState> emit) async {
    if (state.isLoading) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    await _fetch(page: 1, more: false, emit: emit);
  }

  Future<void> _onMoreRequested(
      TagEventsMoreRequested event, Emitter<TagEventsState> emit) async {
    if (!state.hasNext || state.isLoadingMore || state.isLoading) return;
    final page = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));
    await _fetch(page: page, more: true, emit: emit);
  }

  Future<void> _fetch({
    required int page,
    required bool more,
    required Emitter<TagEventsState> emit,
  }) async {
    try {
      final result = await _search.tagEvents(tag, page: page, limit: _limit);
      if (emit.isDone) return;
      // A refresh that landed first already reset the list — see the same
      // guard in [EventPhotosBloc].
      if (more && state.page != page - 1) {
        emit(state.copyWith(isLoadingMore: false));
        return;
      }
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        label: result.label,
        postCount: result.postCount,
        eventCount: result.eventCount,
        events: more ? [...state.events, ...result.events] : result.events,
        page: page,
        hasNext: result.pagination.hasNext,
        clearError: true,
      ));
    } catch (error) {
      if (emit.isDone) return;
      emit(state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: more
            ? null
            : switch (error) {
                NotFoundException e => e.message,
                NetworkException e => e.message,
                ServerException e => e.message,
                _ => 'Could not load this tag.',
              },
      ));
    }
  }
}
