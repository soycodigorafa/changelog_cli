/// A parsed git tag for a single app, e.g. `RC_ZZ_Sample_v4.1.6+40000072`
/// or `IR_ZZ_Sample_QA_v0.18.16+82`.
class TagInfo {
  TagInfo({
    required this.rawTag,
    required this.kind,
    required this.subtype,
    required this.version,
    required this.build,
    required this.createdAt,
  });

  final String rawTag;

  /// `IR` or `RC`.
  final String kind;

  /// Optional sub-type appended after the app format, e.g. `QA` or `store`.
  final String? subtype;

  final String version;

  /// Build number, if the tag has one (older IR tags may omit it).
  final String? build;

  final DateTime createdAt;

  /// Combined type label used for filtering/grouping, e.g. `IR`, `RC`, `RC_store`, `IR_QA`.
  String get type => subtype == null ? kind : '${kind}_$subtype';

  /// Matches --type filter values case-insensitively (`rc`, `rc_store`, `ir_qa`, ...).
  bool matchesTypeFilter(String filter) {
    if (filter.toLowerCase() == 'all') return true;
    return type.toLowerCase() == filter.toLowerCase();
  }

  static TagInfo? parse(String rawTag, DateTime createdAt, String appTagFormat) {
    final escapedAppFormat = RegExp.escape(appTagFormat);
    final pattern = RegExp(
      r'^([A-Za-z]+)_' + escapedAppFormat + r'(?:_([A-Za-z]+))?_v([0-9]+(?:\.[0-9]+)*)(?:\+([0-9]+))?$',
    );
    final match = pattern.firstMatch(rawTag);
    if (match == null) return null;
    return TagInfo(
      rawTag: rawTag,
      kind: match.group(1)!,
      subtype: match.group(2),
      version: match.group(3)!,
      build: match.group(4),
      createdAt: createdAt,
    );
  }

  /// The `v<version>[+<build>]` fragment as printed in the manual changelog.
  String get versionLabel => build == null ? 'v$version' : 'v$version+$build';
}
