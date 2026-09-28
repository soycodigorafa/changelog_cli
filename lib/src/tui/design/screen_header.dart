import 'package:nocterm/nocterm.dart';

import 'section_header.dart';

/// The title line shown at the top of every screen, with an optional second
/// line injected below it — e.g. [StatusLine] on the app picker, or a query
/// summary on the search-results screen. Centralizes that title+extra
/// composition so screens compose one shared widget instead of each
/// hand-rolling their own header `Column`.
class ScreenHeader extends StatelessComponent {
  const ScreenHeader({required this.title, this.extra, super.key});

  final String title;
  final Component? extra;

  @override
  Component build(BuildContext context) {
    final injected = extra;
    if (injected == null) return SectionHeader(title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionHeader(title), injected],
    );
  }
}
