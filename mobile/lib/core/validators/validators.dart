class Validators{
 static String? emailValidator(String? value) {
    final emailRegExp = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (value == null || value.isEmpty) {
      return '*Invalid email';
    }
    if (!emailRegExp.hasMatch(value.trim())) {
      return "*Invalid email";
    }

    return null;
  }


 static String? codeValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '*Invalid code';
    }
    if (value.trim().length < 3 ) {
      return '*Invalid code';
    }
    return null;
  }

   static String? reminderTitle(String? value) {
    if (value == null || value.isEmpty) {
      return '*is required';
    }
   
    return null;
  }

 static String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '*required ';
    }
    
    return null;
  }
 
 static String? nameValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '*Minimum 6 characters';
    }
    return null;
  }
 static String? phoneNumberValidator(String? value) {
    final emailRegExp = RegExp(
        r"^0[2,5]{1}[0-9]+$");
    if (value == null || value.isEmpty) {
      return '*Invalid number';
    }
    if (!emailRegExp.hasMatch(value.trim())) {
      return "*Invalid number";
    }

    return null;
  }

 
}