import 'dart:io';

import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/cache.dart';
import 'package:changelog_cli/src/sync.dart';
import 'package:test/test.dart';

import 'fake_git_client.dart';

void main() {
  final app = AppEntry(folderName: 'zz_sample', tagFormat: 'ZZ_Sample', displayName: 'Sample');
  final otherApp = AppEntry(folderName: 'zz_other', tagFormat: 'ZZ_Other', displayName: 'Other');

  final rcOld = 'RC_ZZ_Sample_v4.1.5+40000070';
  final rcNew = 'RC_ZZ_Sample_v4.1.6+40000072';
  final irOnly = 'IR_ZZ_Sample_v0.18.15';
  final otherIr = 'IR_ZZ_Other_v1.0.0';

  DateTime d(int day) => DateTime(2026, 1, day);

  FakeGitClient buildGit() => FakeGitClient(
        tags: [
          MapEntry(irOnly, d(1)),
          MapEntry(rcOld, d(2)),
          MapEntry(rcNew, d(3)),
        ],
        prTitles: {'$rcOld..$rcNew': ['WR-1 some change (#101)']},
      );

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('changelog_sync_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('syncApp caches every tag on first run', () async {
    final cache = await ChangelogCache.load(File('${tempDir.path}/app.json'));
    final result = await syncApp(buildGit(), app, cache);

    expect(result.newlyCached, 3);
    expect(result.totalCached, 3);
    expect(cache.prTitlesFor(rcNew), ['WR-1 some change (#101)']);
    expect(cache.prTitlesFor(irOnly), isEmpty);
  });

  test('syncApp does no new work on a second run against the same cache', () async {
    final cache = await ChangelogCache.load(File('${tempDir.path}/app.json'));
    await syncApp(buildGit(), app, cache);

    // Same tags, but no prTitles configured: if syncApp diffed rcOld..rcNew
    // again instead of trusting the cache, it would recompute an empty PR
    // list for rcNew instead of the cached one.
    final emptyGit = FakeGitClient(tags: [
      MapEntry(irOnly, d(1)),
      MapEntry(rcOld, d(2)),
      MapEntry(rcNew, d(3)),
    ]);
    final result = await syncApp(emptyGit, app, cache);

    expect(result.newlyCached, 0);
    expect(result.totalCached, 3);
    expect(cache.prTitlesFor(rcNew), ['WR-1 some change (#101)']);
  });

  test('syncAll covers every app and writes one cache file per app', () async {
    final cacheDir = Directory('${tempDir.path}/cache');
    final results = await syncAll(buildGit(), [app, otherApp], cacheDir);

    expect(results.map((r) => r.app.folderName), [app.folderName, otherApp.folderName]);
    expect(await cacheFileFor(cacheDir, app).exists(), isTrue);
    expect(await cacheFileFor(cacheDir, otherApp).exists(), isFalse); // no tags -> nothing to save
  });

  test('syncAll reports progress with a monotonic count and a stable grand total', () async {
    final cacheDir = Directory('${tempDir.path}/cache');
    final progress = <SyncProgress>[];

    await syncAll(buildGit(), [app, otherApp], cacheDir, onProgress: progress.add);

    // otherApp's tagFormat doesn't match any of the fake tags, so only
    // app's 3 tags ever get reported.
    expect(progress.map((p) => p.completed).toList(), [1, 2, 3]);
    expect(progress.map((p) => p.total).toSet(), {3});
    expect(progress.every((p) => p.appLabel == app.displayName), isTrue);
  });

  test('syncApp stops early when canceled mid-run, keeping whatever was already cached', () async {
    final cache = await ChangelogCache.load(File('${tempDir.path}/app.json'));
    final controller = SyncController();

    final result = await syncApp(
      buildGit(),
      app,
      cache,
      controller: controller,
      concurrency: 1, // deterministic order, so canceling after tag 1 is reproducible
      onProgress: (tag, completed, totalForApp) {
        if (completed == 1) controller.cancel();
      },
    );

    expect(result.newlyCached, 1);
    expect(result.totalCached, 1);
    expect(cache.prTitlesFor(irOnly), isEmpty);
    expect(cache.prTitlesFor(rcNew), isNull);
  });

  test('SyncController.waitIfPaused blocks until resume is called', () async {
    final controller = SyncController()..pause();
    var resumed = false;
    final future = controller.waitIfPaused().then((_) => resumed = true);

    await Future<void>.delayed(Duration.zero);
    expect(resumed, isFalse);

    controller.resume();
    await future;
    expect(resumed, isTrue);
  });

  test('SyncController.cancel unblocks a paused wait', () async {
    final controller = SyncController()..pause();
    var unblocked = false;
    final future = controller.waitIfPaused().then((_) => unblocked = true);

    controller.cancel();
    await future;

    expect(unblocked, isTrue);
    expect(controller.isCancelled, isTrue);
  });

  test('onStart reports the already-cached count before any diffing', () async {
    final cacheDir = Directory('${tempDir.path}/cache');
    await syncAll(buildGit(), [app, otherApp], cacheDir); // pre-cache everything

    int? startAlready, startTotal;
    await syncAll(
      buildGit(),
      [app, otherApp],
      cacheDir,
      onStart: (already, total) {
        startAlready = already;
        startTotal = total;
      },
    );

    expect(startAlready, 3); // everything was cached by the first run
    expect(startTotal, 3);
  });

  test('onFinished reports the final tally even when canceled before reaching a later app', () async {
    final cacheDir = Directory('${tempDir.path}/cache');
    final controller = SyncController();
    final gitWithBothApps = FakeGitClient(
      tags: [
        MapEntry(irOnly, d(1)),
        MapEntry(rcOld, d(2)),
        MapEntry(rcNew, d(3)),
        MapEntry(otherIr, d(1)),
      ],
      prTitles: {'$rcOld..$rcNew': ['WR-1 some change (#101)']},
    );

    int? finishedCached, finishedTotal;
    await syncAll(
      gitWithBothApps,
      [app, otherApp],
      cacheDir,
      controller: controller,
      concurrency: 1,
      onProgress: (progress) {
        if (progress.completed == 1) controller.cancel();
      },
      onFinished: (cachedNow, total) async {
        finishedCached = cachedNow;
        finishedTotal = total;
      },
    );

    // app's 3 tags + otherApp's 1 tag, but only app's first tag was reached
    // before the cancel took effect (otherApp's cache was never touched).
    expect(finishedTotal, 4);
    expect(finishedCached, 1);
  });

  test('syncApp with higher concurrency still caches every tag correctly', () async {
    final manyTags = List.generate(20, (i) => MapEntry('RC_ZZ_Sample_v1.0.$i', d(i + 1)));
    final commits = <String, List<String>>{};
    for (var i = 1; i < manyTags.length; i++) {
      commits['${manyTags[i - 1].key}..${manyTags[i].key}'] = ['PR-$i change (#$i)'];
    }
    final git = FakeGitClient(tags: manyTags, prTitles: commits);
    final cache = await ChangelogCache.load(File('${tempDir.path}/many.json'));

    final result = await syncApp(git, app, cache, concurrency: 4);

    expect(result.newlyCached, 20);
    expect(result.totalCached, 20);
    for (var i = 1; i < manyTags.length; i++) {
      expect(cache.prTitlesFor(manyTags[i].key), ['PR-$i change (#$i)']);
    }
  });
}
