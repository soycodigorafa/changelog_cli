import 'dart:io';

import 'package:changelog_cli/src/cache.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('changelog_cache_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('load from a missing file returns an empty cache', () async {
    final cache = await ChangelogCache.load(File('${tempDir.path}/missing.json'));
    expect(cache.length, 0);
    expect(cache.prTitlesFor('some-tag'), isNull);
  });

  test('put + save + reload round-trips', () async {
    final file = File('${tempDir.path}/app.json');
    final cache = await ChangelogCache.load(file);
    cache.put('RC_App_v1.0.0', ['WR-1 first (#1)', 'WR-2 second (#2)']);
    await cache.save();

    expect(await file.exists(), isTrue);

    final reloaded = await ChangelogCache.load(file);
    expect(reloaded.prTitlesFor('RC_App_v1.0.0'), ['WR-1 first (#1)', 'WR-2 second (#2)']);
    expect(reloaded.length, 1);
  });

  test('save is a no-op when nothing changed', () async {
    final file = File('${tempDir.path}/app.json');
    final cache = await ChangelogCache.load(file);
    await cache.save();

    expect(await file.exists(), isFalse);
  });

  test('a corrupt cache file is treated as empty instead of throwing', () async {
    final file = File('${tempDir.path}/corrupt.json')..writeAsStringSync('not json');
    final cache = await ChangelogCache.load(file);
    expect(cache.length, 0);
  });

  test('readLastFullSyncAt returns null when a sync has never run', () async {
    expect(await readLastFullSyncAt(tempDir), isNull);
  });

  test('recordFullSync + readLastFullSyncAt round-trips a recent timestamp', () async {
    final before = DateTime.now();
    await recordFullSync(tempDir);
    final at = await readLastFullSyncAt(tempDir);

    expect(at, isNotNull);
    expect(at!.isAfter(before.subtract(const Duration(seconds: 5))), isTrue);
  });

  test('readSyncStats returns null when no sync has ever run', () async {
    expect(await readSyncStats(tempDir), isNull);
  });

  test('writeSyncStats + readSyncStats round-trips', () async {
    await writeSyncStats(tempDir, cachedTags: 522, totalTags: 600);
    final stats = await readSyncStats(tempDir);

    expect(stats, isNotNull);
    expect(stats!.cachedTags, 522);
    expect(stats.totalTags, 600);
  });

  test('concurrent put + save calls never corrupt the cache file', () async {
    final file = File('${tempDir.path}/concurrent.json');
    final cache = await ChangelogCache.load(file);

    await Future.wait([
      for (var i = 0; i < 50; i++)
        Future(() async {
          cache.put('tag-$i', ['title-$i']);
          await cache.save();
        }),
    ]);

    final reloaded = await ChangelogCache.load(file);
    expect(reloaded.length, 50);
    for (var i = 0; i < 50; i++) {
      expect(reloaded.prTitlesFor('tag-$i'), ['title-$i']);
    }
  });
}
