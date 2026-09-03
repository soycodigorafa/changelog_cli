import 'dart:io';

import 'package:args/args.dart';
import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/cache.dart';
import 'package:changelog_cli/src/changelog.dart';
import 'package:changelog_cli/src/formatter.dart';
import 'package:changelog_cli/src/git_client.dart';
import 'package:changelog_cli/src/search.dart';
import 'package:changelog_cli/src/sync.dart';
import 'package:changelog_cli/src/time_range.dart';
import 'package:changelog_cli/src/tui/app.dart';
import 'package:changelog_cli/src/version.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  try {
    await _run(arguments);
  } catch (error) {
    _printFriendlyError(error);
    exitCode = 1;
  }
}

Future<void> _run(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('type', defaultsTo: 'all', help: 'Filter tag type: ir, rc, rc_store, ir_qa, all')
    ..addOption('from', help: 'Start tag (inclusive)')
    ..addOption('to', help: 'End tag (inclusive), defaults to latest')
    ..addOption('limit', help: 'Only the last N tags')
    ..addOption('ticket-prefix', help: 'Only include PR lines matching this ticket prefix, e.g. WR')
    ..addOption('format', defaultsTo: 'markdown', help: 'Output format: markdown or text')
    ..addOption('display-name', help: 'Override the header name for a single app (ignored with "all")')
    ..addOption('since',
        defaultsTo: 'max',
        help: 'search: how far back to look, e.g. day, "2 days", "365 days", "1 year", or max')
    ..addFlag('fetch', negatable: false, help: 'Run git fetch --tags before reading (off by default)')
    ..addFlag('no-cache', negatable: false, help: 'Skip the on-disk PR-title cache for this run')
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('version', abbr: 'v', negatable: false);

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}\n');
    _printUsage(parser);
    exitCode = 64;
    return;
  }

  if (args['version'] as bool) {
    stdout.writeln('changelog_cli v$appVersion');
    return;
  }

  if (args['help'] as bool) {
    _printUsage(parser);
    return;
  }

  final repoRoot = _findRepoRoot();
  final apps = discoverApps(repoRoot);
  final cacheDir = Directory(p.join(repoRoot, 'local_tools', 'changelog_cli', '.cache'));
  final useCache = !(args['no-cache'] as bool);

  if (args.rest.isEmpty) {
    final git = ProcessGitClient(workingDirectory: repoRoot);
    if (args['fetch'] as bool) {
      await git.fetchTags();
    }
    await runChangelogTui(apps, git, cacheDir);
    return;
  }

  if (args.rest[0] == 'sync') {
    final git = ProcessGitClient(workingDirectory: repoRoot);
    if (args['fetch'] as bool) {
      await git.fetchTags();
    }
    final results = await syncAll(
      git,
      apps,
      cacheDir,
      onFinished: (cachedTagsNow, totalTags) => writeSyncStats(cacheDir, cachedTags: cachedTagsNow, totalTags: totalTags),
    );
    await recordFullSync(cacheDir);
    for (final result in results) {
      if (result.newlyCached == 0) {
        stdout.writeln('${result.app.displayName}: up to date (${result.totalCached} tags cached)');
      } else {
        stdout.writeln('${result.app.displayName}: +${result.newlyCached} new tags cached (${result.totalCached} total)');
      }
    }
    return;
  }

  final appArg = args.rest[0];
  final command = args.rest.length > 1 ? args.rest[1] : 'changelog';

  var targets = appArg == 'all' ? apps : [findApp(apps, appArg)].whereType<AppEntry>().toList();

  if (targets.isEmpty) {
    stderr.writeln('Unknown app "$appArg". Known apps: ${apps.map((a) => a.folderName).join(', ')}');
    exitCode = 64;
    return;
  }

  final displayNameOverride = args['display-name'] as String?;
  if (displayNameOverride != null && targets.length == 1) {
    final only = targets.single;
    targets = [
      AppEntry(folderName: only.folderName, tagFormat: only.tagFormat, displayName: displayNameOverride),
    ];
  }

  final git = ProcessGitClient(workingDirectory: repoRoot);
  if (args['fetch'] as bool) {
    await git.fetchTags();
  }

  if (command == 'search') {
    final query = args.rest.length > 2 ? args.rest[2] : null;
    if (query == null) {
      stderr.writeln('search requires a query, e.g.: changelog <app> search "TASK-1234" --since 1y');
      exitCode = 64;
      return;
    }
    Duration? within;
    try {
      within = parseTimeRange(args['since'] as String);
    } on ArgumentError catch (e) {
      stderr.writeln('Error: ${e.message}');
      exitCode = 64;
      return;
    }
    for (final app in targets) {
      final cache = useCache ? await ChangelogCache.load(cacheFileFor(cacheDir, app)) : null;
      final matches = await searchAcrossTags(
        git,
        app,
        query,
        within: within,
        typeFilter: args['type'] as String,
        cache: cache,
      );
      if (cache != null) await cache.save();
      if (matches.isEmpty) {
        stdout.writeln('${app.displayName}: no match for "$query" within ${args['since']}.');
      } else {
        stdout.writeln('${app.displayName}:');
        for (final m in matches) {
          stdout.writeln('  ${m.type} ${m.tag.versionLabel} (${m.tag.rawTag})');
          for (final title in m.matchedTitles) {
            stdout.writeln('    - $title');
          }
        }
      }
      if (app != targets.last) stdout.writeln('');
    }
    return;
  }

  final OutputFormat format;
  try {
    format = parseOutputFormat(args['format'] as String);
  } on ArgumentError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exitCode = 64;
    return;
  }

  final limitArg = args['limit'] as String?;
  final limit = limitArg == null ? null : int.tryParse(limitArg);

  for (final app in targets) {
    final tags = await loadTags(
      git,
      app,
      typeFilter: args['type'] as String,
      from: args['from'] as String?,
      to: args['to'] as String?,
      limit: limit,
    );

    if (tags.isEmpty) {
      stderr.writeln('No tags found for ${app.folderName} matching the given filters.');
      continue;
    }

    if (command == 'list') {
      print(formatTagList(app, tags));
    } else {
      final cache = useCache ? await ChangelogCache.load(cacheFileFor(cacheDir, app)) : null;
      var entries = cache == null ? await buildChangelog(git, tags) : await buildChangelogCached(cache, git, tags);
      if (cache != null) await cache.save();
      final ticketPrefix = args['ticket-prefix'] as String?;
      if (ticketPrefix != null) {
        entries = filterByTicketPrefix(entries, ticketPrefix);
      }
      print(formatChangelog(app, entries, format));
    }
    if (app != targets.last) print('');
  }
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(dir.path, 'apps')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        "chlog needs to run from inside the target repo (a folder with both apps/ and "
        "pubspec.yaml). Searched from: ${Directory.current.path}",
      );
    }
    dir = parent;
  }
}

