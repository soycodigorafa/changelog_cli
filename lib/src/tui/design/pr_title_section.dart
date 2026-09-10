import 'package:nocterm/nocterm.dart';

import '../../changelog.dart';
import 'theme.dart';

/// A bold tag headline (e.g. `some_app v1.2.3-RC`) followed by every PR
/// title merged under it, each with its `[TAG]` groups (or `NO-TAGS`) on
/// their own uppercased line above the title, tags stripped out of the
/// title itself. Shared by the changelog detail screen and the search
/// results screen.
class PrTitleSection extends StatelessComponent {
  const PrTitleSection({required this.tagLabel, required this.titles, super.key});

  final String tagLabel;
  final List<String> titles;

  @override
  Component build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tagLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
        AppSpacing.gap,
        for (final title in titles) ...[
          _PrTitleLine(title),
          AppSpacing.gap,
        ],
      ],
    );
  }
}

class _PrTitleLine extends StatelessComponent {
  const _PrTitleLine(this.title);

  final String title;

  @override
  Component build(BuildContext context) {
    final tags = extractBracketTags(title);
    final header = tags.isEmpty ? 'NO-TAGS' : tags.map((t) => t.toUpperCase()).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('  $header', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        Text('  - ${stripBracketTags(title)}'),
      ],
    );
  }
}
