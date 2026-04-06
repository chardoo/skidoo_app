part of 'home_bloc.dart';

class HomeState extends Equatable {
  final String userName;
  final List<Event> events;
  final List<Photo> searchImages;
  final bool isSearching;
  final bool isLoadingEvents;
  final bool isLoadingImages;
  final bool isSavingFree;
  final int? savedFreeCount;   // set after a successful save; null otherwise
  final String? errorMessage;

  const HomeState({
    this.userName = '',
    this.events = const [],
    this.searchImages = const [],
    this.isSearching = false,
    this.isLoadingEvents = false,
    this.isLoadingImages = false,
    this.isSavingFree = false,
    this.savedFreeCount,
    this.errorMessage,
  });

  HomeState copyWith({
    String? userName,
    List<Event>? events,
    List<Photo>? searchImages,
    bool? isSearching,
    bool? isLoadingEvents,
    bool? isLoadingImages,
    bool? isSavingFree,
    int? savedFreeCount,
    bool clearSavedCount = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      userName: userName ?? this.userName,
      events: events ?? this.events,
      searchImages: searchImages ?? this.searchImages,
      isSearching: isSearching ?? this.isSearching,
      isLoadingEvents: isLoadingEvents ?? this.isLoadingEvents,
      isLoadingImages: isLoadingImages ?? this.isLoadingImages,
      isSavingFree: isSavingFree ?? this.isSavingFree,
      savedFreeCount:
          clearSavedCount ? null : (savedFreeCount ?? this.savedFreeCount),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        userName,
        events,
        searchImages,
        isSearching,
        isLoadingEvents,
        isLoadingImages,
        isSavingFree,
        savedFreeCount,
        errorMessage,
      ];
}