/// Turns an uncaught error into a short, human-readable message instead of a
/// raw Dart stack trace — the last line of defense for anything not already
/// handled with a specific error message above (bad args, unknown app, ...).
void _printFriendlyError(Object error) {
  if (error is ProcessException) {
    final command = '${error.executable} ${error.arguments.join(' ')}'.trim();
    stderr.writeln('chlog could not run `$command`.');
    final detail = error.message.trim();
    if (detail.isNotEmpty) stderr.writeln(detail);
  } else if (error is StateError) {
    stderr.writeln('chlog error: ${error.message}');
  } else if (error is ArgumentError) {
    stderr.writeln('chlog error: ${error.message}');
  } else {
    stderr.writeln('chlog hit an unexpected error: $error');
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln('''
Usage: changelog <app|all> [list|changelog|search "<query>"] [options]
       changelog sync

  app        apps/<name> folder, e.g. some_app, or "all"
  list       show tags chronologically instead of the PR changelog
  changelog  (default) show PR titles merged between each tag and the previous one
  search     find which tags (across every type) shipped a PR matching "<query>",
             bounded by --since, e.g. changelog some_app search "TASK-1234" --since 1 year
  sync       backfill the on-disk PR-title cache for every app, so changelog/search/list
             and the TUI don't have to re-diff git history for tags already seen

By default, changelog/search/list read the cache first and write anything newly computed
back into it (see --no-cache); sync is just the deliberate way to warm it in bulk.

Options:
${parser.usage}''');
}
