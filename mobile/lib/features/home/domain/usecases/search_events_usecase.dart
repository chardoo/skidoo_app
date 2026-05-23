import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/home/domain/repositories/home_repository.dart';
import 'package:skidoo_app/models/event/Event.dart';

class SearchEventsUseCase implements UseCase<List<Event>, SearchEventsParams> {
  final HomeRepository _repository;
  SearchEventsUseCase(this._repository);

  @override
  Future<List<Event>> call(SearchEventsParams params) =>
      _repository.searchEvents(params.query);
}

class SearchEventsParams extends Equatable {
  final String query;
  const SearchEventsParams(this.query);
  @override
  List<Object?> get props => [query];
}
