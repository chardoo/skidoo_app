class PhotographerEvent {
  final String id;
  final String eventName;
  final String eventDate;
  final String url;

  const PhotographerEvent({
    required this.id,
    required this.eventName,
    required this.eventDate,
    required this.url,
  });

  factory PhotographerEvent.fromJson(Map<String, dynamic> json) {
    return PhotographerEvent(
      id: json['id']?.toString() ?? '',
      eventName: json['eventName']?.toString() ?? '',
      eventDate: json['eventDate']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class PhotographerEventsResult {
  final List<PhotographerEvent> events;
  final bool hasNext;

  const PhotographerEventsResult({required this.events, required this.hasNext});
}
