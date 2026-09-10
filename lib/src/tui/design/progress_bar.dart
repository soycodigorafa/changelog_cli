import 'package:nocterm/nocterm.dart';

/// ASCII progress bar: `[####----] NN% (completed/total)`. Named
/// `SyncProgressBar` (not `ProgressBar`) because nocterm's own barrel
/// already exports a `ProgressBar` widget.
class SyncProgressBar extends StatelessComponent {
  const SyncProgressBar({required this.completed, required this.total, this.width = 30, super.key});

  final int completed;
  final int total;
  final int width;

  @override
  Component build(BuildContext context) {
    if (total == 0) return Text('[${'#' * width}] 100%');
    final fraction = completed / total;
    final filled = (fraction * width).round().clamp(0, width);
    final bar = '${'#' * filled}${'-' * (width - filled)}';
    return Text('[$bar] ${(fraction * 100).round()}% ($completed/$total)');
  }
}
