import 'dart:io';

import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../git_client.dart';
import '../search.dart';
import '../time_range.dart';
import 'pr_title_line.dart';
import 'sync_status_line.dart';

/// Reachable from the type picker's `Search` entry: type a query, pick a
/// time range, and see every tag (across every type) whose PR diff matched.
/// Uses the on-disk cache in [cacheDir] first (see `lib/src/cache.dart`).
class SearchView extends StatefulComponent {
  const SearchView({
    super.key,
    required this.app,
    required this.git,
    required this.cacheDir,
    required this.lastFullSyncAt,
    required this.syncStats,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final Directory cacheDir;
  final DateTime? lastFullSyncAt;
  final SyncStats? syncStats;
  final void Function() onBack;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  static const _ranges = ['day', 'week', 'month', 'year', 'max'];

  final ScrollController _scrollController = ScrollController();
  late final Future<ChangelogCache> _cacheFuture;

  String queryText = '';
  int rangeIndex = _ranges.length - 1;
  bool loading = false;
  String? error;
  List<SearchMatch>? results;

  String get _rangeLabel => _ranges[rangeIndex];

  @override
  void initState() {
    super.initState();
    _cacheFuture = ChangelogCache.load(cacheFileFor(component.cacheDir, component.app));
  }

  Future<void> _runSearch() async {
    final query = queryText.trim();
    if (query.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final cache = await _cacheFuture;
      final matches = await searchAcrossTags(
        component.git,
        component.app,
        query,
        within: parseTimeRange(_rangeLabel),
        cache: cache,
      );
      await cache.save();
      setState(() {
        results = matches;
        loading = false;
      });
      _scrollController.jumpTo(0);
    } catch (e) {
      setState(() {
        error = '$e';
        loading = false;
      });
    }
  }

  void _scrollBy(double delta) {
    _scrollController.jumpTo(_scrollController.offset + delta);
  }

  @override
  Component build(BuildContext context) {
    if (loading) {
      return const Container(
        padding: EdgeInsets.all(1),
        child: Text('Searching...'),
      );
    }
    if (results != null) {
      return _buildResults(results!);
    }
    return _buildForm();
  }

  Component _buildForm() {
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowLeft) {
          setState(() {
            if (rangeIndex > 0) rangeIndex--;
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowRight) {
          setState(() {
            if (rangeIndex < _ranges.length - 1) rangeIndex++;
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.enter) {
          _runSearch();
          return true;
        }
        if (event.logicalKey == LogicalKey.backspace) {
          if (queryText.isNotEmpty) {
            setState(() => queryText = queryText.substring(0, queryText.length - 1));
          }
          return true;
        }
        if (event.logicalKey == LogicalKey.escape) {
          component.onBack();
          return true;
        }
        if (event.character != null && event.character!.isNotEmpty) {
          setState(() => queryText += event.character!);
          return true;
        }
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${component.app.folderName} — search PR titles', style: const TextStyle(fontWeight: FontWeight.bold)),
            buildSyncStatusLine(component.lastFullSyncAt, component.syncStats),
            const SizedBox(height: 1),
            Text('Query: $queryText'),
            Text('Range: $_rangeLabel   (←/→ to change)'),
            if (error != null) ...[
              const SizedBox(height: 1),
              Text(error!, style: const TextStyle(color: Colors.brightRed)),
            ],
            const SizedBox(height: 1),
            const Text('Type to edit query   ←/→ range   Enter search   Esc back',
                style: TextStyle(color: Colors.brightBlack)),
          ],
        ),
      ),
    );
  }

  Component _buildResults(List<SearchMatch> matches) {
    final lines = <Component>[];
    if (matches.isEmpty) {
      lines.add(Text('No match for "$queryText" within $_rangeLabel. Try a wider range or a different query.'));
    } else {
      for (final match in matches) {
        lines.add(Text(
          '${match.type} ${match.tag.versionLabel} (${match.tag.rawTag})',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brightYellow),
        ));
        for (final title in match.matchedTitles) {
          lines.add(buildPrTitleLine(title));
        }
        lines.add(const SizedBox(height: 1));
      }
    }

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowDown) {
          _scrollBy(1);
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp) {
          _scrollBy(-1);
          return true;
        }
        if (event.logicalKey == LogicalKey.pageDown) {
          _scrollBy(10);
          return true;
        }
        if (event.logicalKey == LogicalKey.pageUp) {
          _scrollBy(-10);
          return true;
        }
        if (event.logicalKey == LogicalKey.escape) {
          setState(() => results = null);
          return true;
        }
        if (event.logicalKey == LogicalKey.keyQ) {
          shutdownApp();
          return true;
        }
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${component.app.folderName}   query: "$queryText"   range: $_rangeLabel   '
                  '↑/↓/PgUp/PgDn scroll   Esc edit query   q quit',
                  style: const TextStyle(color: Colors.brightBlack),
                ),
                buildSyncStatusLine(component.lastFullSyncAt, component.syncStats),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines),
            ),
          ),
        ],
      ),
    );
  }
}
