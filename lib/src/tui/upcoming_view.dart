import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../changelog.dart';
import '../git_client.dart';
import '../upcoming.dart';
import 'design/design.dart';

/// Reachable from the type picker's `Upcoming` entry: shows, grouped per
/// tag type that exists for [app], the PR titles merged since that type's
/// own latest tag up to `HEAD`. Always computed live from git — never reads
/// or writes `ChangelogCache` (see `lib/src/cache.dart`), because this
/// range's answer changes on every new commit.
class UpcomingView extends StatefulComponent {
  const UpcomingView({
    super.key,
    required this.app,
    required this.git,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final void Function() onBack;

  @override
  State<UpcomingView> createState() => _UpcomingViewState();
}

class _UpcomingViewState extends State<UpcomingView> {
  final ScrollController _scrollController = ScrollController();

  List<UpcomingSection>? sections;
  String? error;

  /// `/` filters by ticket number or `[tag]`, same matching as
  /// `changelog_view.dart`'s `/` filter, applied within each section.
  bool editingQuery = false;
  String queryText = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await buildUpcomingByType(component.git, component.app);
      setState(() => sections = loaded);
    } catch (e) {
      setState(() => error = '$e');
    }
  }

  /// [sections] with [queryText] applied per type: PRs that don't match are
  /// dropped, and a section with no matching PRs left is dropped entirely.
  /// Unfiltered (and in the original, already-newest-first order) when
  /// [queryText] is empty.
  List<UpcomingSection> get _visibleSections {
    final loaded = sections!;
    if (queryText.isEmpty) return loaded;
    return loaded
        .map((s) => UpcomingSection(
              type: s.type,
              sinceTag: s.sinceTag,
              prs: s.prs.where((p) => matchesTicketOrTagQuery(p.title, queryText)).toList(),
            ))
        .where((s) => s.prs.isNotEmpty)
        .toList();
  }

  String? get _queryLineText {
    if (editingQuery) return 'Filter (ticket # or [tag]): $queryText';
    if (queryText.isEmpty) return null;
    return '[filter: $queryText]';
  }

  String get _footerText {
    if (editingQuery) return 'Type to edit   Enter confirm   Esc cancel';
    return '↑/↓/PgUp/PgDn scroll   / filter   c copy all   drag to copy   Esc back   q quit';
  }

  void _scrollBy(double delta) {
    _scrollController.jumpTo(_scrollController.offset + delta);
  }

  void _copyAll() {
    if (sections == null) return;
    final text = _visibleSections.expand((s) => s.prs).map((p) => p.title).join('\n');
    if (text.isEmpty) return;
    ClipboardManager.copy(text);
  }

