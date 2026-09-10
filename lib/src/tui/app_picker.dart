import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import 'design/design.dart';

class AppPicker extends StatefulComponent {
  const AppPicker({
    super.key,
    required this.apps,
    required this.lastFullSyncAt,
    required this.onSelected,
    required this.onSync,
  });

  final List<AppEntry> apps;
  final DateTime? lastFullSyncAt;
  final void Function(AppEntry app) onSelected;
  final void Function() onSync;

  @override
  State<AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<AppPicker> {
  int selectedIndex = 0;

  /// Row 0 is always `Sync all apps`; app entries follow, shifted by one.
  int get _optionCount => component.apps.length + 1;

  bool _onKeyEvent(KeyboardEvent event) {
    if (event.logicalKey == LogicalKey.arrowDown) {
      setState(() {
        if (selectedIndex < _optionCount - 1) selectedIndex++;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      setState(() {
        if (selectedIndex > 0) selectedIndex--;
      });
      return true;
    }
    if (event.logicalKey == LogicalKey.enter) {
      if (selectedIndex == 0) {
        component.onSync();
      } else if (component.apps.isNotEmpty) {
        component.onSelected(component.apps[selectedIndex - 1]);
      }
      return true;
    }
    if (event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    return ScreenScaffold(
      onKeyEvent: _onKeyEvent,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Select an app'),
          StatusLine(lastFullSyncAt: component.lastFullSyncAt),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableRow(label: 'Sync all apps', selected: selectedIndex == 0),
          for (var i = 0; i < component.apps.length; i++)
            SelectableRow(label: component.apps[i].folderName, selected: i + 1 == selectedIndex),
        ],
      ),
      footer: const FooterHint('↑/↓ move   Enter select   q quit'),
    );
  }
}
