/*
{
  email: "",
  firstName: "",
  lastName: "",
  mobile: "",
  password: "",
  
}
*/

class MimeTypeModel {
  final String name;

  MimeTypeModel(this.name);

  //deserialization
  factory MimeTypeModel.fromMap(Map<String, dynamic> json) {
    return MimeTypeModel(json["mime"]);
  }
  Map<String, dynamic> toJson() => {
        "name": name,
      };

  @override
  String toString() {
    return "{ name: $name}";
  }
}
