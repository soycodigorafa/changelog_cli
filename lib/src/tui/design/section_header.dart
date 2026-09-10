import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// Bold section header text. Defaults to [AppColors.primary]; pass [color]
/// to reuse for other bold-headline variants (e.g. [PrTitleSection] passes
/// [AppColors.warning] for its tag headline).
class SectionHeader extends StatelessComponent {
  const SectionHeader(this.text, {this.color = AppColors.primary, super.key});

  final String text;
  final Color color;

  @override
  Component build(BuildContext context) {
    return Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color));
  }
}
