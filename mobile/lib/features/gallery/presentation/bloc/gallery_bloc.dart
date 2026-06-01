import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/utils/gallery_refresh_signal.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_gallery_usecase.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'gallery_event.dart';
part 'gallery_state.dart';

class GalleryBloc extends Bloc<GalleryEvent, GalleryState> {
  final GetGalleryUseCase _getGalleryUseCase;
  final AuthService _authService;

  GalleryBloc({required GetGalleryUseCase getGalleryUseCase})
      : _getGalleryUseCase = getGalleryUseCase,
        _authService = sl<AuthService>(),
        super(const GalleryState()) {
    on<GalleryLoadRequested>(_onLoadRequested);
    // Reload when a purchase / free-save adds photos elsewhere in the app.
    GalleryRefreshSignal.revision.addListener(_onRefreshSignal);
  }

  void _onRefreshSignal() {
    if (!isClosed) add(const GalleryLoadRequested());
  }

  @override
  Future<void> close() {
    GalleryRefreshSignal.revision.removeListener(_onRefreshSignal);
    return super.close();
  }

  Future<void> _onLoadRequested(
      GalleryLoadRequested event, Emitter<GalleryState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final clientId = await _authService.getUserId();
      if (clientId.isEmpty) {
        emit(state.copyWith(
            isLoading: false, errorMessage: 'User not authenticated.'));
        return;
      }
      final photos =
          await _getGalleryUseCase(GetGalleryParams(clientId));
      emit(state.copyWith(isLoading: false, photos: photos));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Failed to load gallery.'));
    }
  }
}
