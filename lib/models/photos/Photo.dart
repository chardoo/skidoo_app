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

class Photo {
  final String id;
  final String eventName;
  final String imageId;
  final String url;
  final String userId;
  final int price;
  final String eventDate;
  late String? identification;
  final bool isPublic;

  Photo(this.id, this.eventName, this.imageId, this.url, this.userId,
      this.price, this.eventDate, this.identification, this.isPublic);

  //deserialization
  factory Photo.fromMap(Map<String, dynamic> json) {
    return Photo(
      json["picture"]["id"],
     '',
      json["picture"]["imageId"],
      json["picture"]["url"],
      "   ",
      0,
      json["picture"]["eventDate"],
      json["picture"]["identification"],
      false,

    );
  }

  factory Photo.fromMap2(Map<String, dynamic> json) {
    print("hello how are  you doing the");
    print(json['event']);
    return Photo(
      json["id"],
      json["event"]["eventName"],
      json["imageId"],
      json["url"],
      json['event']["userId"],
      int.parse(json["price"]),
      json["event"]["eventDate"],
      json["identification"],
      json['public']
    );
  }
  Map<String, dynamic> toJson() => {
        "id": id,
        "eventName": eventName,
        "imageId": imageId,
        "url": url,
        "userId": userId,
        "price": price,
        "eventDate": eventDate,
        "identification": identification,
      };

  //serialization
  @override
  String toString() {
    return "{ id: $id, eventName: $eventName, imageId: $imageId, url: $url,userId: $userId"
        "price: $price, eventDate: $eventDate, identification: $identification}";
  }
}
