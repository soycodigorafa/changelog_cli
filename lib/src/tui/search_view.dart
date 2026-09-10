import 'dart:io';

import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../git_client.dart';
import '../search.dart';
import '../time_range.dart';
import 'design/design.dart';

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
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final Directory cacheDir;
  final DateTime? lastFullSyncAt;
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

  bool _onFormKeyEvent(KeyboardEvent event) {
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
  }

  bool _onResultsKeyEvent(KeyboardEvent event) {
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
  }

  @override
  Component build(BuildContext context) {
    if (loading) {
      return ScreenScaffold(
        onKeyEvent: (_) => false,
        header: SectionHeader('${component.app.folderName} — search PR titles'),
        body: const LoadingText('Searching...'),
        footer: const FooterHint(''),
      );
    }
    final matches = results;
    if (matches != null) {
      return _SearchResultsBody(
        appLabel: component.app.folderName,
        queryText: queryText,
        rangeLabel: _rangeLabel,
        matches: matches,
        lastFullSyncAt: component.lastFullSyncAt,
        scrollController: _scrollController,
        onKeyEvent: _onResultsKeyEvent,
      );
    }
    return _SearchFormBody(
      appLabel: component.app.folderName,
      queryText: queryText,
      rangeLabel: _rangeLabel,
      error: error,
      lastFullSyncAt: component.lastFullSyncAt,
      onKeyEvent: _onFormKeyEvent,
    );
  }
}

class _SearchFormBody extends StatelessComponent {
  const _SearchFormBody({
    required this.appLabel,
    required this.queryText,
    required this.rangeLabel,
    required this.error,
    required this.lastFullSyncAt,
    required this.onKeyEvent,
  });

  final String appLabel;
  final String queryText;
  final String rangeLabel;
  final String? error;
  final DateTime? lastFullSyncAt;
  final KeyEventHandler onKeyEvent;

  @override
  Component build(BuildContext context) {
    return ScreenScaffold(
      onKeyEvent: onKeyEvent,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('$appLabel — search PR titles'),
          StatusLine(lastFullSyncAt: lastFullSyncAt),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BodyText('Query: $queryText'),
          BodyText('Range: $rangeLabel   (←/→ to change)'),
          if (error != null) ErrorText(error!),
        ],
      ),
      footer: const FooterHint('Type to edit query   ←/→ range   Enter search   Esc back'),
    );
  }
}

class _SearchResultsBody extends StatelessComponent {
  const _SearchResultsBody({
    required this.appLabel,
    required this.queryText,
    required this.rangeLabel,
    required this.matches,
    required this.lastFullSyncAt,
    required this.scrollController,
    required this.onKeyEvent,
  });

  final String appLabel;
  final String queryText;
  final String rangeLabel;
  final List<SearchMatch> matches;
  final DateTime? lastFullSyncAt;
  final ScrollController scrollController;
  final KeyEventHandler onKeyEvent;

  @override
  Component build(BuildContext context) {
    return ScreenScaffold(
      onKeyEvent: onKeyEvent,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FooterHint(
            '$appLabel   query: "$queryText"   range: $rangeLabel   '
            '↑/↓/PgUp/PgDn scroll   drag to copy   Esc edit query   q quit',
          ),
          StatusLine(lastFullSyncAt: lastFullSyncAt),
        ],
      ),
      body: matches.isEmpty
          ? BodyText('No match for "$queryText" within $rangeLabel. Try a wider range or a different query.')
          : CopyableScrollBody(
              controller: scrollController,
              children: [
                for (final match in matches) ...[
                  PrTitleSection(
                    tagLabel: '${match.type} ${match.tag.versionLabel} (${match.tag.rawTag})',
                    titles: match.matchedTitles,
                  ),
                  AppSpacing.gap,
                ],
              ],
            ),
      footer: const FooterHint(''),
    );
  }
}
