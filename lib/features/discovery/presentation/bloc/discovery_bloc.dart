import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'discovery_event.dart';
part 'discovery_state.dart';

const _pageSize = 10;

class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final GetRandomImagesUseCase _getRandomImagesUseCase;
  final AuthService _authService;

  DiscoveryBloc({required GetRandomImagesUseCase getRandomImagesUseCase})
      : _getRandomImagesUseCase = getRandomImagesUseCase,
        _authService = sl<AuthService>(),
        super(const DiscoveryState()) {
    on<DiscoveryLoadRequested>(_onLoadRequested);
    on<DiscoveryLoadMoreRequested>(_onLoadMoreRequested);
  }

  Future<String?> _getUserId() async {
    try {
      final id = await _authService.getUserId();
      return id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _onLoadRequested(
      DiscoveryLoadRequested event, Emitter<DiscoveryState> emit) async {
    emit(const DiscoveryState(isLoading: true));
    try {
      final userId = await _getUserId();
      final events = await _getRandomImagesUseCase(
        take: _pageSize,
        userId: userId,
      );
      emit(DiscoveryState(events: events));
    } on NetworkException catch (e) {
      emit(DiscoveryState(errorMessage: e.message));
    } on ServerException catch (e) {
      emit(DiscoveryState(errorMessage: e.message));
    } catch (_) {
      emit(const DiscoveryState(errorMessage: 'Failed to load events.'));
    }
  }

  Future<void> _onLoadMoreRequested(
      DiscoveryLoadMoreRequested event, Emitter<DiscoveryState> emit) async {
    if (state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final userId = await _getUserId();
      // API returns random images — each call gives a fresh batch to append.
      final more = await _getRandomImagesUseCase(
        take: _pageSize,
        userId: userId,
      );
      emit(state.copyWith(
        isLoadingMore: false,
        events: [...state.events, ...more],
      ));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
          isLoadingMore: false, errorMessage: 'Failed to load more.'));
    }
  }
}
