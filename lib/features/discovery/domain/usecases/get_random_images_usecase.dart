import 'package:skidoo_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class GetRandomImagesUseCase {
  final DiscoveryRepository _repository;
  GetRandomImagesUseCase(this._repository);

  Future<List<EventDiscovery>> call({
    required int take,
    required int skip,
    String? userId,
    List<String>? followedPhotographerIds,
  }) =>
      _repository.getRandomEvents(
        take: take,
        skip: skip,
        userId: userId,
        followedPhotographerIds: followedPhotographerIds,
      );
}
