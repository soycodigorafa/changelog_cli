import 'dart:io';

/// Thin wrapper over the `git` CLI. Abstracted behind this class (rather than
/// calling `Process.run` directly from changelog logic) so tests can supply a
/// fake implementation instead of shelling out.
abstract class GitClient {
  Future<void> fetchTags();

  /// Tags matching [glob] (a `git tag -l` pattern), each with its creation date.
  Future<List<MapEntry<String, DateTime>>> tagsMatching(String glob);

  /// PR titles for commits between [from] and [to] (exclusive..inclusive)
  /// that look like merged PRs: either a real "Merge pull request" commit
  /// (title = first non-empty line of its body) or a squash merge whose
  /// subject ends in "(#123)" (title = the subject itself), replicating the
  /// squash-vs-merge-commit logic from scripts/generate-ir-tags.sh /
  /// generate-rc-tags.sh. One git call regardless of how many commits match.
  Future<List<String>> prTitlesBetween(String from, String to);
}

class ProcessGitClient implements GitClient {
  ProcessGitClient({this.workingDirectory});

  final String? workingDirectory;

  /// Separates hash/subject/body within one commit record in [prTitlesBetween]'s
  /// custom `git log` format. Chosen because it can never appear in a real
  /// commit message, unlike `\n` (which the body itself may contain).
  static const _unitSep = '\x1f';

  /// Separates one commit record from the next.
  static const _recordSep = '\x1e';

  Future<ProcessResult> _run(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: workingDirectory);
    if (result.exitCode != 0) {
      throw ProcessException('git', args, result.stderr.toString(), result.exitCode);
    }
    return result;
  }

  @override
  Future<void> fetchTags() async {
    await _run(['fetch', '--tags', '--quiet']);
  }

  @override
  Future<List<MapEntry<String, DateTime>>> tagsMatching(String glob) async {
    final result = await _run([
      'for-each-ref',
      'refs/tags/$glob',
      '--sort=creatordate',
      "--format=%(refname:short)\t%(creatordate:iso-strict)",
    ]);
    final lines = (result.stdout as String).split('\n').where((l) => l.trim().isNotEmpty);
    return lines.map((line) {
      final parts = line.split('\t');
      return MapEntry(parts[0], DateTime.parse(parts[1]));
    }).toList();
  }

  @override
  Future<List<String>> prTitlesBetween(String from, String to) async {
    final result = await _run([
      'log',
      '$from..$to',
      '-E',
      '--format=%H$_unitSep%s$_unitSep%b$_recordSep',
      r'--grep=\(#[0-9]+\)$',
      '--grep=^Merge pull request',
    ]);
    final records = (result.stdout as String)
        .split(_recordSep)
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty);

    final titles = <String>[];
    for (final record in records) {
      final parts = record.split(_unitSep);
      final subject = parts.length > 1 ? parts[1] : '';
      final body = parts.length > 2 ? parts[2] : '';
      if (subject.startsWith('Merge pull request')) {
        final firstLine = body
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty, orElse: () => subject);
        titles.add(firstLine);
      } else {
        titles.add(subject);
      }
    }
    return titles;
  }
}
