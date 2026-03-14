part of 'photographer_bloc.dart';

abstract class PhotographerEvent extends Equatable {
  const PhotographerEvent();
  @override
  List<Object?> get props => [];
}

class PhotographersLoadRequested extends PhotographerEvent {
  const PhotographersLoadRequested();
}

class PhotographersSearched extends PhotographerEvent {
  final String query;
  const PhotographersSearched(this.query);
  @override
  List<Object?> get props => [query];
}
