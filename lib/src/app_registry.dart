import 'dart:io';

import 'package:path/path.dart' as p;

class AppEntry {
  AppEntry({required this.folderName, required this.tagFormat, required this.displayName});

  /// The apps/<folderName> directory name, e.g. `zz_sample`.
  final String folderName;

  /// Tag-prefix form used inside git tags, e.g. `ZZ_Sample`. Matches the
  /// awk transform in scripts/generate-ir-tags.sh / generate-rc-tags.sh.
  final String tagFormat;

  /// Human-readable name for changelog headers; defaults to [tagFormat].
  final String displayName;
}

/// Converts an apps/ folder name (e.g. `zz_sample`) into the tag-prefix
/// form used by scripts/generate-ir-tags.sh / generate-rc-tags.sh (`ZZ_Sample`).
String tagFormatFor(String folderName) {
  final parts = folderName.split('_');
  final country = parts.first.toUpperCase();
  final rest = parts.skip(1).join('_');
  final name = rest.isEmpty ? '' : rest[0].toUpperCase() + rest.substring(1).toLowerCase();
  return name.isEmpty ? country : '${country}_$name';
}

/// Discovers apps by scanning `apps/*/version.yaml`, so newly added apps are
/// picked up without keeping a hardcoded list in sync (unlike the bash
/// scripts' `APPS=(...)` array).
List<AppEntry> discoverApps(String repoRoot) {
  final appsDir = Directory(p.join(repoRoot, 'apps'));
  if (!appsDir.existsSync()) {
    return const [];
  }
  final entries = <AppEntry>[];
  for (final entity in appsDir.listSync()) {
    if (entity is! Directory) continue;
    final folderName = p.basename(entity.path);
    final versionFile = File(p.join(entity.path, 'version.yaml'));
    if (!versionFile.existsSync()) continue;
    final tagFormat = tagFormatFor(folderName);
    entries.add(
      AppEntry(
        folderName: folderName,
        tagFormat: tagFormat,
        displayName: tagFormat,
      ),
    );
  }
  entries.sort((a, b) => a.folderName.compareTo(b.folderName));
  return entries;
}

AppEntry? findApp(List<AppEntry> apps, String folderName) {
  for (final app in apps) {
    if (app.folderName == folderName) return app;
  }
  return null;
}
