/// 书库与章节数据访问。
library;

import 'package:sqflite/sqflite.dart';

import '../model/models.dart';

class BookRepository {
  final Database _db;

  BookRepository(this._db);

  /// 新增书籍及其章节，返回书籍 id。
  Future<int> insertBook(Book book, List<Chapter> chapters) async {
    return _db.transaction((txn) async {
      final id = await txn.insert('books', book.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      final batch = txn.batch();
      for (final c in chapters) {
        batch.insert('chapters', Chapter(
          id: 0,
          bookId: id,
          idx: c.idx,
          title: c.title,
          startOffset: c.startOffset,
          endOffset: c.endOffset,
        ).toMap());
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  Future<List<Book>> listBooks() async {
    final rows = await _db.query('books', orderBy: 'addedAt DESC');
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> getBook(int id) async {
    final rows =
        await _db.query('books', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  Future<Book?> findByBookKey(String bookKey) async {
    final rows = await _db.query('books',
        where: 'bookKey = ?', whereArgs: [bookKey], limit: 1);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  Future<void> deleteBook(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('chapters', where: 'bookId = ?', whereArgs: [id]);
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Chapter>> listChapters(int bookId) async {
    final rows = await _db.query('chapters',
        where: 'bookId = ?', whereArgs: [bookId], orderBy: 'idx');
    return rows.map(Chapter.fromMap).toList();
  }
}

/// 阅读进度数据访问（含同步合并逻辑）。
class ProgressRepository {
  final Database _db;

  ProgressRepository(this._db);

  Future<ReadingProgress?> getProgress(String bookKey) async {
    final rows = await _db.query('progress',
        where: 'bookKey = ?', whereArgs: [bookKey], limit: 1);
    return rows.isEmpty ? null : ReadingProgress.fromMap(rows.first);
  }

  /// 保存本地进度（仅当比现有记录更新时写入）。
  Future<void> saveProgress(ReadingProgress progress) async {
    await _db.insert('progress', progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 全量本地进度（用于同步上行）。
  Future<List<ReadingProgress>> listAll() async {
    final rows = await _db.query('progress');
    return rows.map(ReadingProgress.fromMap).toList();
  }

  /// 合并远端进度：last-write-wins，被覆盖时保留冲突快照。
  ///
  /// 返回被覆盖而生成快照的 bookKey 列表。
  Future<List<String>> mergeRemote(List<ReadingProgress> remote) async {
    final snapshotKeys = <String>[];
    await _db.transaction((txn) async {
      for (final r in remote) {
        final rows = await txn.query('progress',
            where: 'bookKey = ?', whereArgs: [r.bookKey], limit: 1);
        if (rows.isEmpty) {
          await txn.insert('progress', r.toMap());
          continue;
        }
        final local = ReadingProgress.fromMap(rows.first);
        if (r.updatedAtMs > local.updatedAtMs) {
          await txn.insert('conflict_snapshots', ConflictSnapshot(
            id: 0,
            bookKey: local.bookKey,
            chapterIndex: local.chapterIndex,
            charOffset: local.charOffset,
            updatedAtMs: local.updatedAtMs,
            savedAt: DateTime.now(),
          ).toMap());
          snapshotKeys.add(local.bookKey);
          await txn.update('progress', r.toMap(),
              where: 'bookKey = ?', whereArgs: [r.bookKey]);
        }
      }
    });
    return snapshotKeys;
  }
}
