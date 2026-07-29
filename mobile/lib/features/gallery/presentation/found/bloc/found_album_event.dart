part of 'found_album_bloc.dart';

abstract class FoundAlbumEvent extends Equatable {
  const FoundAlbumEvent();
  @override
  List<Object?> get props => [];
}

/// Loads the album's photos; [loadMore] appends the next page instead of
/// reloading from page 1.
class FoundAlbumPhotosRequested extends FoundAlbumEvent {
  const FoundAlbumPhotosRequested({this.loadMore = false});

  final bool loadMore;

  @override
  List<Object?> get props => [loadMore];
}
