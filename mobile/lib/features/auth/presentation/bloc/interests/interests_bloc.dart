import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/features/auth/domain/usecases/pending_interests_usecases.dart';
import 'package:jperg_app/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:jperg_app/services/auth_service.dart';

part 'interests_event.dart';
part 'interests_state.dart';

class InterestsBloc extends Bloc<InterestsEvent, InterestsState> {
  final UpdateProfileUseCase _updateProfile;
  final ClearPendingInterestsUseCase _clearPendingInterests;
  final AuthService _authService;

  InterestsBloc({
    required UpdateProfileUseCase updateProfileUseCase,
    required ClearPendingInterestsUseCase clearPendingInterests,
    required AuthService authService,
  })  : _updateProfile = updateProfileUseCase,
        _clearPendingInterests = clearPendingInterests,
        _authService = authService,
        super(const InterestsState()) {
    on<InterestToggled>(_onInterestToggled);
    on<InterestsSubmitted>(_onInterestsSubmitted);
  }

  void _onInterestToggled(
      InterestToggled event, Emitter<InterestsState> emit) {
    final updated = Set<String>.from(state.selected);
    if (updated.contains(event.interest)) {
      updated.remove(event.interest);
    } else {
      updated.add(event.interest);
    }
    emit(state.copyWith(selected: updated));
  }

  Future<void> _onInterestsSubmitted(
      InterestsSubmitted event, Emitter<InterestsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final clientId = await _authService.getUserId();
      await _updateProfile(UpdateProfileParams(
        clientId: clientId,
        data: {'interest_tags': state.selected.toList()},
      ));
      await _clearPendingInterests();
      emit(state.copyWith(isLoading: false, isSuccess: true));
    } on NetworkException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to save interests. Please try again.'));
    }
  }
}
