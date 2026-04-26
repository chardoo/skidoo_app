part of 'interests_bloc.dart';

class InterestsState extends Equatable {
  final Set<String> selected;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const InterestsState({
    this.selected = const {},
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  InterestsState copyWith({
    Set<String>? selected,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return InterestsState(
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [selected, isLoading, errorMessage, isSuccess];
}
