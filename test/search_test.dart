import 'dart:io';

import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/cache.dart';
import 'package:changelog_cli/src/search.dart';
import 'package:test/test.dart';

import 'fake_git_client.dart';

void main() {
  final app = AppEntry(folderName: 'zz_sample', tagFormat: 'ZZ_Sample', displayName: 'Sample');

  final irOld = 'IR_ZZ_Sample_v0.18.14';
  final irNew = 'IR_ZZ_Sample_v0.18.15';
  final rcOld = 'RC_ZZ_Sample_v4.1.5+40000070';
  final rcNew = 'RC_ZZ_Sample_v4.1.6+40000072';

  final now = DateTime.now();
  DateTime daysAgo(int n) => now.subtract(Duration(days: n));

  FakeGitClient buildGit() => FakeGitClient(
        tags: [
          MapEntry(irOld, daysAgo(100)),
          MapEntry(irNew, daysAgo(50)),
          MapEntry(rcOld, daysAgo(40)),
          MapEntry(rcNew, daysAgo(5)),
        ],
        prTitles: {
          '$irOld..$irNew': ['TASK-1234-[BE] old change (#99)'],
          '$rcOld..$rcNew': ['TASK-1234-[FE] some change (#101)'],
        },
      );

  test('searchAcrossTags finds matches across every type, grouped by exact type', () async {
    final matches = await searchAcrossTags(buildGit(), app, 'TASK-1234');

    expect(matches.map((m) => m.type).toList(), ['IR', 'RC']);
    expect(matches[0].tag.rawTag, irNew);
    expect(matches[0].matchedTitles, ['TASK-1234-[BE] old change (#99)']);
    expect(matches[1].tag.rawTag, rcNew);
    expect(matches[1].matchedTitles, ['TASK-1234-[FE] some change (#101)']);
  });

  test('searchAcrossTags excludes tags created before the "within" cutoff', () async {
    final matches = await searchAcrossTags(buildGit(), app, 'TASK-1234', within: const Duration(days: 30));

    expect(matches.map((m) => m.type).toList(), ['RC']);
    expect(matches.single.tag.rawTag, rcNew);
  });

  test('searchAcrossTags respects typeFilter', () async {
    final matches = await searchAcrossTags(buildGit(), app, 'TASK-1234', typeFilter: 'rc');

    expect(matches.map((m) => m.type).toList(), ['RC']);
  });

  test('searchAcrossTags returns empty when nothing matches', () async {
    final matches = await searchAcrossTags(buildGit(), app, 'no-such-ticket');

    expect(matches, isEmpty);
  });

  test('searchAcrossTags reads from the cache instead of hitting git when present', () async {
    final cache = await ChangelogCache.load(File('${Directory.systemTemp.path}/does-not-exist-search-cache-test.json'));
    cache.put(irNew, ['TASK-1234-[BE] old change (#99)']);
    cache.put(rcNew, ['TASK-1234-[FE] some change (#101)']);

    // Same tags, but no prTitles configured: a live diff would find no
    // matching PR titles for these tags.
    final gitWithNoData = FakeGitClient(tags: [
      MapEntry(irOld, daysAgo(100)),
      MapEntry(irNew, daysAgo(50)),
      MapEntry(rcOld, daysAgo(40)),
      MapEntry(rcNew, daysAgo(5)),
    ]);

    final matches = await searchAcrossTags(gitWithNoData, app, 'TASK-1234', cache: cache);

    expect(matches.map((m) => m.type).toList(), ['IR', 'RC']);
    expect(matches[0].matchedTitles, ['TASK-1234-[BE] old change (#99)']);
    expect(matches[1].matchedTitles, ['TASK-1234-[FE] some change (#101)']);
  });
}
