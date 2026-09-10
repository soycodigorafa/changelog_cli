import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// One row in a keyboard-navigable list: a `❯ ` prefix and highlighted
/// background when [selected], plain text otherwise. Mirrors wsrun_cli's
/// `ConfigList` row rendering.
class SelectableRow extends StatelessComponent {
  const SelectableRow({required this.label, required this.selected, super.key});

  final String label;
  final bool selected;

  @override
  Component build(BuildContext context) {
    return Container(
      decoration: selected ? const BoxDecoration(color: AppColors.selectedRowBg) : null,
      child: Row(
        children: [
          Text(selected ? '❯ ' : '  ', style: const TextStyle(color: AppColors.accent)),
          Expanded(
            child: Text(
              label,
              style: selected
                  ? const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
                  : const TextStyle(color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}
