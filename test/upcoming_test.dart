import 'package:changelog_cli/src/app_registry.dart';
import 'package:changelog_cli/src/git_client.dart';
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
    final irPr = PrMergeInfo(title: 'TASK-1-[BE] unreleased IR change (#201)', mergedAt: d(5));
    final rcPr = PrMergeInfo(title: 'TASK-2-[FE] unreleased RC change (#202)', mergedAt: d(6));
    final git = FakeGitClient(
      tags: [
        MapEntry(irTag, d(1)),
        MapEntry(rcOld, d(2)),
        MapEntry(rcNew, d(3)),
      ],
      prDetails: {
        '$irTag..HEAD': [irPr],
        '$rcNew..HEAD': [rcPr],
      },
    );

    final sections = await buildUpcomingByType(git, app);

    expect(sections.map((s) => s.type).toList(), ['IR', 'RC']);
    expect(sections[0].sinceTag.rawTag, irTag);
    expect(sections[0].prs, [irPr]);
    expect(sections[0].prs.single.mergedAt, d(5));
    // RC has two tags; must diff from the newest (rcNew), not rcOld.
    expect(sections[1].sinceTag.rawTag, rcNew);
    expect(sections[1].prs, [rcPr]);
    expect(sections[1].prs.single.mergedAt, d(6));
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

  test('buildUpcomingByType passes "HEAD" through to prDetailsBetween literally', () async {
    final pr = PrMergeInfo(title: 'TASK-3 some change (#301)', mergedAt: d(2));
    final git = FakeGitClient(
      tags: [MapEntry(rcNew, d(1))],
      prDetails: {'$rcNew..HEAD': [pr]},
    );
    final sections = await buildUpcomingByType(git, app);
    expect(sections.single.prs, [pr]);
  });

  test('buildUpcomingByType returns an empty prs list, not a crash, '
      'when nothing merged since the latest tag', () async {
    final git = FakeGitClient(tags: [MapEntry(rcNew, d(1))]);
    final sections = await buildUpcomingByType(git, app);
    expect(sections.single.prs, isEmpty);
  });
}
