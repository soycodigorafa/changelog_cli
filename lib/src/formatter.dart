import 'app_registry.dart';
import 'changelog.dart';
import 'tag_info.dart';

enum OutputFormat { markdown, text }

OutputFormat parseOutputFormat(String value) {
  switch (value.toLowerCase()) {
    case 'text':
      return OutputFormat.text;
    case 'markdown':
      return OutputFormat.markdown;
    default:
      throw ArgumentError('Unknown format "$value", expected markdown or text');
  }
}

/// Renders [entries] in the same style as the hand-written changelog:
/// a header per tag followed by a bullet per merged PR, with an empty body
/// left for tags that had no new PRs since the previous one.
String formatChangelog(AppEntry app, List<ChangelogEntry> entries, OutputFormat format) {
  final buffer = StringBuffer();
  for (final entry in entries) {
    final header = '${app.displayName} ${entry.tag.versionLabel}-${entry.tag.type}';
    buffer.writeln(format == OutputFormat.markdown ? '## $header' : header);
    for (final title in entry.prTitles) {
      buffer.writeln(format == OutputFormat.markdown ? '- $title' : title);
    }
    buffer.writeln();
  }
  return buffer.toString().trimRight();
}

String formatTagList(AppEntry app, List<TagInfo> entries) {
  final buffer = StringBuffer();
  for (final tag in entries) {
    buffer.writeln('${tag.rawTag}\t${tag.type}\t${tag.versionLabel}\t${tag.createdAt.toIso8601String()}');
  }
  return buffer.toString().trimRight();
}
