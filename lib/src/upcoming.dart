import 'app_registry.dart';
import 'changelog.dart';
import 'git_client.dart';
import 'tag_info.dart';

/// One tag type's outstanding PRs: everything merged since that type's own
/// latest tag, up to `HEAD` — i.e. what would land in that type's next tag
/// if one were cut right now.
class UpcomingSection {
  UpcomingSection({required this.type, required this.sinceTag, required this.prTitles});

  final String type;
  final TagInfo sinceTag;
  final List<String> prTitles;
}

/// For every tag type that exists for [app], finds that type's own latest
/// tag (by creation date, via [loadTags]) and returns the PR titles merged
/// from there up to `HEAD` — mirrors [search.dart]'s per-type grouping, but
/// diffs against `HEAD` instead of another tag, so the result changes on
/// every new commit and must never be read from or written to
/// [ChangelogCache].
///
/// Types with no tags at all are skipped — there's no "latest tag" to diff
/// from.
Future<List<UpcomingSection>> buildUpcomingByType(GitClient git, AppEntry app) async {
  final tags = await loadTags(git, app);
  final byType = <String, List<TagInfo>>{};
  for (final tag in tags) {
    byType.putIfAbsent(tag.type, () => []).add(tag);
  }

  final sections = <UpcomingSection>[];
  for (final type in byType.keys.toList()..sort()) {
    final latest = byType[type]!.last;
    final titles = await git.prTitlesBetween(latest.rawTag, 'HEAD');
    sections.add(UpcomingSection(type: type, sinceTag: latest, prTitles: titles));
  }
  return sections;
}
