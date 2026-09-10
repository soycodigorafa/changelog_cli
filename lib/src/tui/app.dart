import 'dart:io';

import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../git_client.dart';
import '../version.dart';
import 'app_picker.dart';
import 'changelog_view.dart';
import 'search_view.dart';
import 'sync_view.dart';
import 'type_picker.dart';

/// Root of the interactive TUI: a screen stack (app -> type -> changelog,
/// or app -> sync) held as plain state, no [Navigator] — simple enough not
/// to need it. Also owns the one shared "last full sync" timestamp so every
/// screen can show the same sync-status line.
class ChangelogTuiRoot extends StatefulComponent {
  const ChangelogTuiRoot({super.key, required this.apps, required this.git, required this.cacheDir});

  final List<AppEntry> apps;
  final GitClient git;
  final Directory cacheDir;

  @override
  State<ChangelogTuiRoot> createState() => _ChangelogTuiRootState();
}

class _ChangelogTuiRootState extends State<ChangelogTuiRoot> {
  AppEntry? selectedApp;
  String? selectedType;
  bool syncing = false;
  DateTime? lastFullSyncAt;

  @override
  void initState() {
    super.initState();
    _reloadSyncStatus();
  }

  Future<void> _reloadSyncStatus() async {
    final at = await readLastFullSyncAt(component.cacheDir);
    setState(() {
      lastFullSyncAt = at;
    });
  }

  @override
  Component build(BuildContext context) {
    if (syncing) {
      return SyncView(
        apps: component.apps,
        git: component.git,
        cacheDir: component.cacheDir,
        onDone: () {
          setState(() => syncing = false);
          _reloadSyncStatus();
        },
      );
    }
    if (selectedApp == null) {
      return AppPicker(
        apps: component.apps,
        lastFullSyncAt: lastFullSyncAt,
        onSelected: (app) => setState(() => selectedApp = app),
        onSync: () => setState(() => syncing = true),
      );
    }
    if (selectedType == null) {
      return TypePicker(
        app: selectedApp!,
        git: component.git,
        lastFullSyncAt: lastFullSyncAt,
        onSelected: (type) => setState(() => selectedType = type),
        onBack: () => setState(() => selectedApp = null),
      );
    }
    if (selectedType == '__search__') {
      return SearchView(
        app: selectedApp!,
        git: component.git,
        cacheDir: component.cacheDir,
        lastFullSyncAt: lastFullSyncAt,
        onBack: () => setState(() => selectedType = null),
      );
    }
    return ChangelogView(
      app: selectedApp!,
      git: component.git,
      typeFilter: selectedType!,
      cacheDir: component.cacheDir,
      lastFullSyncAt: lastFullSyncAt,
      onBack: () => setState(() => selectedType = null),
    );
  }
}

Future<void> runChangelogTui(List<AppEntry> apps, GitClient git, Directory cacheDir) {
  return runApp(
    NoctermApp(
      title: 'changelog v$appVersion',
      child: ChangelogTuiRoot(apps: apps, git: git, cacheDir: cacheDir),
    ),
  );
}
