/// 阅读统计数据访问（按天聚合，累加写入）。
library;

import 'package:sqflite/sqflite.dart';

import '../model/models.dart';

class StatsRepository {
  final Database _db;

  StatsRepository(this._db);

  /// 当日日期键（YYYY-MM-DD，本地时区）。
  static String todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// 累加当日时长与字数（不存在则插入，存在则累加）。
  Future<void> addToday({required int durationMs, required int charCount}) async {
    if (durationMs <= 0 && charCount <= 0) return;
    final date = todayKey();
    await _db.rawInsert(
      'INSERT INTO reading_stats (date, durationMs, charCount) '
      'VALUES (?, ?, ?) '
      'ON CONFLICT(date) DO UPDATE SET '
      'durationMs = durationMs + excluded.durationMs, '
      'charCount = charCount + excluded.charCount',
      [date, durationMs, charCount],
    );
  }

  /// 全部每日统计（按日期倒序）。
  Future<List<ReadingStat>> listAll() async {
    final rows = await _db.query('reading_stats', orderBy: 'date DESC');
    return rows.map(ReadingStat.fromMap).toList();
  }

  /// 累计总时长与总字数。
  Future<ReadingStat> getTotal() async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(durationMs), 0) AS durationMs, '
      'COALESCE(SUM(charCount), 0) AS charCount FROM reading_stats',
    );
    final row = rows.first;
    return ReadingStat(
      date: '',
      durationMs: (row['durationMs'] as num?)?.toInt() ?? 0,
      charCount: (row['charCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// 当日统计（无记录返回零值）。
  Future<ReadingStat> getToday() async {
    final date = todayKey();
    final rows =
        await _db.query('reading_stats', where: 'date = ?', whereArgs: [date]);
    return rows.isEmpty
        ? ReadingStat(date: date)
        : ReadingStat.fromMap(rows.first);
  }
}
