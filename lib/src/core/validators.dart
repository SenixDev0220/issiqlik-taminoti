/// Input validation and sanitization for security.
class Validators {
  Validators._();

  static const int loginMinLength = 3;
  static const int loginMaxLength = 30;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 64;
  static const int nameMaxLength = 50;

  static final _loginRegex = RegExp(r'^[a-zA-Z0-9._-]+$');
  static final _phoneRegex = RegExp(r'^\+?[\d\s\-()]{9,15}$');
  static final _hasUpperCase = RegExp(r'[A-Z]');
  static final _hasLowerCase = RegExp(r'[a-z]');
  static final _hasDigit = RegExp(r'\d');

  /// Sanitize text input — trim and remove control characters.
  static String sanitize(String input) {
    return input.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  /// Validate login format.
  static String? validateLogin(String? value) {
    if (value == null || value.trim().isEmpty) return 'Login bo\'sh bo\'lishi mumkin emas';
    final v = sanitize(value);
    if (v.length < loginMinLength) return 'Login kamida $loginMinLength ta belgi';
    if (v.length > loginMaxLength) return 'Login $loginMaxLength ta belgidan oshmasin';
    if (!_loginRegex.hasMatch(v)) return 'Faqat harf, raqam, nuqta, tire ruxsat';
    return null;
  }

  /// Validate password strength.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Parol bo\'sh bo\'lishi mumkin emas';
    if (value.length < passwordMinLength) return 'Parol kamida $passwordMinLength ta belgi';
    if (value.length > passwordMaxLength) return 'Parol juda uzun';
    if (!_hasUpperCase.hasMatch(value)) return 'Kamida 1 ta katta harf kerak';
    if (!_hasLowerCase.hasMatch(value)) return 'Kamida 1 ta kichik harf kerak';
    if (!_hasDigit.hasMatch(value)) return 'Kamida 1 ta raqam kerak';
    return null;
  }

  /// Validate name fields.
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bu maydon to\'ldirilishi shart';
    final v = sanitize(value);
    if (v.length > nameMaxLength) return 'Juda uzun';
    if (RegExp(r'[<>{}\\\/]').hasMatch(v)) return 'Noto\'g\'ri belgilar';
    return null;
  }

  /// Validate phone number.
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Bu maydon to\'ldirilishi shart';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 12) return 'Telefon raqami noto\'g\'ri';
    if (!_phoneRegex.hasMatch(value.trim())) return 'Telefon raqami noto\'g\'ri';
    return null;
  }
}
