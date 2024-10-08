/*
{
  email: "",
  firstName: "",
  lastName: "",
  mobile: "",
  password: "",
  
}
*/

class Registration {
  String email = "";
  String firstName = "";
  String lastName = "";
  String mobile = "";
  String password = "";

  Registration(
      this.email, this.firstName, this.lastName, this.mobile, this.password);

  Registration.empty() {
    email = "";
    firstName = "";
    lastName = "";
    mobile = "";
    password = "";
  }

  //deserialization
  factory Registration.fromJson(Map<String, dynamic> json) {
    return Registration(
      json["email"] as String,
      json["firstName"] as String,
      json["lastName"] as String,
      json["mobile"] as String,
      json["password"] as String,
    );
  }

  //serialization
  Map<String, dynamic> toJson() {
    var map = {
      "email": email,
      "firstName": firstName,
      "lastName": lastName,
      "mobile": mobile,
      "password": password,
    };
    return map;
  }

  @override
  String toString() {
    return "registration = { email: $email, firstName: $firstName, lastName: $lastName, mobile: $mobile "
        "password: $password}";
  }
}
