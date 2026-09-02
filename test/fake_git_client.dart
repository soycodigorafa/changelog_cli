import 'package:changelog_cli/src/git_client.dart';

/// In-memory [GitClient] fake for tests: no real git calls.
class FakeGitClient implements GitClient {
  FakeGitClient({
    this.tags = const [],
    this.prTitles = const {},
  });

  final List<MapEntry<String, DateTime>> tags;

  /// Keyed by `"$from..$to"`.
  final Map<String, List<String>> prTitles;

  bool fetched = false;

  @override
  Future<void> fetchTags() async {
    fetched = true;
  }

  @override
  Future<List<MapEntry<String, DateTime>>> tagsMatching(String glob) async => tags;

  @override
  Future<List<String>> prTitlesBetween(String from, String to) async => prTitles['$from..$to'] ?? const [];
}
