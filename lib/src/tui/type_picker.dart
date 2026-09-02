import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../changelog.dart';
import '../git_client.dart';
import 'sync_status_line.dart';

class TypePicker extends StatefulComponent {
  const TypePicker({
    super.key,
    required this.app,
    required this.git,
    required this.lastFullSyncAt,
    required this.syncStats,
    required this.onSelected,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final DateTime? lastFullSyncAt;
  final SyncStats? syncStats;
  final void Function(String typeFilter) onSelected;
  final void Function() onBack;

  @override
  State<TypePicker> createState() => _TypePickerState();
}

class _TypePickerState extends State<TypePicker> {
  int selectedIndex = 0;
  List<String>? types;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tags = await loadTags(component.git, component.app);
      final distinct = tags.map((t) => t.type).toSet().toList()..sort();
      setState(() {
        types = ['All', 'Search', ...distinct];
      });
    } catch (e) {
      setState(() {
        error = '$e';
      });
    }
  }

  @override
  Component build(BuildContext context) {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(1),
        child: Text('Error loading tags for ${component.app.folderName}: $error',
            style: const TextStyle(color: Colors.brightRed)),
      );
    }
    final options = types;
    if (options == null) {
      return const Container(
        padding: EdgeInsets.all(1),
        child: Text('Loading tags...'),
      );
    }
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowDown) {
          setState(() {
            if (selectedIndex < options.length - 1) selectedIndex++;
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
          final selected = options[selectedIndex];
          if (selected == 'Search') {
            component.onSelected('__search__');
          } else {
            component.onSelected(selected == 'All' ? 'all' : selected);
          }
          return true;
        }
        if (event.logicalKey == LogicalKey.escape) {
          component.onBack();
          return true;
        }
        if (event.character == 's') {
          component.onSelected('__search__');
          return true;
        }
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${component.app.folderName} — select a tag type',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            buildSyncStatusLine(component.lastFullSyncAt, component.syncStats),
            const SizedBox(height: 1),
            for (var i = 0; i < options.length; i++)
              Text(
                '${i == selectedIndex ? '> ' : '  '}${options[i]}',
                style: TextStyle(color: i == selectedIndex ? Colors.brightCyan : Colors.white),
              ),
            const SizedBox(height: 1),
            const Text('↑/↓ move   Enter select   s search   Esc back', style: TextStyle(color: Colors.brightBlack)),
          ],
        ),
      ),
    );
  }
}
