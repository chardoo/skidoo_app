import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographers_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/search_photographers_usecase.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

part 'photographer_event.dart';
part 'photographer_state.dart';

class PhotographerBloc extends Bloc<PhotographerEvent, PhotographerState> {
  final GetPhotographersUseCase _getPhotographersUseCase;
  final SearchPhotographersUseCase _searchPhotographersUseCase;

  PhotographerBloc({
    required GetPhotographersUseCase getPhotographersUseCase,
    required SearchPhotographersUseCase searchPhotographersUseCase,
  })  : _getPhotographersUseCase = getPhotographersUseCase,
        _searchPhotographersUseCase = searchPhotographersUseCase,
        super(const PhotographerState()) {
    on<PhotographersLoadRequested>(_onLoadRequested);
    on<PhotographersSearched>(_onSearched);
  }

  Future<void> _onLoadRequested(
      PhotographersLoadRequested event, Emitter<PhotographerState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final photographers =
          await _getPhotographersUseCase(const NoParams());
      emit(state.copyWith(isLoading: false, photographers: photographers));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Failed to load photographers.'));
    }
  }

  Future<void> _onSearched(
      PhotographersSearched event, Emitter<PhotographerState> emit) async {
    if (event.query.isEmpty) {
      add(const PhotographersLoadRequested());
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final photographers = await _searchPhotographersUseCase(
          SearchPhotographersParams(event.query));
      emit(state.copyWith(isLoading: false, photographers: photographers));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: 'Search failed.'));
    }
  }
}
