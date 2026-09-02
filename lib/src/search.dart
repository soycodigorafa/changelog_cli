import 'app_registry.dart';
import 'cache.dart';
import 'changelog.dart';
import 'git_client.dart';
import 'sync.dart';
import 'tag_info.dart';

/// One tag whose PR diff (against its predecessor) matched a search query.
class SearchMatch {
  SearchMatch({required this.type, required this.tag, required this.matchedTitles});

  /// The exact tag type, e.g. `IR`, `RC`, `RC_store`, `IR_QA`.
  final String type;

  final TagInfo tag;
  final List<String> matchedTitles;
}

/// Searches every tag type for [app] (or just [typeFilter], see [loadTags])
/// for PR titles matching [query] (plain case-insensitive substring, see
/// [filterByText]), only diffing tags created within [within] of now
/// (`null` means no limit — search full history). When [cache] is provided,
/// reads/writes it via [buildChangelogEntryAtCached] instead of always
/// hitting git live.
Future<List<SearchMatch>> searchAcrossTags(
  GitClient git,
  AppEntry app,
  String query, {
  Duration? within,
  String typeFilter = 'all',
  ChangelogCache? cache,
}) async {
  final allTags = await loadTags(git, app, typeFilter: typeFilter);
  final byType = <String, List<TagInfo>>{};
  for (final tag in allTags) {
    byType.putIfAbsent(tag.type, () => []).add(tag);
  }

  final cutoff = within == null ? null : DateTime.now().subtract(within);
  final matches = <SearchMatch>[];
  for (final type in byType.keys.toList()..sort()) {
    final typeTags = byType[type]!;
    for (var i = 0; i < typeTags.length; i++) {
      final tag = typeTags[i];
      if (cutoff != null && tag.createdAt.isBefore(cutoff)) continue;
      final entry = cache == null
          ? await buildChangelogEntryAt(git, typeTags, i)
          : await buildChangelogEntryAtCached(cache, git, typeTags, i);
      final matchedTitles = filterByText([entry], query).single.prTitles;
      if (matchedTitles.isNotEmpty) {
        matches.add(SearchMatch(type: type, tag: tag, matchedTitles: matchedTitles));
      }
    }
  }
  return matches;
}
