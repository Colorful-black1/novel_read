import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/data/database.dart';
import 'package:novel_read/data/model/models.dart';
import 'package:novel_read/data/repository/book_repository.dart';
import 'package:novel_read/data/repository/bookmark_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('书签增删查与书籍级联清理', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: AppDatabase.createSchema),
    );
    final bookRepo = BookRepository(db);
    final repo = BookmarkRepository(db);

    final bookId = await bookRepo.insertBook(
      Book(
        id: 0,
        title: '书一',
        author: '',
        filePath: 'C:/fake/书一.txt',
        fileSize: 100,
        bookKey: 'key-a',
        chapterCount: 2,
        addedAt: DateTime(2026, 1, 1),
      ),
      [
        Chapter(id: 0, bookId: 0, idx: 0, title: '第一章', startOffset: 0, endOffset: 50),
        Chapter(id: 0, bookId: 0, idx: 1, title: '第二章', startOffset: 50, endOffset: 100),
      ],
    );
    expect(bookId, greaterThan(0));

    Bookmark make(int chapterIndex, int charOffset) => Bookmark(
          bookKey: 'key-a',
          chapterIndex: chapterIndex,
          charOffset: charOffset,
          snippet: '摘录$chapterIndex-$charOffset',
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        );

    final id1 = await repo.addBookmark(make(0, 0));
    final id2 = await repo.addBookmark(make(1, 20));
    expect(id2, isNot(id1));

    // 按阅读顺序排列
    final list = await repo.listBookmarks('key-a');
    expect(list.length, 2);
    expect(list[0].chapterIndex, 0);
    expect(list[1].chapterIndex, 1);
    expect(list[1].snippet, '摘录1-20');

    // 精确匹配定位
    final found = await repo.findBookmark('key-a', 1, 20);
    expect(found, isNotNull);
    expect(await repo.findBookmark('key-a', 0, 999), isNull);

    // 删除单条
    await repo.deleteBookmark(id1);
    expect((await repo.listBookmarks('key-a')).length, 1);

    // 级联清理：删除书籍时书签一并删除
    await repo.addBookmark(make(0, 10));
    await bookRepo.deleteBook(bookId);
    expect(await repo.listBookmarks('key-a'), isEmpty);

    await db.close();
  });
}
