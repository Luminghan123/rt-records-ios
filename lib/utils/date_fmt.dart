const List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

String _two(int v) => v.toString().padLeft(2, '0');

/// 2026-11-05 22:14（可存进 JSON，也能按字符串排序）
String formatStamp(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

DateTime? parseStamp(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  try {
    final parts = s.trim().split(' ');
    final date = parts[0].split('-').map(int.parse).toList();
    if (parts.length < 2) return DateTime(date[0], date[1], date[2]);
    final time = parts[1].split(':').map(int.parse).toList();
    return DateTime(date[0], date[1], date[2], time[0], time[1]);
  } catch (_) {
    return null;
  }
}

/// 11月5日 周四
String formatCnDate(DateTime d) =>
    '${d.month}月${d.day}日 周${_weekdays[d.weekday - 1]}';

/// 2026年11月
String formatMonth(DateTime d) => '${d.year}年${d.month}月';

/// 2026-11-05
String formatIso(DateTime d) =>
    '${d.year}-${_two(d.month)}-${_two(d.day)}';

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
