class Validators {
  static String? emailValidator(String? value) {
    final emailRegExp = RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+\-/=?^_`{|}~]+@[a-zA-Z0-9-]+\.[a-zA-Z.]+$");
    if (value == null || value.trim().isEmpty) {
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
    if (value.trim().length < 3) {
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

  /// Stronger password rule for sign-up. Login keeps [passwordValidator] so
  /// existing accounts with shorter passwords can still sign in.
  static String? signupPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return '*Password is required';
    }
    if (value.length < 6) {
      return '*Minimum 6 characters';
    }
    return null;
  }

  static String? nameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '*Required';
    }
    if (value.trim().length < 2) {
      return '*Name is too short';
    }
    return null;
  }

  static String? phoneNumberValidator(String? value) {
    final phoneRegExp = RegExp(r"^0[2,5]{1}[0-9]+$");
    if (value == null || value.isEmpty) {
      return '*Invalid number';
    }
    if (!phoneRegExp.hasMatch(value.trim())) {
      return "*Invalid number";
    }

    return null;
  }

  // ── Reusable, composable validators ──────────────────────────────────────

  /// Requires a non-empty value. [field] customises the message.
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '*$field is required';
    }
    return null;
  }

  /// Rejects values longer than [max] characters. Empty values pass — combine
  /// with [required] when the field is mandatory.
  static String? maxLength(String? value, int max, {String field = 'This field'}) {
    if (value != null && value.trim().length > max) {
      return '*$field must be $max characters or fewer';
    }
    return null;
  }

  /// Requires a non-empty value within [min]..[max] characters.
  static String? lengthBetween(
    String? value,
    int min,
    int max, {
    String field = 'This field',
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '*$field is required';
    if (trimmed.length < min) return '*$field must be at least $min characters';
    if (trimmed.length > max) return '*$field must be $max characters or fewer';
    return null;
  }

  /// Required positive amount (money/quantity). Rejects non-numbers and ≤ 0.
  static String? amount(String? value, {String field = 'Amount'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '*$field is required';
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return '*Enter a valid $field';
    if (parsed <= 0) return '*$field must be greater than 0';
    return null;
  }

  /// Optional positive amount — blank is allowed, but if present it must be a
  /// valid number greater than 0.
  static String? optionalAmount(String? value, {String field = 'Amount'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final parsed = double.tryParse(trimmed);
    if (parsed == null) return '*Enter a valid $field';
    if (parsed <= 0) return '*$field must be greater than 0';
    return null;
  }

  /// Validates an http(s) URL. When [isRequired] is false, blank passes.
  static String? url(String? value, {bool isRequired = true, String field = 'Link'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return isRequired ? '*$field is required' : null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority) {
      return '*$field must be a valid URL (https://…)';
    }
    return null;
  }
}
