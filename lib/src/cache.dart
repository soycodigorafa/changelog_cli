import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_registry.dart';

/// Persists PR titles per tag to a JSON file so repeated runs don't have to
/// re-diff git history for tags whose PR diff never changes once the tag
/// exists. Pure file I/O — no git or business logic.
class ChangelogCache {
  ChangelogCache._(this._file, this._prTitlesByTag);

  final File _file;
  final Map<String, List<String>> _prTitlesByTag;
  bool _dirty = false;

  /// Chains every [save] call onto whichever save is already in flight, so
  /// concurrent callers (e.g. multiple sync workers) never write the file
  /// at the same time — each write still ends up reflecting every [put]
  /// that happened before its turn.
  Future<void> _saveChain = Future.value();

  static Future<ChangelogCache> load(File file) async {
    if (!await file.exists()) {
      return ChangelogCache._(file, {});
    }
    try {
      final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final map = decoded.map((key, value) => MapEntry(key, (value as List).cast<String>()));
      return ChangelogCache._(file, map);
    } catch (_) {
      // Corrupt/unreadable cache file: treat as empty rather than failing the run.
      return ChangelogCache._(file, {});
    }
  }

  List<String>? prTitlesFor(String rawTag) => _prTitlesByTag[rawTag];

  void put(String rawTag, List<String> prTitles) {
    _prTitlesByTag[rawTag] = prTitles;
    _dirty = true;
  }

  int get length => _prTitlesByTag.length;

  Future<void> save() {
    _saveChain = _saveChain.then((_) => _writeIfDirty());
    return _saveChain;
  }

  Future<void> _writeIfDirty() async {
    if (!_dirty) return;
    _dirty = false;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(_prTitlesByTag));
  }
}

/// `<cacheDir>/<folderName>.json` — one cache file per app.
File cacheFileFor(Directory cacheDir, AppEntry app) => File(p.join(cacheDir.path, '${app.folderName}.json'));

/// `<cacheDir>/last_full_sync.json` — one shared timestamp for "when did a
/// sync covering every app last complete", read by every TUI screen's
/// status line and written by both the CLI `sync` command and the TUI's
/// sync screen.
File lastFullSyncFile(Directory cacheDir) => File(p.join(cacheDir.path, 'last_full_sync.json'));

Future<void> recordFullSync(Directory cacheDir) async {
  final file = lastFullSyncFile(cacheDir);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode({'at': DateTime.now().toIso8601String()}));
}

/// `null` if a full sync has never completed (or the file is unreadable).
Future<DateTime?> readLastFullSyncAt(Directory cacheDir) async {
  final file = lastFullSyncFile(cacheDir);
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return DateTime.parse(decoded['at'] as String);
  } catch (_) {
    return null;
  }
}

/// `<cacheDir>/sync_stats.json` — how many tags (across every app) are
/// cached out of how many exist, as of the last sync attempt (whether it
/// completed or was canceled/paused-and-exited). Separate from
/// [lastFullSyncFile], which only ever means "a full run completed".
File syncStatsFile(Directory cacheDir) => File(p.join(cacheDir.path, 'sync_stats.json'));

class SyncStats {
  SyncStats({required this.cachedTags, required this.totalTags});

  final int cachedTags;
  final int totalTags;
}

Future<void> writeSyncStats(Directory cacheDir, {required int cachedTags, required int totalTags}) async {
  final file = syncStatsFile(cacheDir);
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode({'cachedTags': cachedTags, 'totalTags': totalTags}));
}

/// `null` if no sync has ever run (or the file is unreadable).
Future<SyncStats?> readSyncStats(Directory cacheDir) async {
  final file = syncStatsFile(cacheDir);
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return SyncStats(cachedTags: decoded['cachedTags'] as int, totalTags: decoded['totalTags'] as int);
  } catch (_) {
    return null;
  }
}
