class LoginResponseObject {
  String id = "";
  String name = "";

  /// The public handle — `sarajohnson4821`, generated at signup.
  ///
  /// **Read from `username`, not from the response's `uniqueName`.** The login
  /// payload carries both, and they are different columns: `uniqueName` is
  /// `User.uiqueName`, the face-recognition person id, which for every account
  /// that did not sign up as a photographer *is their email address*.
  ///
  /// Taking that one put an email under the avatar, and worse, it is what the
  /// Edit Profile form prefilled its Username field with — so saving the form
  /// without touching that field sent an address to a field the API accepts
  /// only as `[A-Za-z0-9_]+`, and an untouched form could not be saved at all.
  String  uniqueName = "";
  String email = "";
  String role = "";
  String token = "";
  bool isValid = false;
  String expiration = "";
  /// False when the server has no E2EE key bundle for this user yet.
  /// The app must call POST /chat/keys/bundle before any DM can be encrypted.
  bool keyBundlePublished = false;

  /// True once the user has uploaded their face/reference photos. When false,
  /// the app nudges them to add photos (on login + every few days).
  bool hasAddedFaces = false;

  LoginResponseObject(this.id, this.email, this.name, this.role,
      this.uniqueName, this.token, this.expiration, this.isValid,
      {this.keyBundlePublished = false, this.hasAddedFaces = false});

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
    hasAddedFaces = false;
  }

  //deserialization
  factory LoginResponseObject.fromJson(Map<String, dynamic> json) {
    return LoginResponseObject(
      json["id"] as String,
      json["email"] as String,
      json["name"] as String,
      json["role"] as String,
      // `username` first; the rest are for a server from before that column,
      // and for the session JSON this used to write. See the field's note.
      (json["username"] ??
          json["uniqueName"] ??
          json["uiqueName"] ??
          "") as String,
      json["token"] as String,
      json["expiration"] as String,
      json["isValid"] as bool,
      keyBundlePublished: json["keyBundlePublished"] as bool? ?? false,
      hasAddedFaces: json["has_added_faces"] as bool? ?? false,
    );
  }

  //serialization
  Map<String, dynamic> toJson() {
    var map = {
      "id": id,
      "email": email,
      "name": name,
      "role": role,
      // Written under the name it is actually read back by. It used to be
      // `uiqueName` here while `fromJson` looked for `uniqueName`, so a
      // round-trip through this map silently lost the handle.
      "username":  uniqueName,
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