  bool _onKeyEvent(KeyboardEvent event) {
    if (editingQuery) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() {
          editingQuery = false;
          queryText = '';
        });
        return true;
      }
      if (event.logicalKey == LogicalKey.enter) {
        setState(() => editingQuery = false);
        return true;
      }
      if (event.logicalKey == LogicalKey.backspace) {
        if (queryText.isNotEmpty) {
          setState(() => queryText = queryText.substring(0, queryText.length - 1));
        }
        return true;
      }
      if (event.character != null && event.character!.isNotEmpty) {
        setState(() => queryText += event.character!);
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKey.arrowDown) {
      _scrollBy(1);
      return true;
    }
    if (event.logicalKey == LogicalKey.arrowUp) {
      _scrollBy(-1);
      return true;
    }
    if (event.logicalKey == LogicalKey.pageDown) {
      _scrollBy(10);
      return true;
    }
    if (event.logicalKey == LogicalKey.pageUp) {
      _scrollBy(-10);
      return true;
    }
    if (event.logicalKey == LogicalKey.slash) {
      setState(() => editingQuery = true);
      return true;
    }
    if (event.character == 'c') {
      _copyAll();
      return true;
    }
    if (event.logicalKey == LogicalKey.escape) {
      component.onBack();
      return true;
    }
    if (event.logicalKey == LogicalKey.keyQ) {
      shutdownApp();
      return true;
    }
    return false;
  }

  @override
  Component build(BuildContext context) {
    final header = ScreenHeader(title: '${component.app.folderName} — Upcoming');

    if (error != null) {
      return ScreenScaffold(
        onKeyEvent: (_) => false,
        header: header,
        body: ErrorText('Error loading upcoming changes: $error'),
        footer: const FooterHint(''),
      );
    }

    final loaded = sections;
    if (loaded == null) {
      return ScreenScaffold(
        onKeyEvent: (_) => false,
        header: header,
        body: const LoadingText('Loading upcoming changes...'),
        footer: const FooterHint(''),
      );
    }

    if (loaded.isEmpty) {
      return ScreenScaffold(
        onKeyEvent: _onKeyEvent,
        header: header,
        body: BodyText('No tags exist yet for ${component.app.folderName} — nothing to compare against.'),
        footer: const FooterHint('Esc back   q quit'),
      );
    }

    final visible = _visibleSections;
    final queryLine = _queryLineText;
    return ScreenScaffold(
      onKeyEvent: _onKeyEvent,
      header: header,
      body: CopyableScrollBody(
        controller: _scrollController,
        children: [
          if (queryLine != null) ...[
            BodyText(queryLine),
            AppSpacing.gap,
          ],
          if (visible.isEmpty)
            BodyText('No match for "$queryText" in any upcoming section.')
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) ...[const AppDivider(), AppSpacing.gap],
              _UpcomingSectionHeader(section: visible[i]),
              AppSpacing.gap,
              for (final pr in visible[i].prs) ...[
                _UpcomingPrLine(pr),
                AppSpacing.gap,
              ],
            ],
        ],
      ),
      footer: FooterHint(_footerText),
    );
  }
}

/// A type's bold `"$type — N pending changes"` (or `"— up to date"`) line,
/// followed by a muted `"since <tag> (cut <date>, <relative>)"` line so it's
/// obvious which tag boundary a section's PRs are measured from.
class _UpcomingSectionHeader extends StatelessComponent {
  const _UpcomingSectionHeader({required this.section});

  final UpcomingSection section;

  @override
  Component build(BuildContext context) {
    final count = section.prs.length;
    final countLabel = count == 0
        ? '${section.type} — up to date'
        : '${section.type} — $count pending change${count == 1 ? '' : 's'}';
    final tag = section.sinceTag;
    final sinceLabel = 'since ${tag.rawTag} (cut ${_formatDate(tag.createdAt)}, ${_formatRelativeAge(tag.createdAt)})'
        '${count == 0 ? ' — no changes yet' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(countLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.warning)),
        Text(sinceLabel, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

/// Same `[TAG]` header + `- title` shape as the shared `PrTitleSection`
/// (see `design/pr_title_section.dart`), with the PR's merge date and
/// relative age appended to the title line.
class _UpcomingPrLine extends StatelessComponent {
  const _UpcomingPrLine(this.pr);

  final PrMergeInfo pr;

  @override
  Component build(BuildContext context) {
    final tags = extractBracketTags(pr.title);
    final header = tags.isEmpty ? 'NO-TAGS' : tags.map((t) => t.toUpperCase()).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('  $header', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        Text('  - ${stripBracketTags(pr.title)}   · ${_formatDate(pr.mergedAt)} (${_formatRelativeAge(pr.mergedAt)})'),
      ],
    );
  }
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)}';
}

/// `"just now"`, `"4 hours ago"`, `"4 days ago"`, `"2 months ago"`,
/// `"1 year ago"` — coarse enough to answer "is this old?" at a glance.
String _formatRelativeAge(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) {
    final years = diff.inDays ~/ 365;
    return years == 1 ? '1 year ago' : '$years years ago';
  }
  if (diff.inDays >= 30) {
    final months = diff.inDays ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }
  if (diff.inDays >= 1) {
    return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
  }
  if (diff.inHours >= 1) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  return 'just now';
}
