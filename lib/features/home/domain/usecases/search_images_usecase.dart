import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/home/domain/repositories/home_repository.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class SearchImagesUseCase
    implements UseCase<List<Photo>, SearchImagesParams> {
  final HomeRepository _repository;
  SearchImagesUseCase(this._repository);

  @override
  Future<List<Photo>> call(SearchImagesParams params) =>
      _repository.searchEventImages(params.eventId, params.uniqueName);
}

class SearchImagesParams extends Equatable {
  final String eventId;
  final String uniqueName;
  const SearchImagesParams({required this.eventId, required this.uniqueName});
  @override
  List<Object?> get props => [eventId, uniqueName];
}
