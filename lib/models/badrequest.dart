/*
{
  email: "",
  firstName: "",
  lastName: "",
  mobile: "",
  password: "",
  
}
*/

class BadRequest {
  late String status;
  late String message;
  BadRequest(this.status, this.message);

  //deserialization
  factory BadRequest.fromMap(Map<String, dynamic> json) {

    return BadRequest(json["status"], json['data'][0]['message']);
  }

  @override
  String toString() {
    return "{ status: $status  message: $message}";
  }
}
