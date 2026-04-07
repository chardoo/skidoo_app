import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/cart/domain/usecases/save_images_free_usecase.dart';
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
  final SaveImagesForFreeUseCase _saveImagesFree;
  final AuthService _authService;

  HomeBloc({
    required SearchEventsUseCase searchEventsUseCase,
    required SearchImagesUseCase searchImagesUseCase,
    required SaveImagesForFreeUseCase saveImagesFree,
  })  : _searchEventsUseCase = searchEventsUseCase,
        _searchImagesUseCase = searchImagesUseCase,
        _saveImagesFree = saveImagesFree,
        _authService = sl<AuthService>(),
        super(const HomeState()) {
    on<HomeInitialized>(_onInitialized);
    on<HomeEventSearched>(_onEventSearched);
    // restartable: cancels the in-flight SSE stream when a new search starts.
    on<HomeImagesSearched>(_onImagesSearched, transformer: restartable());
    on<HomeSearchClosed>(_onSearchClosed);
    on<HomeFreeImagesSaved>(_onFreeImagesSaved);
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
      final email = await _authService.getEmail();
      final stream = _searchImagesUseCase(
          SearchImagesParams(eventId: event.eventId, email: email));
      await for (final photo in stream) {
        if (emit.isDone) return;
        // Emit each photo immediately so the grid renders it as it arrives.
        emit(state.copyWith(searchImages: [...state.searchImages, photo]));
        // Yield to the platform event queue so Flutter can render the new
        // photo before the next one is processed from the stream.
        await Future.delayed(Duration.zero);
        if (emit.isDone) return;
      }
      // Stream finished — clear the loading flag now.
      emit(state.copyWith(isLoadingImages: false));
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

  Future<void> _onFreeImagesSaved(
      HomeFreeImagesSaved event, Emitter<HomeState> emit) async {
    if (event.photos.isEmpty) return;
    emit(state.copyWith(
        isSavingFree: true, clearError: true, clearSavedCount: true));
    try {
      final clientId = await _authService.getUserId();
      await _saveImagesFree(event.photos, clientId: clientId);
      emit(state.copyWith(
          isSavingFree: false, savedFreeCount: event.photos.length));
    } on NetworkException {
      emit(state.copyWith(
          isSavingFree: false, errorMessage: 'No internet connection.'));
    } on ServerException catch (e) {
      emit(state.copyWith(isSavingFree: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
          isSavingFree: false, errorMessage: 'Failed to save images.'));
    }
  }
}
