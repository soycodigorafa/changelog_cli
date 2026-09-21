import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../changelog.dart';
import '../git_client.dart';
import 'design/design.dart';

class TypePicker extends StatefulComponent {
  const TypePicker({
    super.key,
    required this.app,
    required this.git,
    required this.lastFullSyncAt,
    required this.onSelected,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final DateTime? lastFullSyncAt;
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
        types = ['All', 'Search', 'Upcoming', ...distinct];
      });
    } catch (e) {
      setState(() {
        error = '$e';
      });
    }
  }

  bool _onKeyEvent(KeyboardEvent event) {
    final options = types!;
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
      } else if (selected == 'Upcoming') {
        component.onSelected('__upcoming__');
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
    if (event.character == 'u') {
      component.onSelected('__upcoming__');
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    if (error != null) {
      return ScreenScaffold(
        onKeyEvent: (_) => false,
        header: const SectionHeader('Select a tag type'),
        body: ErrorText('Error loading tags for ${component.app.folderName}: $error'),
        footer: const FooterHint(''),
      );
    }
    final options = types;
    if (options == null) {
      return ScreenScaffold(
        onKeyEvent: (_) => false,
        header: const SectionHeader('Select a tag type'),
        body: const LoadingText('Loading tags...'),
        footer: const FooterHint(''),
      );
    }
    return ScreenScaffold(
      onKeyEvent: _onKeyEvent,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('${component.app.folderName} — select a tag type'),
          StatusLine(lastFullSyncAt: component.lastFullSyncAt),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++)
            SelectableRow(label: options[i], selected: i == selectedIndex),
        ],
      ),
      footer: const FooterHint('↑/↓ move   Enter select   s search   u upcoming   Esc back'),
    );
  }
}
