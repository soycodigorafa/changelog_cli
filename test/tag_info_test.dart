import 'package:changelog_cli/src/tag_info.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  test('parses a plain RC tag', () {
    final tag = TagInfo.parse('RC_ZZ_Sample_v4.1.6+40000072', now, 'ZZ_Sample')!;
    expect(tag.kind, 'RC');
    expect(tag.subtype, isNull);
    expect(tag.type, 'RC');
    expect(tag.version, '4.1.6');
    expect(tag.build, '40000072');
    expect(tag.versionLabel, 'v4.1.6+40000072');
  });

  test('parses an IR tag without a build number', () {
    final tag = TagInfo.parse('IR_ZZ_Sample_v0.18.15', now, 'ZZ_Sample')!;
    expect(tag.kind, 'IR');
    expect(tag.build, isNull);
    expect(tag.versionLabel, 'v0.18.15');
  });

  test('parses a QA sub-type tag', () {
    final tag = TagInfo.parse('IR_YY_Demo_QA_v0.18.16+82', now, 'YY_Demo')!;
    expect(tag.kind, 'IR');
    expect(tag.subtype, 'QA');
    expect(tag.type, 'IR_QA');
  });

  test('parses a store sub-type tag', () {
    final tag = TagInfo.parse('RC_ZZ_Sample_store_v4.1.6+40000072', now, 'ZZ_Sample')!;
    expect(tag.type, 'RC_store');
  });

  test('returns null for a different app', () {
    expect(TagInfo.parse('RC_QQ_Other_v1.0.0+1', now, 'ZZ_Sample'), isNull);
  });

  test('type filter is case-insensitive', () {
    final tag = TagInfo.parse('RC_ZZ_Sample_v4.1.6+40000072', now, 'ZZ_Sample')!;
    expect(tag.matchesTypeFilter('rc'), isTrue);
    expect(tag.matchesTypeFilter('ir'), isFalse);
    expect(tag.matchesTypeFilter('all'), isTrue);
  });
}
