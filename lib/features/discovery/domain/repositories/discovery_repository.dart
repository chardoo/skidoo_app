import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

abstract class DiscoveryRepository {
  Future<List<EventDiscovery>> getRandomEvents({
    required int take,
    String? userId,
  });
}
