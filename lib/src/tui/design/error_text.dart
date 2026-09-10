import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// A single error message line, styled in [AppColors.danger].
class ErrorText extends StatelessComponent {
  const ErrorText(this.message, {super.key});

  final String message;

  @override
  Component build(BuildContext context) {
    return Text(message, style: const TextStyle(color: AppColors.danger));
  }
}
