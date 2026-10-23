/// Stateless validators for user input. Return `null` on success, or a
/// user-facing error string on failure — the exact signature Flutter's
/// `TextFormField.validator` expects.
///
/// All regexes are compiled once as top-level constants, not recompiled per
/// call, and are scoped to Tanzania where applicable (Phase 0 decision).
class Validators {
  Validators._();

  // ─── Compiled patterns ───────────────────────────────────────────

  static final _email = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
  );

  /// Tanzania phone: accept `+255XXXXXXXXX`, `255XXXXXXXXX`, `0XXXXXXXXX`.
  /// Local mobile starts with 6 or 7 (M-Pesa/Tigo/Airtel range).
  static final _tzPhone = RegExp(
    r'^(?:\+?255|0)(?:6[1-9]|7[1-9])\d{7}$',
  );

  /// NIDA: exactly 20 digits.
  static final _nida = RegExp(r'^\d{20}$');

  /// Tanzania plate: 1–3 leading letters, 3 digits, 0–3 trailing letters.
  /// Covers both standard formats (`ABC123`, `ABC123D`) and the T-prefixed
  /// format (`T123ABC`). Case-insensitive.
  static final _plateTz = RegExp(
    r'^[A-Z]{1,3}\d{3}[A-Z]{0,3}$',
    caseSensitive: false,
  );
  // ─── Text ────────────────────────────────────────────────────────

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? minLength(String? value, int min, {String? label}) {
    final v = value?.trim() ?? '';
    if (v.length < min) {
      return '${label ?? 'This field'} must be at least $min characters.';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String? label}) {
    final v = value?.trim() ?? '';
    if (v.length > max) {
      return '${label ?? 'This field'} must be at most $max characters.';
    }
    return null;
  }

  // ─── Formats ─────────────────────────────────────────────────────

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    if (!_email.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    // Strip spaces and dashes for friendlier input.
    final normalized = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!_tzPhone.hasMatch(normalized)) {
      return 'Enter a valid Tanzania phone number (e.g. 0712 345 678).';
    }
    return null;
  }

  static String? nida(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIDA number is required.';
    }
    if (!_nida.hasMatch(value.trim())) {
      return 'NIDA number must be exactly 20 digits.';
    }
    return null;
  }

  static String? plateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Plate number is required.';
    }
    if (!_plateTz.hasMatch(value.trim())) {
      return 'Enter a valid plate number (e.g. ABC123 or T123ABC).';
    }
    return null;
  }

  // ─── Passwords ───────────────────────────────────────────────────

  static String? password(String? value, {int minLength = 8}) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value != original) {
      return 'Passwords do not match.';
    }
    return null;
  }
}