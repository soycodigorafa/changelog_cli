/// Parses a `--since` value into a lookback [Duration], or `null` for `max`
/// (no limit — search full history). Accepts `max`, a bare unit (`day`,
/// `week`, `month`, `year`), or `<n> <unit>` (`2 days`, `365 days`, `1 year`).
Duration? parseTimeRange(String input) {
  final trimmed = input.trim().toLowerCase();
  if (trimmed == 'max') return null;

  final match = RegExp(r'^(\d+)?\s*(day|days|week|weeks|month|months|year|years)$').firstMatch(trimmed);
  if (match == null) {
    throw ArgumentError(
      'Invalid time range "$input", expected e.g. "day", "2 weeks", "365 days", "1 year", or "max"',
    );
  }

  final count = int.parse(match.group(1) ?? '1');
  final unitDays = switch (match.group(2)!) {
    'day' || 'days' => 1,
    'week' || 'weeks' => 7,
    'month' || 'months' => 30,
    'year' || 'years' => 365,
    _ => throw StateError('unreachable'),
  };
  return Duration(days: count * unitDays);
}
