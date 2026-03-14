part of 'photographer_bloc.dart';

class PhotographerState extends Equatable {
  final bool isLoading;
  final List<PhotographerModel> photographers;
  final String? errorMessage;

  const PhotographerState({
    this.isLoading = false,
    this.photographers = const [],
    this.errorMessage,
  });

  PhotographerState copyWith({
    bool? isLoading,
    List<PhotographerModel>? photographers,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PhotographerState(
      isLoading: isLoading ?? this.isLoading,
      photographers: photographers ?? this.photographers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, photographers, errorMessage];
}
