/// SQLite 数据库打开与建表。
///
/// Windows / 桌面端通过 sqflite_common_ffi 运行，Android 使用原生 sqflite。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._();

  static Database? _db;

  /// 打开（或复用已打开的）数据库。
  static Future<Database> instance() async {
    final cached = _db;
    if (cached != null && cached.isOpen) return cached;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationSupportDirectory();
    final db = await databaseFactory.openDatabase(
      p.join(dir.path, 'novel_read.db'),
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: createSchema,
        onUpgrade: upgrade,
      ),
    );
    _db = db;
    return db;
  }

  /// 版本迁移。
  ///
  /// v1→v2：书架自定义排序与分组。
  /// 回滚说明：SQLite 3.35+ 可 DROP COLUMN，但建议直接备份恢复旧版
  /// novel_read.db 文件（旧版本应用无法识别新增列）。
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE books ADD COLUMN sortIndex INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE books ADD COLUMN groupId INTEGER');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS book_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          sortIndex INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  /// 建表（公开以便单元测试在内存库上复用）。
  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        filePath TEXT NOT NULL,
        fileSize INTEGER NOT NULL,
        bookKey TEXT NOT NULL UNIQUE,
        chapterCount INTEGER NOT NULL,
        addedAt INTEGER NOT NULL,
        sortIndex INTEGER NOT NULL DEFAULT 0,
        groupId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS book_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sortIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookId INTEGER NOT NULL,
        idx INTEGER NOT NULL,
        title TEXT NOT NULL,
        startOffset INTEGER NOT NULL,
        endOffset INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_chapters_book ON chapters(bookId, idx)');
    await db.execute('''
      CREATE TABLE progress (
        bookKey TEXT PRIMARY KEY,
        chapterIndex INTEGER NOT NULL,
        charOffset INTEGER NOT NULL,
        percent REAL NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_pairs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deviceId TEXT NOT NULL UNIQUE,
        deviceName TEXT NOT NULL DEFAULT '',
        token TEXT NOT NULL,
        host TEXT NOT NULL DEFAULT '',
        port INTEGER NOT NULL DEFAULT 0,
        lastSyncAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time INTEGER NOT NULL,
        direction TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE conflict_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bookKey TEXT NOT NULL,
        chapterIndex INTEGER NOT NULL,
        charOffset INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        savedAt INTEGER NOT NULL
      )
    ''');
  }
}
