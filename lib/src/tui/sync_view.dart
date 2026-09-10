import 'dart:io';

import 'package:nocterm/nocterm.dart';

import '../app_registry.dart';
import '../cache.dart';
import '../git_client.dart';
import '../sync.dart';
import 'design/design.dart';

/// Reachable from the app picker's `Sync all apps` entry: runs [syncAll]
/// for every app, showing a progress bar and a `Scanning...` line while it
/// runs. `p` pauses/resumes, `Esc` cancels (whatever was already cached
/// before pausing/canceling is still saved). Once done — completed or
/// canceled — any key returns.
class SyncView extends StatefulComponent {
  const SyncView({
    super.key,
    required this.apps,
    required this.git,
    required this.cacheDir,
    required this.onDone,
  });

  final List<AppEntry> apps;
  final GitClient git;
  final Directory cacheDir;
  final void Function() onDone;

  @override
  State<SyncView> createState() => _SyncViewState();
}

class _SyncViewState extends State<SyncView> {
  final SyncController _controller = SyncController();

  int completed = 0;
  int total = 0;
  int alreadyCached = 0;
  String currentLabel = '';
  bool paused = false;
  bool done = false;
  List<SyncResult> results = const [];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final syncResults = await syncAll(
      component.git,
      component.apps,
      component.cacheDir,
      controller: _controller,
      onStart: (already, totalTags) {
        setState(() {
          alreadyCached = already;
          total = totalTags;
        });
      },
      onProgress: (progress) {
        setState(() {
          completed = progress.completed;
          total = progress.total;
          currentLabel = '${progress.appLabel} ${progress.tagLabel}';
        });
      },
    );
    if (!_controller.isCancelled) {
      await recordFullSync(component.cacheDir);
    }
    setState(() {
      results = syncResults;
      done = true;
    });
  }

  void _togglePause() {
    setState(() {
      if (paused) {
        _controller.resume();
      } else {
        _controller.pause();
      }
      paused = !paused;
    });
  }

  void _cancel() {
    setState(() {
      paused = false;
      _controller.cancel();
    });
  }

  String get _statusLine {
    if (_controller.isCancelled) return 'Canceling...';
    if (paused) return currentLabel.isEmpty ? 'Paused' : 'Paused — $currentLabel';
    return currentLabel.isEmpty ? 'Scanning...' : 'Scanning... $currentLabel';
  }

  bool _onKeyEvent(KeyboardEvent event) {
    if (!done) {
      if (event.character == 'p') {
        _togglePause();
        return true;
      }
      if (event.logicalKey == LogicalKey.escape || event.character == 'c') {
        _cancel();
        return true;
      }
      return true; // swallow everything else while running, nothing else to do
    }
    component.onDone();
    return true;
  }

  @override
  Component build(BuildContext context) {
    return ScreenScaffold(
      onKeyEvent: _onKeyEvent,
      header: const SectionHeader('Syncing all apps'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!done) ...[
            if (total > 0)
              FooterHint(
                '$alreadyCached of $total tags already cached — syncing the remaining '
                '${total - alreadyCached}...',
              ),
            SyncProgressBar(completed: completed, total: total),
            BodyText(_statusLine),
          ] else ...[
            SectionHeader(
              _controller.isCancelled ? 'Canceled.' : 'Done.',
              color: _controller.isCancelled ? AppColors.warning : AppColors.success,
            ),
            AppSpacing.gap,
            for (final result in results)
              BodyText(
                result.newlyCached == 0
                    ? '${result.app.displayName}: up to date (${result.totalCached} tags cached)'
                    : '${result.app.displayName}: +${result.newlyCached} new tags cached (${result.totalCached} total)',
              ),
          ],
        ],
      ),
      footer: FooterHint(done ? 'Press any key to go back' : 'p pause/resume   Esc cancel'),
    );
  }
}
