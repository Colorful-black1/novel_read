/// 同步配对与日志数据访问。
library;

import 'package:sqflite/sqflite.dart';

import '../model/models.dart';

class SyncRepository {
  final Database _db;

  SyncRepository(this._db);

  // ---------------- 配对设备 ----------------

  Future<List<SyncPair>> listPairs() async {
    final rows = await _db.query('sync_pairs', orderBy: 'lastSyncAt DESC');
    return rows.map(SyncPair.fromMap).toList();
  }

  Future<SyncPair?> findPairByDeviceId(String deviceId) async {
    final rows = await _db.query('sync_pairs',
        where: 'deviceId = ?', whereArgs: [deviceId], limit: 1);
    return rows.isEmpty ? null : SyncPair.fromMap(rows.first);
  }

  Future<SyncPair?> findPairByToken(String token) async {
    final rows = await _db.query('sync_pairs',
        where: 'token = ?', whereArgs: [token], limit: 1);
    return rows.isEmpty ? null : SyncPair.fromMap(rows.first);
  }

  /// 新增或更新配对设备。
  Future<void> upsertPair(SyncPair pair) async {
    await _db.insert('sync_pairs', pair.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updatePairSyncTime(String deviceId, int lastSyncAtMs) async {
    await _db.update(
      'sync_pairs',
      {'lastSyncAt': lastSyncAtMs},
      where: 'deviceId = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> deletePair(String deviceId) async {
    await _db
        .delete('sync_pairs', where: 'deviceId = ?', whereArgs: [deviceId]);
  }

  // ---------------- 同步日志 ----------------

  Future<void> addLog(String direction, String detail) async {
    await _db.insert('sync_logs', SyncLog(
      id: 0,
      time: DateTime.now(),
      direction: direction,
      detail: detail,
    ).toMap());
  }

  Future<List<SyncLog>> listLogs({int limit = 50}) async {
    final rows = await _db.query('sync_logs',
        orderBy: 'time DESC', limit: limit);
    return rows.map(SyncLog.fromMap).toList();
  }
}
