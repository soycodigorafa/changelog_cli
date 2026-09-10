import 'package:nocterm/nocterm.dart';

import 'theme.dart';

/// "Last sync: 2026-09-02 14:32" or "Not synced yet — run Sync from the
/// app picker", shown near the top of every screen.
/// There's no live re-check of git here — [lastFullSyncAt] is just the
/// timestamp of the last completed full sync — so the color is a freshness
/// signal based on how long ago that was, not proof the tags are current:
/// green within [_freshWindow], yellow within [_staleWindow], red beyond it
/// (or if a sync has never completed).
class StatusLine extends StatelessComponent {
  const StatusLine({required this.lastFullSyncAt, super.key});

  final DateTime? lastFullSyncAt;

  static const _freshWindow = Duration(hours: 12);
  static const _staleWindow = Duration(days: 3);

  @override
  Component build(BuildContext context) {
    final syncedAt = lastFullSyncAt;
    if (syncedAt == null) {
      return const Text(
        'Not synced yet — run Sync from the app picker',
        style: TextStyle(color: AppColors.danger),
      );
    }
    final age = DateTime.now().difference(syncedAt);
    final color = age <= _freshWindow
        ? AppColors.success
        : age <= _staleWindow
            ? AppColors.warning
            : AppColors.danger;
    return Text(
      'Last sync: ${_formatDateTime(syncedAt)}',
      style: TextStyle(color: color),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
}
