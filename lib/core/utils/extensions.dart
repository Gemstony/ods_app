import 'package:flutter/material.dart';

/// Small, focused extensions. Nothing here should grow into a framework —
/// keep each one obviously useful and named for exactly what it does.
extension StringX on String {
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => !isBlank;

  /// Capitalizes only the first character, leaving the rest alone.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Truncates to [max] characters and appends an ellipsis if cut.
  String truncated(int max) =>
      length <= max ? this : '${substring(0, max - 1)}…';
}

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);

  /// Convenience wrapper around the messenger, using the floating style
  /// already configured in `AppTheme`.
  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFDC2626) : null,
        ),
      );
  }
}

extension DateTimeX on DateTime {
  /// `2026-04-23` — used in audit trails and receipts.
  String get yyyyMmDd => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
