import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import 'sync_status_line.dart';

class AppPicker extends StatefulComponent {
  const AppPicker({
    super.key,
    required this.apps,
    required this.lastFullSyncAt,
    required this.syncStats,
    required this.onSelected,
    required this.onSync,
  });

  final List<AppEntry> apps;
  final DateTime? lastFullSyncAt;
  final SyncStats? syncStats;
  final void Function(AppEntry app) onSelected;
  final void Function() onSync;

  @override
  State<AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<AppPicker> {
  int selectedIndex = 0;

  /// Row 0 is always `Sync all apps`; app entries follow, shifted by one.
  int get _optionCount => component.apps.length + 1;

  @override
  Component build(BuildContext context) {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
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
      },
      child: Container(
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select an app', style: TextStyle(fontWeight: FontWeight.bold)),
            buildSyncStatusLine(component.lastFullSyncAt, component.syncStats),
            const SizedBox(height: 1),
            Text(
              '${selectedIndex == 0 ? '> ' : '  '}Sync all apps',
              style: TextStyle(color: selectedIndex == 0 ? Colors.brightCyan : Colors.white),
            ),
            for (var i = 0; i < component.apps.length; i++)
              Text(
                '${i + 1 == selectedIndex ? '> ' : '  '}${component.apps[i].folderName}',
                style: TextStyle(color: i + 1 == selectedIndex ? Colors.brightCyan : Colors.white),
              ),
            const SizedBox(height: 1),
            const Text('↑/↓ move   Enter select   q quit', style: TextStyle(color: Colors.brightBlack)),
          ],
        ),
      ),
    );
  }
}
