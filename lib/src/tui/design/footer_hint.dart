import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// Dim help-hint line, shown at the top or bottom of a screen (e.g.
/// `↑/↓ move   Enter select   q quit`).
class FooterHint extends StatelessComponent {
  const FooterHint(this.text, {super.key});

  final String text;

  @override
  Component build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.muted));
  }
}
