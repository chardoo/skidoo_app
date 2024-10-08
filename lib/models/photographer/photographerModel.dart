class PhotographerModel {
  String id = "";
  String name = "";
  String email = "";
  String contact = "";


  PhotographerModel(this.id, this.email, this.name, this.contact,
    );

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
    );
  }

  //serialization
  Map<String, dynamic> toJson() {
    var map = {
      "id": id,
      "email": email,
      "name": name,
      "contact": contact,
    };
    return map;
  }

  @override
  String toString() {
    return "LoginResponseObject = [ id: $id, email: $email, contact: $contact, "
        "name: $name,]";
  }
}
