class EventPicture {
  final String id;
  final String url;
  final String imageId;
  final int price;

  const EventPicture({
    required this.id,
    required this.url,
    required this.imageId,
    required this.price,
  });

  factory EventPicture.fromMap(Map<String, dynamic> json) {
    return EventPicture(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }
}

class EventDiscovery {
  final String id;
  final String eventName;
  final String photographerName;
  final String photographerId;
  final List<EventPicture> pictures;

  const EventDiscovery({
    required this.id,
    required this.eventName,
    required this.photographerName,
    required this.photographerId,
    required this.pictures,
  });

  factory EventDiscovery.fromMap(Map<String, dynamic> json) {
    final event = json['event'] as Map<String, dynamic>;
    final user = (event['user'] as Map<String, dynamic>?) ?? {};
    final pics = (event['pictures'] as List<dynamic>? ?? [])
        .map((p) => EventPicture.fromMap(p as Map<String, dynamic>))
        .toList();
    return EventDiscovery(
      id: event['id']?.toString() ?? '',
      eventName: event['eventName']?.toString() ?? '',
      photographerName: user['name']?.toString() ?? '',
      photographerId: user['id']?.toString() ?? '',
      pictures: pics,
    );
  }
}
