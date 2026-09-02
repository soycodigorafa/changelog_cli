import 'package:nocterm/nocterm.dart';

import '../cache.dart';

/// "87% synced (522/600 tags) · Fully synced — last full sync: 2026-09-02
/// 14:32" or "· Not synced yet — run Sync from the app picker", shown near
/// the top of every screen. "Fully synced" just means "a full sync has
/// completed at least once" — it does not re-check whether new tags have
/// appeared since; the percentage comes from [stats], persisted by every
/// sync run (full or partial/canceled).
Component buildSyncStatusLine(DateTime? lastFullSyncAt, SyncStats? stats) {
  final percentPart = stats == null || stats.totalTags == 0
      ? ''
      : '${((stats.cachedTags / stats.totalTags) * 100).round()}% synced '
          '(${stats.cachedTags}/${stats.totalTags} tags) · ';
  final text = lastFullSyncAt == null
      ? '${percentPart}Not synced yet — run Sync from the app picker'
      : '${percentPart}Fully synced — last full sync: ${_formatDateTime(lastFullSyncAt)}';
  return Text(text, style: TextStyle(color: lastFullSyncAt == null ? Colors.brightRed : Colors.brightGreen));
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
}
