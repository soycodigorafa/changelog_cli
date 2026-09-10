import 'package:nocterm/nocterm.dart';

import 'divider.dart';
import 'theme.dart';

/// Shared bordered-frame layout for every TUI screen: a padded, bordered
/// box with [header] on top, a divider, the [body] (often an [Expanded]
/// scroll area), another divider, then [footer].
class ScreenScaffold extends StatelessComponent {
  const ScreenScaffold({
    required this.header,
    required this.body,
    required this.footer,
    required this.onKeyEvent,
    super.key,
  });

  final Component header;
  final Component body;
  final Component footer;
  final KeyEventHandler onKeyEvent;

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: onKeyEvent,
      child: Container(
        decoration: BoxDecoration(border: BoxBorder.all(color: AppColors.border)),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const AppDivider(),
            body,
            const AppDivider(),
            footer,
          ],
        ),
      ),
    );
  }
}
