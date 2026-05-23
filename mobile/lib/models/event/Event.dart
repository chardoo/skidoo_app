/*
{
  id: "",
  eventName: "",
  imageId: "",
  url: "",
  price: "",
  eventDate: "",
  identification: "",
}
*/

class Event {
  final String id;
  final String eventName;
  final String eventDate;
  final String photographer;

  Event(this.id, this.eventName, this.eventDate, this.photographer);

  //deserialization
  factory Event.fromMap(Map<String, dynamic> json) {
    // Photographer name can come under different field names.
    final photographerName = json["userName"]
        ?? (json["user"] as Map<String, dynamic>?)?["name"]
        ?? json["photographerName"]
        ?? json["photographer"]
        ?? '';
    return Event(
      json["id"] as String? ?? '',
      json["eventName"] as String? ?? '',
      json["eventDate"] as String? ?? '',
      photographerName as String,
    );
  }
  Map<String, dynamic> toJson() => {
        "id": id,
        "eventName": eventName,
        "eventDate": eventDate,
        "photographer": photographer,
      };

  String geteventName() {
    return eventName;
  }

  // String dateskds() {
  //  DateTime dt =  DateTime.parse(eventDate);

  // }

  //serialization
  @override
  String toString() {
    return ' $eventName ';
  }
}
