import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/data/database.dart';
import 'package:novel_read/data/model/models.dart';
import 'package:novel_read/data/repository/book_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('insertBook 连续插入多本书与多章节不触发主键冲突', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
          version: 1, onCreate: AppDatabase.createSchema),
    );
    final repo = BookRepository(db);

    Book makeBook(String key, String title) => Book(
          id: 0,
          title: title,
          author: '',
          filePath: 'C:/fake/$title.txt',
          fileSize: 100,
          bookKey: key,
          chapterCount: 2,
          addedAt: DateTime(2026, 1, 1),
        );

    List<Chapter> makeChapters() => [
          Chapter(
              id: 0,
              bookId: 0,
              idx: 0,
              title: '第一章',
              startOffset: 0,
              endOffset: 50),
          Chapter(
              id: 0,
              bookId: 0,
              idx: 1,
              title: '第二章',
              startOffset: 50,
              endOffset: 100),
        ];

    // 回归：此前显式插入 id=0，第二本书/第二章会触发 UNIQUE 冲突
    final id1 = await repo.insertBook(makeBook('key-a', '书一'), makeChapters());
    final id2 = await repo.insertBook(makeBook('key-b', '书二'), makeChapters());

    expect(id2, isNot(id1));
    expect((await repo.listChapters(id1)).length, 2);
    expect((await repo.listChapters(id2)).length, 2);
    expect((await repo.listBooks()).length, 2);

    await db.close();
  });
}
