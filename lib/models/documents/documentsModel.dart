/*
{
  email: "",
  firstName: "",
  lastName: "",
  mobile: "",
  password: "",
  
}
*/

class Documents {
  final String documentURL;
  final String firstName;
  final String lastName;
  final String objectID;
  final String companyName;
  final bool isLater;
  final bool isViewed;
  final String createdTime;
  final String mime;

  Documents(this.documentURL, this.firstName, this.lastName, this.objectID,
      this.companyName, this.isLater, this.isViewed, this.createdTime, this.mime);

  //deserialization
  factory Documents.fromMap(Map<String, dynamic> json) {
    return Documents(
        json["documentURL"],
        json["firstName"],
        json["lastName"],
        json["objectID"],
        json["companyName"],
        json["isLater"],
        json["isViewed"],
        json["createdTime"],
        json["mime"]);
  }
  Map<String, dynamic> toJson() => {
        "documentURL": documentURL,
        "firstName": firstName,
        "lastName": lastName,
        "objectID": objectID,
        "companyName": companyName,
        "isLater": isLater,
        "isViewed": isViewed,
        "createdTime": createdTime,
         "mime": mime,
      };

  //serialization

  @override
  String toString() {
    return "{ documentURL: $documentURL, firstName: $firstName, lastName: $lastName, objectID: $objectID "
        "companyName: $companyName, isLater: $isLater, isViewed: $isViewed, createdTime: $createdTime, mime: $mime}";
  }
}
