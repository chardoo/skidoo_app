import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';

class SearchPhotographersUseCase
    implements UseCase<List<PhotographerModel>, SearchPhotographersParams> {
  final PhotographerRepository _repository;
  SearchPhotographersUseCase(this._repository);

  @override
  Future<List<PhotographerModel>> call(SearchPhotographersParams params) =>
      _repository.searchPhotographers(params.query);
}

class SearchPhotographersParams extends Equatable {
  final String query;
  const SearchPhotographersParams(this.query);
  @override
  List<Object?> get props => [query];
}
