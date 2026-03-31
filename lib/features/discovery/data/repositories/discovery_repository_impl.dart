import 'package:skidoo_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:skidoo_app/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class DiscoveryRepositoryImpl implements DiscoveryRepository {
  final DiscoveryRemoteDataSource _dataSource;
  DiscoveryRepositoryImpl(this._dataSource);

  @override
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    String? userId,
  }) =>
      _dataSource.getRandomEvents(take: take, userId: userId);
}
