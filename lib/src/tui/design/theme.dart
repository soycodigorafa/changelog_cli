import 'package:nocterm/nocterm.dart';

/// Shared color palette for the changelog_cli TUI. Every screen should pull
/// its colors from here instead of referencing `Colors.*` directly, so the
/// palette stays consistent and only needs to change in one place.
class AppColors {
  AppColors._();

  static const Color accent = Colors.brightCyan;
  static const Color primary = Colors.brightWhite;
  static const Color secondary = Colors.white;
  static const Color muted = Colors.brightBlack;
  static const Color success = Colors.brightGreen;
  static const Color danger = Colors.brightRed;
  static const Color warning = Colors.brightYellow;
  static const Color border = Colors.brightBlack;

  /// Background highlight for the selected row in a [SelectableRow] list,
  /// copied from wsrun_cli's `ConfigList`.
  static const Color selectedRowBg = Color.fromRGB(30, 50, 80);
}

/// Shared spacing constants for the changelog_cli TUI.
class AppSpacing {
  AppSpacing._();

  static const EdgeInsets screenPadding = EdgeInsets.all(1);
  static const SizedBox gap = SizedBox(height: 1);
}
