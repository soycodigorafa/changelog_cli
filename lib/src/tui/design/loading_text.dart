import 'package:nocterm/nocterm.dart';

/// A plain status line for in-progress states (e.g. `Loading tags...`).
class LoadingText extends StatelessComponent {
  const LoadingText(this.label, {super.key});

  final String label;

  @override
  Component build(BuildContext context) => Text(label);
}
