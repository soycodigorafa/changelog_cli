import 'app_registry.dart';
import 'git_client.dart';
import 'tag_info.dart';

class ChangelogEntry {
  ChangelogEntry({required this.tag, required this.prTitles});

  final TagInfo tag;
  final List<String> prTitles;
}

/// Loads every tag for [app], sorted chronologically, optionally narrowed by
/// [typeFilter] (e.g. `rc`, `ir`, `all`), an explicit [from]/[to] range, or a
/// trailing [limit].
Future<List<TagInfo>> loadTags(
  GitClient git,
  AppEntry app, {
  String typeFilter = 'all',
  String? from,
  String? to,
  int? limit,
}) async {
  final raw = await git.tagsMatching('*_${app.tagFormat}_*');
  final tags = raw
      .map((e) => TagInfo.parse(e.key, e.value, app.tagFormat))
      .whereType<TagInfo>()
      .where((t) => t.matchesTypeFilter(typeFilter))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  var result = tags;
  if (from != null) {
    final fromIndex = result.indexWhere((t) => t.rawTag == from);
    if (fromIndex >= 0) result = result.sublist(fromIndex);
  }
  if (to != null) {
    final toIndex = result.indexWhere((t) => t.rawTag == to);
    if (toIndex >= 0) result = result.sublist(0, toIndex + 1);
  }
  if (limit != null && limit < result.length) {
    result = result.sublist(result.length - limit);
  }
  return result;
}

/// For each tag (after the first), finds the PR titles merged since the
/// previous tag in the list.
Future<List<ChangelogEntry>> buildChangelog(GitClient git, List<TagInfo> tags) async {
  final entries = <ChangelogEntry>[];
  for (var i = 0; i < tags.length; i++) {
    entries.add(await buildChangelogEntryAt(git, tags, i));
  }
  return entries;
}

/// Builds the [ChangelogEntry] for just `tags[index]`, diffing against
/// `tags[index - 1]`. Lets callers (like the TUI) get one tag's PR titles
/// without paying for a diff of every tag in the list.
Future<ChangelogEntry> buildChangelogEntryAt(GitClient git, List<TagInfo> tags, int index) async {
  final tag = tags[index];
  if (index == 0) {
    return ChangelogEntry(tag: tag, prTitles: const []);
  }
  final previous = tags[index - 1];
  final titles = await git.prTitlesBetween(previous.rawTag, tag.rawTag);
  return ChangelogEntry(tag: tag, prTitles: titles);
}

/// Keeps only PR titles containing [ticketPrefix] (case-insensitive), e.g. `WR`.
List<ChangelogEntry> filterByTicketPrefix(List<ChangelogEntry> entries, String ticketPrefix) {
  final pattern = RegExp(RegExp.escape(ticketPrefix) + r'-\d+', caseSensitive: false);
  return entries
      .map((e) => ChangelogEntry(
            tag: e.tag,
            prTitles: e.prTitles.where((t) => pattern.hasMatch(t)).toList(),
          ))
      .toList();
}

/// The `[TAG]` groups inside a PR title, e.g. `TASK-1234-[FE][CO] some title`
/// → `['FE', 'CO']`, or `[NO TICKET] [BR] some title` → `['NO TICKET', 'BR']`.
List<String> extractBracketTags(String prTitle) {
  return RegExp(r'\[([^\]]+)\]').allMatches(prTitle).map((m) => m.group(1)!).toList();
}

/// [prTitle] with every `[TAG]` group (and a directly-preceding hyphen, e.g.
/// from `TASK-1234-[FE]`) removed, for display alongside the extracted tags.
String stripBracketTags(String prTitle) {
  return prTitle.replaceAll(RegExp(r'-?\[[^\]]+\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Keeps only PR titles matching [query]: either a ticket number
/// (`<query>-123`, case-insensitive) or a `[TAG]` group containing [query]
/// (case-insensitive), e.g. `FE` matches both `TASK-1234-[FE]...` and a bare
/// `[FE]` tag.
List<ChangelogEntry> filterByQuery(List<ChangelogEntry> entries, String query) {
  final ticketPattern = RegExp(RegExp.escape(query) + r'-\d+', caseSensitive: false);
  final lowerQuery = query.toLowerCase();
  bool matches(String title) {
    if (ticketPattern.hasMatch(title)) return true;
    return extractBracketTags(title).any((tag) => tag.toLowerCase().contains(lowerQuery));
  }

  return entries
      .map((e) => ChangelogEntry(tag: e.tag, prTitles: e.prTitles.where(matches).toList()))
      .toList();
}

/// Keeps only PR titles containing [query] anywhere (case-insensitive) — a
/// plain substring search, unlike [filterByQuery]'s ticket/tag-only matching.
List<ChangelogEntry> filterByText(List<ChangelogEntry> entries, String query) {
  final lowerQuery = query.toLowerCase();
  return entries
      .map((e) => ChangelogEntry(
            tag: e.tag,
            prTitles: e.prTitles.where((t) => t.toLowerCase().contains(lowerQuery)).toList(),
          ))
      .toList();
}
