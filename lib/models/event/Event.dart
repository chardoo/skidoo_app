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
    print(json);
    return Event(
      json["id"],
      json["eventName"],
      json["eventDate"],
      json["user"]["name"],
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
