import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/data/database.dart';
import 'package:novel_read/data/repository/stats_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('空表 getTotal 不抛异常且返回零值（回归：0 AS date 类型转换）', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 4, onCreate: AppDatabase.createSchema),
    );
    final repo = StatsRepository(db);

    // 空表：getTotal 不应抛异常（此前 0 AS date 为 int，fromMap 强转 String 崩溃）
    final total = await repo.getTotal();
    expect(total.durationMs, 0);
    expect(total.charCount, 0);

    final today = await repo.getToday();
    expect(today.durationMs, 0);
    expect(today.charCount, 0);

    expect(await repo.listAll(), isEmpty);
    await db.close();
  });

  test('addToday 累加与查询', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 4, onCreate: AppDatabase.createSchema),
    );
    final repo = StatsRepository(db);

    await repo.addToday(durationMs: 60000, charCount: 1000);
    await repo.addToday(durationMs: 30000, charCount: 500);

    final today = await repo.getToday();
    expect(today.durationMs, 90000);
    expect(today.charCount, 1500);

    final total = await repo.getTotal();
    expect(total.durationMs, 90000);
    expect(total.charCount, 1500);

    expect((await repo.listAll()).length, 1);
    await db.close();
  });
}
