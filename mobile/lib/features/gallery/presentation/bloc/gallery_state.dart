part of 'gallery_bloc.dart';

class GalleryState extends Equatable {
  final bool isLoading;
  final List<Photo> photos;
  final String? errorMessage;

  const GalleryState({
    this.isLoading = false,
    this.photos = const [],
    this.errorMessage,
  });

  GalleryState copyWith({
    bool? isLoading,
    List<Photo>? photos,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GalleryState(
      isLoading: isLoading ?? this.isLoading,
      photos: photos ?? this.photos,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, photos, errorMessage];
}
