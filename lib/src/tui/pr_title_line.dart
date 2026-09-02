import 'package:nocterm/nocterm.dart';

import '../changelog.dart';

/// Renders one PR title with its `[TAG]` groups (or `NO-TAGS`) on their own
/// uppercased line above the title, tags stripped out of the title itself.
/// Shared by the changelog detail screen and the search results screen.
Component buildPrTitleLine(String title) {
  final tags = extractBracketTags(title);
  final header = tags.isEmpty ? 'NO-TAGS' : tags.map((t) => t.toUpperCase()).join(' ');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '  $header',
        style: const TextStyle(color: Colors.brightWhite, fontWeight: FontWeight.bold),
      ),
      Text('  - ${stripBracketTags(title)}'),
    ],
  );
}
