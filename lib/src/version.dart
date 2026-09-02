import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads this package's own `version:` field straight from its
/// `pubspec.yaml`, located relative to this script's own file. Only
/// reliable under `dart run` — it depends on the source tree (including
/// `pubspec.yaml`) still being on disk next to `bin/`, which holds for how
/// this tool is actually run, but would break under `dart compile exe`
/// (a standalone binary doesn't carry `pubspec.yaml` with it).
String readAppVersion() {
  final scriptFile = File(Platform.script.toFilePath());
  final packageRoot = scriptFile.parent.parent; // bin/<script>.dart -> package root
  final pubspecFile = File(p.join(packageRoot.path, 'pubspec.yaml'));
  final content = pubspecFile.readAsStringSync();
  final match = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
  return match?.group(1)?.trim() ?? 'unknown';
}
