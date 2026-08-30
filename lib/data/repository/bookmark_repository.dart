/// 书签数据访问。
library;

import 'package:sqflite/sqflite.dart';

import '../model/models.dart';

class BookmarkRepository {
  final Database _db;

  BookmarkRepository(this._db);

  Future<int> addBookmark(Bookmark bookmark) =>
      _db.insert('bookmarks', bookmark.toMap());

  Future<void> deleteBookmark(int id) =>
      _db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);

  /// 某本书的全部书签，按阅读顺序排列。
  Future<List<Bookmark>> listBookmarks(String bookKey) async {
    final rows = await _db.query('bookmarks',
        where: 'bookKey = ?',
        whereArgs: [bookKey],
        orderBy: 'chapterIndex ASC, charOffset ASC');
    return rows.map(Bookmark.fromMap).toList();
  }

  /// 精确匹配章节内偏移的书签（同一页的首字符偏移在分页参数不变时固定）。
  Future<Bookmark?> findBookmark(
      String bookKey, int chapterIndex, int charOffset) async {
    final rows = await _db.query('bookmarks',
        where: 'bookKey = ? AND chapterIndex = ? AND charOffset = ?',
        whereArgs: [bookKey, chapterIndex, charOffset],
        limit: 1);
    return rows.isEmpty ? null : Bookmark.fromMap(rows.first);
  }

  /// 删除某本书的全部书签（书籍从书架移除时级联调用）。
  Future<void> deleteByBookKey(String bookKey) =>
      _db.delete('bookmarks', where: 'bookKey = ?', whereArgs: [bookKey]);
}
