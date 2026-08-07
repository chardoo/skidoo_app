import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:jperg_app/models/photographer/photographer_event.dart';

class GetPhotographerEventsUseCase {
  final PhotographerRepository _repo;
  GetPhotographerEventsUseCase(this._repo);

  Future<PhotographerEventsResult> call({
    required String photographerId,
    required int page,
    required int limit,
  }) =>
      _repo.getPhotographerEvents(
        photographerId: photographerId,
        page: page,
        limit: limit,
      );
}
