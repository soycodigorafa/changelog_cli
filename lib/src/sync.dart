import 'dart:async';
import 'dart:io';

import 'app_registry.dart';
import 'cache.dart';
import 'changelog.dart';
import 'git_client.dart';
import 'tag_info.dart';

const _defaultConcurrency = 8;

/// Cache-first version of [buildChangelogEntryAt]: returns the cached PR
/// titles for `tags[index]` if present, else computes them live and writes
/// the result into [cache] (in-memory — caller decides when to persist via
/// `cache.save()`).
Future<ChangelogEntry> buildChangelogEntryAtCached(
  ChangelogCache cache,
  GitClient git,
  List<TagInfo> tags,
  int index,
) async {
  final tag = tags[index];
  final cached = cache.prTitlesFor(tag.rawTag);
  if (cached != null) {
    return ChangelogEntry(tag: tag, prTitles: cached);
  }
  final entry = await buildChangelogEntryAt(git, tags, index);
  cache.put(tag.rawTag, entry.prTitles);
  return entry;
}

/// Cache-first version of [buildChangelog].
Future<List<ChangelogEntry>> buildChangelogCached(ChangelogCache cache, GitClient git, List<TagInfo> tags) async {
  final entries = <ChangelogEntry>[];
  for (var i = 0; i < tags.length; i++) {
    entries.add(await buildChangelogEntryAtCached(cache, git, tags, i));
  }
  return entries;
}

class SyncResult {
  SyncResult({required this.app, required this.newlyCached, required this.totalCached});

  final AppEntry app;
  final int newlyCached;
  final int totalCached;
}

/// Lets a caller pause/resume/cancel an in-progress [syncApp]/[syncAll] run.
/// Checked between tags, so the earliest it takes effect is right after the
/// tag(s) currently in flight finish — nothing already computed is lost,
/// since each tag's cache entry is saved as soon as it's computed (see
/// [syncApp]).
class SyncController {
  bool _cancelled = false;
  Completer<void>? _pauseCompleter;

  bool get isCancelled => _cancelled;
  bool get isPaused => _pauseCompleter != null;

  void cancel() {
    _cancelled = true;
    resume(); // unblock a paused loop so it can observe the cancellation
  }

  void pause() {
    _pauseCompleter ??= Completer<void>();
  }

  void resume() {
    _pauseCompleter?.complete();
    _pauseCompleter = null;
  }

  Future<void> waitIfPaused() async {
    final completer = _pauseCompleter;
    if (completer != null) await completer.future;
  }
}

/// One tag processed during a [syncAll] run, for driving a progress bar.
class SyncProgress {
  SyncProgress({required this.appLabel, required this.tagLabel, required this.completed, required this.total});

  final String appLabel;

  /// e.g. `RC v4.1.6+40000072`.
  final String tagLabel;

  /// 1-based, across every app in the run.
  final int completed;

  /// Grand total tags across every app in the run.
  final int total;
}

/// Runs [concurrency] workers pulling from [items] until it's drained.
/// Safe with no locking: Dart's single-threaded event loop means the
/// index read-and-increment below never interleaves with itself.
Future<void> _forEachConcurrently<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T item) action,
) async {
  if (items.isEmpty) return;
  var nextIndex = 0;
  Future<void> worker() async {
    while (nextIndex < items.length) {
      final item = items[nextIndex];
      nextIndex++;
      await action(item);
    }
  }

  final workerCount = concurrency.clamp(1, items.length);
  await Future.wait(List.generate(workerCount, (_) => worker()));
}

class _TagTask {
  _TagTask(this.typeTags, this.index);
  final List<TagInfo> typeTags;
  final int index;

  TagInfo get tag => typeTags[index];
}

