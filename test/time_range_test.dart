import 'package:changelog_cli/src/time_range.dart';
import 'package:test/test.dart';

void main() {
  test('parseTimeRange("max") returns null (no limit)', () {
    expect(parseTimeRange('max'), isNull);
    expect(parseTimeRange('MAX'), isNull);
  });

  test('parseTimeRange accepts a bare unit, defaulting to 1', () {
    expect(parseTimeRange('day'), const Duration(days: 1));
    expect(parseTimeRange('week'), const Duration(days: 7));
    expect(parseTimeRange('month'), const Duration(days: 30));
    expect(parseTimeRange('year'), const Duration(days: 365));
  });

  test('parseTimeRange accepts "<n> <unit>"', () {
    expect(parseTimeRange('2 days'), const Duration(days: 2));
    expect(parseTimeRange('365 days'), const Duration(days: 365));
    expect(parseTimeRange('1 year'), const Duration(days: 365));
  });

  test('parseTimeRange throws on garbage input', () {
    expect(() => parseTimeRange('whenever'), throwsArgumentError);
    expect(() => parseTimeRange(''), throwsArgumentError);
  });
}
