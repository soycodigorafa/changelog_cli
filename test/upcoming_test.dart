import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/upcoming.dart';
import 'package:test/test.dart';

import 'fake_git_client.dart';

void main() {
  final app = AppEntry(folderName: 'zz_sample', tagFormat: 'ZZ_Sample', displayName: 'Sample');

  final irTag = 'IR_ZZ_Sample_v0.18.15';
  final rcOld = 'RC_ZZ_Sample_v4.1.5+40000070';
  final rcNew = 'RC_ZZ_Sample_v4.1.6+40000072';

  DateTime d(int day) => DateTime(2026, 1, day);

  test("buildUpcomingByType diffs each type's own latest tag to HEAD", () async {
    final git = FakeGitClient(
      tags: [
        MapEntry(irTag, d(1)),
        MapEntry(rcOld, d(2)),
        MapEntry(rcNew, d(3)),
      ],
      prTitles: {
        '$irTag..HEAD': ['TASK-1-[BE] unreleased IR change (#201)'],
        '$rcNew..HEAD': ['TASK-2-[FE] unreleased RC change (#202)'],
      },
    );

    final sections = await buildUpcomingByType(git, app);

    expect(sections.map((s) => s.type).toList(), ['IR', 'RC']);
    expect(sections[0].sinceTag.rawTag, irTag);
    expect(sections[0].prTitles, ['TASK-1-[BE] unreleased IR change (#201)']);
    // RC has two tags; must diff from the newest (rcNew), not rcOld.
    expect(sections[1].sinceTag.rawTag, rcNew);
    expect(sections[1].prTitles, ['TASK-2-[FE] unreleased RC change (#202)']);
  });

  test('buildUpcomingByType skips types with no tags at all', () async {
    final git = FakeGitClient(tags: [MapEntry(irTag, d(1))]);
    final sections = await buildUpcomingByType(git, app);
    expect(sections.map((s) => s.type).toList(), ['IR']);
  });

  test('buildUpcomingByType returns an empty list when the app has no tags yet', () async {
    final sections = await buildUpcomingByType(FakeGitClient(tags: const []), app);
    expect(sections, isEmpty);
  });

  test('buildUpcomingByType passes "HEAD" through to prTitlesBetween literally', () async {
    final git = FakeGitClient(
      tags: [MapEntry(rcNew, d(1))],
      prTitles: {'$rcNew..HEAD': ['TASK-3 some change (#301)']},
    );
    final sections = await buildUpcomingByType(git, app);
    expect(sections.single.prTitles, ['TASK-3 some change (#301)']);
  });

  test('buildUpcomingByType returns an empty prTitles list, not a crash, '
      'when nothing merged since the latest tag', () async {
    final git = FakeGitClient(tags: [MapEntry(rcNew, d(1))]);
    final sections = await buildUpcomingByType(git, app);
    expect(sections.single.prTitles, isEmpty);
  });
}
