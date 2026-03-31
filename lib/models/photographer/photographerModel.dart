class PhotographerModel {
  String id = "";
  String name = "";
  String email = "";
  String contact = "";
  String? imageUrl;
  double? rating;

  PhotographerModel(
    this.id,
    this.email,
    this.name,
    this.contact, {
    this.imageUrl,
    this.rating,
  });

  PhotographerModel.empty() {
    id = "";
    email = "";
    name = "";
    contact = "";
  }

  //deserialization
  factory PhotographerModel.fromJson(Map<String, dynamic> json) {
    return PhotographerModel(
      json["id"] as String,
      json["email"] as String,
      json["name"] as String,
      json["contact"] as String,
      imageUrl: json["imageUrl"] as String?,
      rating: (json["rating"] as num?)?.toDouble(),
    );
  }

  //serialization
  Map<String, dynamic> toJson() {
    var map = {
      "id": id,
      "email": email,
      "name": name,
      "contact": contact,
      if (imageUrl != null) "imageUrl": imageUrl,
      if (rating != null) "rating": rating,
    };
    return map;
  }

  @override
  String toString() {
    return "LoginResponseObject = [ id: $id, email: $email, contact: $contact, "
        "name: $name,]";
  }
}
