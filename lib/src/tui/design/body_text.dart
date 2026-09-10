import 'package:nocterm/nocterm.dart';

/// A plain, unstyled content line (sync results, status text, "no match"
/// messages, etc.) — the design-system equivalent of a bare `Text(...)`
/// for content that doesn't need any special styling.
class BodyText extends StatelessComponent {
  const BodyText(this.text, {super.key});

  final String text;

  @override
  Component build(BuildContext context) => Text(text);
}
