import 'package:nocterm/nocterm.dart';

/// A scrollable body that also supports click-drag text selection, copying
/// the selection to the system clipboard (via OSC 52) when the drag
/// completes.
class CopyableScrollBody extends StatelessComponent {
  const CopyableScrollBody({required this.controller, required this.children, super.key});

  final ScrollController controller;
  final List<Component> children;

  @override
  Component build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        controller: controller,
        child: SelectionArea(
          onSelectionCompleted: (text) {
            if (text.isNotEmpty) ClipboardManager.copy(text);
          },
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
