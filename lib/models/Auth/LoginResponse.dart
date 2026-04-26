class LoginResponseObject {
  String id = "";
  String name = "";
  String  uniqueName = "";
  String email = "";
  String role = "";
  String token = "";
  bool isValid = false;
  String expiration = "";
  /// False when the server has no E2EE key bundle for this user yet.
  /// The app must call POST /chat/keys/bundle before any DM can be encrypted.
  bool keyBundlePublished = false;

  LoginResponseObject(this.id, this.email, this.name, this.role,
      this.uniqueName, this.token, this.expiration, this.isValid,
      {this.keyBundlePublished = false});

  LoginResponseObject.empty() {
    id = "";
    email = "";
    name = "";
    role = "";
    uniqueName = "";
    token = "";
    expiration = "";
    isValid = false;
    keyBundlePublished = false;
  }

  //deserialization
  factory LoginResponseObject.fromJson(Map<String, dynamic> json) {
    return LoginResponseObject(
      json["id"] as String,
      json["email"] as String,
      json["name"] as String,
      json["role"] as String,
      json["uniqueName"] as String,
      json["token"] as String,
      json["expiration"] as String,
      json["isValid"] as bool,
      keyBundlePublished: json["keyBundlePublished"] as bool? ?? false,
    );
  }

  //serialization
  Map<String, dynamic> toJson() {
    var map = {
      "id": id,
      "email": email,
      "name": name,
      "role": role,
      "uiqueName":  uniqueName,
      "token": token,
      "expiration": expiration,
      "isValid": isValid,
    };
    return map;
  }

  @override
  String toString() {
    return "LoginResponseObject = [ id: $id, email: $email, role: $role, token: $token "
        "name: $name, uniqueName : $uniqueName , expiration: $expiration, isValid: $isValid]";
  }
}
