import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// A 1-row horizontal rule used to separate a screen's header/body/footer.
class AppDivider extends StatelessComponent {
  const AppDivider({super.key});

  @override
  Component build(BuildContext context) {
    return const Container(
      decoration: BoxDecoration(
        border: BoxBorder(bottom: BorderSide(color: AppColors.border)),
      ),
    );
  }
}
