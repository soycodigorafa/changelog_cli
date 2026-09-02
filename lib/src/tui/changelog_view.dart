import 'dart:io';

import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../changelog.dart';
import '../git_client.dart';
import '../sync.dart';
import '../tag_info.dart';
import 'pr_title_line.dart';
import 'sync_status_line.dart';

/// Screen 3: lists tags for the chosen app/type (cheap — just parsed tag
/// refs, no PR diffing), most recent first with a "fetch more" action to
/// reveal older ones in [_pageSize] batches. Selecting a tag lazily computes
/// its PR changelog on demand instead of diffing every tag up front, using
/// the on-disk cache in [cacheDir] first (see `lib/src/cache.dart`).
class ChangelogView extends StatefulComponent {
  const ChangelogView({
    super.key,
    required this.app,
    required this.git,
    required this.typeFilter,
    required this.cacheDir,
    required this.lastFullSyncAt,
    required this.syncStats,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final String typeFilter;
  final Directory cacheDir;
  final DateTime? lastFullSyncAt;
  final SyncStats? syncStats;
  final void Function() onBack;

  @override
  State<ChangelogView> createState() => _ChangelogViewState();
}

enum _QueryMode { none, tagFilter, search }

class _ChangelogViewState extends State<ChangelogView> {
  static const _pageSize = 5;

  final ScrollController _scrollController = ScrollController();

  List<TagInfo>? tags;
  String? error;
  int visibleCount = _pageSize;
  int selectedIndex = 0;

  ChangelogEntry? selectedEntry;
  String? detailError;
  bool loadingDetail = false;

  /// Which kind of query is active in the detail view: `/` filters by
  /// ticket number or `[tag]`, `s` searches PR titles for any substring.
  _QueryMode queryMode = _QueryMode.none;
  bool editingQuery = false;
  String queryText = '';

  late final Future<ChangelogCache> _cacheFuture;

  @override
  void initState() {
    super.initState();
    _cacheFuture = ChangelogCache.load(cacheFileFor(component.cacheDir, component.app));
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await loadTags(component.git, component.app, typeFilter: component.typeFilter);
      setState(() {
        tags = loaded;
        visibleCount = loaded.length < _pageSize ? loaded.length : _pageSize;
      });
    } catch (e) {
      setState(() {
        error = '$e';
      });
    }
  }

  /// Most recent tags first, capped at [visibleCount].
  List<TagInfo> get _visibleTags {
    final all = tags!;
    final start = all.length - visibleCount;
    return all.sublist(start < 0 ? 0 : start).reversed.toList();
  }

  bool get _hasMore => tags != null && visibleCount < tags!.length;

  void _fetchMore() {
    if (!_hasMore) return;
    setState(() {
      visibleCount = (visibleCount + _pageSize).clamp(0, tags!.length);
    });
  }

  Future<void> _openTag(TagInfo tag) async {
    final all = tags!;
    final index = all.indexOf(tag);
    setState(() {
      loadingDetail = true;
      detailError = null;
      selectedEntry = null;
    });
    try {
      final cache = await _cacheFuture;
      final entry = await buildChangelogEntryAtCached(cache, component.git, all, index);
      await cache.save();
      setState(() {
        selectedEntry = entry;
        loadingDetail = false;
      });
      _scrollController.jumpTo(0);
    } catch (e) {
      setState(() {
        detailError = '$e';
        loadingDetail = false;
      });
    }
  }

  void _closeDetail() {
    setState(() {
      selectedEntry = null;
      detailError = null;
      loadingDetail = false;
      queryMode = _QueryMode.none;
      editingQuery = false;
      queryText = '';
    });
  }

  void _startQuery(_QueryMode mode) {
    setState(() {
      if (queryMode != mode) queryText = '';
      queryMode = mode;
      editingQuery = true;
    });
  }

  List<String> get _visiblePrTitles {
    final entry = selectedEntry!;
    if (queryText.isEmpty) return entry.prTitles;
    switch (queryMode) {
      case _QueryMode.tagFilter:
        return filterByQuery([entry], queryText).single.prTitles;
      case _QueryMode.search:
        return filterByText([entry], queryText).single.prTitles;
      case _QueryMode.none:
        return entry.prTitles;
    }
  }

  void _scrollBy(double delta) {
    _scrollController.jumpTo(_scrollController.offset + delta);
  }

  @override
  Component build(BuildContext context) {
    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(1),
        child: Text('Error loading tags: $error', style: const TextStyle(color: Colors.brightRed)),
      );
    }
    if (tags == null) {
      return const Container(
        padding: EdgeInsets.all(1),
        child: Text('Loading tags...'),
      );
    }
    if (tags!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(1),
        child: Text('No ${component.typeFilter} tags found for ${component.app.folderName}.'),
      );
    }

    if (loadingDetail) {
      return const Container(
        padding: EdgeInsets.all(1),
        child: Text('Loading changelog...'),
      );
    }
    if (detailError != null) {
      return Container(
        padding: const EdgeInsets.all(1),
        child: Text('Error building changelog: $detailError', style: const TextStyle(color: Colors.brightRed)),
      );
    }
    if (selectedEntry != null) {
      return _buildDetail(selectedEntry!);
    }
    return _buildList();
  }

  Component _buildList() {
    final visible = _visibleTags;
    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (event.logicalKey == LogicalKey.arrowDown) {
          setState(() {
            if (selectedIndex < visible.length - 1) selectedIndex++;
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.arrowUp) {
          setState(() {
            if (selectedIndex > 0) selectedIndex--;
          });
          return true;
        }
        if (event.logicalKey == LogicalKey.enter) {
          _openTag(visible[selectedIndex]);
          return true;
        }
        if (event.character == 'f') {
          _fetchMore();
          return true;
        }
        if (event.logicalKey == LogicalKey.escape) {
          component.onBack();
          return true;
        }
        if (event.logicalKey == LogicalKey.keyQ) {
          shutdownApp();
          return true;
        }
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${component.app.folderName} [${component.typeFilter}] — showing ${visible.length} of ${tags!.length} tags',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            buildSyncStatusLine(component.lastFullSyncAt, component.syncStats),
            const SizedBox(height: 1),
            for (var i = 0; i < visible.length; i++)
              Text(
                '${i == selectedIndex ? '> ' : '  '}${visible[i].versionLabel}-${visible[i].type}',
                style: TextStyle(color: i == selectedIndex ? Colors.brightCyan : Colors.white),
              ),
            const SizedBox(height: 1),
            Text(
              _hasMore
                  ? '↑/↓ move   Enter view changelog   f fetch $_pageSize more   Esc back   q quit'
                  : '↑/↓ move   Enter view changelog   Esc back   q quit',
              style: const TextStyle(color: Colors.brightBlack),
            ),
          ],
        ),
      ),
    );
  }

  String _headerText() {
    if (editingQuery) {
      final label = queryMode == _QueryMode.tagFilter ? 'Filter (ticket # or [tag])' : 'Search PR titles';
      return '$label: $queryText';
    }
    final active = queryText.isEmpty
        ? ''
        : '   [${queryMode == _QueryMode.tagFilter ? 'filter' : 'search'}: $queryText]';
    return '${component.app.folderName} [${component.typeFilter}]   '
        '↑/↓/PgUp/PgDn scroll   / filter   s search   Esc back to list   q quit$active';
  }

  Component _buildDetail(ChangelogEntry entry) {
    final titles = _visiblePrTitles;
    final lines = <Component>[
      Text(
        '${component.app.displayName} ${entry.tag.versionLabel}-${entry.tag.type}',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brightYellow),
      ),
      const SizedBox(height: 1),
      for (final title in titles) ...[
        buildPrTitleLine(title),
        const SizedBox(height: 1),
      ],
    ];

    return Focusable(
      focused: true,
      onKeyEvent: (event) {
        if (editingQuery) {
          if (event.logicalKey == LogicalKey.escape) {
            setState(() {
              editingQuery = false;
              queryMode = _QueryMode.none;
              queryText = '';
            });
            return true;
          }
          if (event.logicalKey == LogicalKey.enter) {
            setState(() => editingQuery = false);
            return true;
          }
          if (event.logicalKey == LogicalKey.backspace) {
            if (queryText.isNotEmpty) {
              setState(() => queryText = queryText.substring(0, queryText.length - 1));
            }
            return true;
          }
          if (event.character != null && event.character!.isNotEmpty) {
            setState(() => queryText += event.character!);
            return true;
          }
          return false;
        }

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
        if (event.logicalKey == LogicalKey.slash) {
          _startQuery(_QueryMode.tagFilter);
          return true;
        }
        if (event.character == 's') {
          _startQuery(_QueryMode.search);
          return true;
        }
        if (event.logicalKey == LogicalKey.escape) {
          _closeDetail();
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
                Text(_headerText(), style: const TextStyle(color: Colors.brightBlack)),
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
