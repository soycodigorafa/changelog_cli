import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
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
    required this.lastFullSyncAt,
    required this.onBack,
  });

  final AppEntry app;
  final GitClient git;
  final DateTime? lastFullSyncAt;
  final void Function() onBack;

  @override
  State<UpcomingView> createState() => _UpcomingViewState();
}

class _UpcomingViewState extends State<UpcomingView> {
  final ScrollController _scrollController = ScrollController();

  List<UpcomingSection>? sections;
  String? error;

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

  void _scrollBy(double delta) {
    _scrollController.jumpTo(_scrollController.offset + delta);
  }

  void _copyAll() {
    final loaded = sections;
    if (loaded == null) return;
    final text = loaded.expand((s) => s.prTitles).join('\n');
    if (text.isEmpty) return;
    ClipboardManager.copy(text);
  }

  bool _onKeyEvent(KeyboardEvent event) {
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
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('${component.app.folderName} — Upcoming'),
        StatusLine(lastFullSyncAt: component.lastFullSyncAt),
      ],
    );

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

    return ScreenScaffold(
      onKeyEvent: _onKeyEvent,
      header: header,
      body: CopyableScrollBody(
        controller: _scrollController,
        children: [
          for (final section in loaded) ...[
            PrTitleSection(
              tagLabel: '${component.app.displayName} ${section.sinceTag.versionLabel}-${section.type}'
                  '  (upcoming since ${section.sinceTag.rawTag})',
              titles: section.prTitles,
            ),
            AppSpacing.gap,
          ],
        ],
      ),
      footer: const FooterHint('↑/↓/PgUp/PgDn scroll   c copy all   drag to copy   Esc back   q quit'),
    );
  }
}