/// Backfills every tag (across every type) for [app] that isn't cached yet,
/// up to [concurrency] tag-diffs at a time (each diff only depends on two
/// tag names, so they're independent of each other and safe to run
/// concurrently — git reads don't need locking). Each newly-computed tag is
/// saved to [cache] immediately, so a kill mid-run only loses whatever was
/// concurrently in flight at that instant, not the whole app's progress.
/// [onProgress], if given, is called once per tag processed (cache hit or
/// fresh compute) with a 1-based [completed] count out of this app's
/// [totalForApp]. Pass already-loaded [tags] to skip a redundant listing.
Future<SyncResult> syncApp(
  GitClient git,
  AppEntry app,
  ChangelogCache cache, {
  List<TagInfo>? tags,
  void Function(TagInfo tag, int completed, int totalForApp)? onProgress,
  SyncController? controller,
  int concurrency = _defaultConcurrency,
}) async {
  final allTags = tags ?? await loadTags(git, app);
  final byType = <String, List<TagInfo>>{};
  for (final tag in allTags) {
    byType.putIfAbsent(tag.type, () => []).add(tag);
  }
  final tasks = <_TagTask>[
    for (final typeTags in byType.values)
      for (var i = 0; i < typeTags.length; i++) _TagTask(typeTags, i),
  ];

  var newlyCached = 0;
  var processed = 0;
  final totalForApp = tasks.length;

  await _forEachConcurrently(tasks, concurrency, (task) async {
    if (controller != null) {
      await controller.waitIfPaused();
      if (controller.isCancelled) return;
    }
    if (cache.prTitlesFor(task.tag.rawTag) == null) {
      await buildChangelogEntryAtCached(cache, git, task.typeTags, task.index);
      newlyCached++;
      await cache.save();
    }
    processed++;
    onProgress?.call(task.tag, processed, totalForApp);
  });

  return SyncResult(app: app, newlyCached: newlyCached, totalCached: cache.length);
}

/// Runs [syncApp] for every app in [apps], loading each app's tags and
/// cache once up front (so the totals below and the real work never
/// re-list tags), then diffing sequentially app-by-app (concurrency is
/// *within* one app's tags, via [concurrency]). The "for all the apps"
/// entry point.
///
/// [onStart], if given, is called once with the already-cached count and
/// the grand total, before any diffing starts. [onProgress] reports one
/// combined [SyncProgress] per tag across every app. [onFinished], if
/// given, is called once at the end — even if [controller] was canceled —
/// with the final cached/total tally, so callers can persist a
/// synced-percentage that reflects exactly how far the run got.
Future<List<SyncResult>> syncAll(
  GitClient git,
  List<AppEntry> apps,
  Directory cacheDir, {
  void Function(int alreadyCached, int totalTags)? onStart,
  void Function(SyncProgress progress)? onProgress,
  Future<void> Function(int cachedTagsNow, int totalTags)? onFinished,
  SyncController? controller,
  int concurrency = _defaultConcurrency,
}) async {
  final tagsByApp = <AppEntry, List<TagInfo>>{};
  final cachesByApp = <AppEntry, ChangelogCache>{};
  var grandTotal = 0;
  var alreadyCached = 0;
  for (final app in apps) {
    final tags = await loadTags(git, app);
    final cache = await ChangelogCache.load(cacheFileFor(cacheDir, app));
    tagsByApp[app] = tags;
    cachesByApp[app] = cache;
    grandTotal += tags.length;
    alreadyCached += tags.where((t) => cache.prTitlesFor(t.rawTag) != null).length;
  }
  onStart?.call(alreadyCached, grandTotal);

  final results = <SyncResult>[];
  var completedSoFar = 0;
  for (final app in apps) {
    if (controller?.isCancelled ?? false) break;
    final cache = cachesByApp[app]!;
    final result = await syncApp(
      git,
      app,
      cache,
      tags: tagsByApp[app],
      controller: controller,
      concurrency: concurrency,
      onProgress: onProgress == null
          ? null
          : (tag, completed, totalForApp) => onProgress(SyncProgress(
                appLabel: app.displayName,
                tagLabel: '${tag.type} ${tag.versionLabel}',
                completed: completedSoFar + completed,
                total: grandTotal,
              )),
    );
    completedSoFar += tagsByApp[app]!.length;
    await cache.save();
    results.add(result);
  }

  if (onFinished != null) {
    final cachedTagsNow = apps.fold<int>(0, (sum, app) => sum + cachesByApp[app]!.length);
    await onFinished(cachedTagsNow, grandTotal);
  }

  return results;
}
