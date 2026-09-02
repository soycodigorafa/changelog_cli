import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/changelog.dart';
import 'package:changelog_cli/src/formatter.dart';
import 'package:test/test.dart';

import 'fake_git_client.dart';

void main() {
  final app = AppEntry(folderName: 'zz_sample', tagFormat: 'ZZ_Sample', displayName: 'Sample');

  final rcOld = 'RC_ZZ_Sample_v4.1.5+40000070';
  final rcNew = 'RC_ZZ_Sample_v4.1.6+40000072';
  final irOld = 'IR_ZZ_Sample_v0.18.15';
  final irNew = 'IR_ZZ_Sample_v0.18.16+82';

  DateTime d(int day) => DateTime(2026, 1, day);

  test('loadTags sorts chronologically across IR and RC and applies range', () async {
    final git = FakeGitClient(tags: [
      MapEntry(rcNew, d(4)),
      MapEntry(irOld, d(1)),
      MapEntry(rcOld, d(3)),
      MapEntry(irNew, d(2)),
    ]);

    final tags = await loadTags(git, app);
    expect(tags.map((t) => t.rawTag).toList(), [irOld, irNew, rcOld, rcNew]);

    final ranged = await loadTags(git, app, from: rcOld, to: rcNew);
    expect(ranged.map((t) => t.rawTag).toList(), [rcOld, rcNew]);
  });

  test('loadTags --type filters out the other tag types', () async {
    final git = FakeGitClient(tags: [
      MapEntry(rcOld, d(1)),
      MapEntry(irNew, d(2)),
    ]);
    final tags = await loadTags(git, app, typeFilter: 'rc');
    expect(tags.map((t) => t.rawTag).toList(), [rcOld]);
  });

  test('buildChangelog attaches PR titles between adjacent tags, empty for the first', () async {
    final git = FakeGitClient(
      tags: [MapEntry(rcOld, d(1)), MapEntry(rcNew, d(2))],
      prTitles: {
        '$rcOld..$rcNew': ['TASK-1 first change (#101)', 'TASK-2 second change (#102)'],
      },
    );
    final tags = await loadTags(git, app);
    final entries = await buildChangelog(git, tags);

    expect(entries[0].prTitles, isEmpty);
    expect(entries[1].prTitles, [
      'TASK-1 first change (#101)',
      'TASK-2 second change (#102)',
    ]);
  });

  test('filterByTicketPrefix keeps only matching PR titles', () async {
    final git = FakeGitClient(
      tags: [MapEntry(rcOld, d(1)), MapEntry(rcNew, d(2))],
      prTitles: {
        '$rcOld..$rcNew': ['TASK-1 something', 'BUG-2 something else'],
      },
    );
    final tags = await loadTags(git, app);
    final entries = await buildChangelog(git, tags);

    final filtered = filterByTicketPrefix(entries, 'TASK');
    expect(filtered.last.prTitles, ['TASK-1 something']);
  });

  test('formatChangelog renders the manual-changelog style, including empty tags', () async {
    final git = FakeGitClient(
      tags: [MapEntry(rcOld, d(1)), MapEntry(rcNew, d(2))],
      prTitles: {'$rcOld..$rcNew': ['TASK-1 some title (#101)']},
    );
    final tags = await loadTags(git, app);
    final entries = await buildChangelog(git, tags);
    final output = formatChangelog(app, entries, OutputFormat.markdown);

    expect(output, '''
## Sample v4.1.5+40000070-RC

## Sample v4.1.6+40000072-RC
- TASK-1 some title (#101)''');
  });
}
