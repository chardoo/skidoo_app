import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/home/domain/usecases/search_events_usecase.dart';
import 'package:skidoo_app/features/home/domain/usecases/search_images_usecase.dart';
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/di/service_locator.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SearchEventsUseCase _searchEventsUseCase;
  final SearchImagesUseCase _searchImagesUseCase;
  final AuthService _authService;

  HomeBloc({
    required SearchEventsUseCase searchEventsUseCase,
    required SearchImagesUseCase searchImagesUseCase,
  })  : _searchEventsUseCase = searchEventsUseCase,
        _searchImagesUseCase = searchImagesUseCase,
        _authService = sl<AuthService>(),
        super(const HomeState()) {
    on<HomeInitialized>(_onInitialized);
    on<HomeEventSearched>(_onEventSearched);
    on<HomeImagesSearched>(_onImagesSearched);
    on<HomeSearchClosed>(_onSearchClosed);
  }

  Future<void> _onInitialized(
      HomeInitialized event, Emitter<HomeState> emit) async {
    try {
      final name = await _authService.getName();
      emit(state.copyWith(userName: name.isNotEmpty ? name : 'User'));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to load user data.'));
    }
  }

  Future<void> _onEventSearched(
      HomeEventSearched event, Emitter<HomeState> emit) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(isSearching: true, events: []));
      return;
    }
    emit(state.copyWith(isSearching: true, isLoadingEvents: true, events: []));
    try {
      final events = await _searchEventsUseCase(SearchEventsParams(event.query));
      emit(state.copyWith(isLoadingEvents: false, events: events));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoadingEvents: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoadingEvents: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoadingEvents: false, errorMessage: 'Failed to search events.'));
    }
  }

  Future<void> _onImagesSearched(
      HomeImagesSearched event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoadingImages: true, searchImages: [], clearError: true));
    try {
      final uniqueName = await _authService.getUniqueName();
      var images = await _searchImagesUseCase(
          SearchImagesParams(eventId: event.eventId, uniqueName: uniqueName));
      if (images.isEmpty) {
        images = await _searchImagesUseCase(
            SearchImagesParams(eventId: event.eventName, uniqueName: uniqueName));
      }
      emit(state.copyWith(isLoadingImages: false, searchImages: images));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoadingImages: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoadingImages: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoadingImages: false, errorMessage: 'Failed to load images.'));
    }
  }

  void _onSearchClosed(HomeSearchClosed event, Emitter<HomeState> emit) {
    emit(state.copyWith(isSearching: false, events: [], searchImages: []));
  }
}
