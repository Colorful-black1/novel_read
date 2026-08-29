/// TXT 导入服务：选文件 → 解码 → 解析章节 → 计算标识 → 入库。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../core/book_key.dart';
import '../core/chapter_parser.dart';
import '../core/constants.dart';
import '../core/encoding.dart';
import '../data/model/models.dart';
import '../data/repository/book_repository.dart';

class ImportResult {
  final bool success;
  final String message;
  final Book? book;

  const ImportResult._(this.success, this.message, this.book);

  factory ImportResult.ok(Book book) =>
      ImportResult._(true, '导入成功：${book.title}', book);

  factory ImportResult.fail(String message) => ImportResult._(false, message, null);
}

class ImportService {
  final BookRepository _books;

  ImportService(this._books);

  /// 弹出文件选择器并导入。
  Future<ImportResult> pickAndImport() async {
    // file_picker 12.x：取消时返回空列表
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (picked.isEmpty) return const ImportResult._(false, '', null);
    final path = picked.single.path;
    if (path == null) return const ImportResult._(false, '', null);
    return importFile(path);
  }

  /// 导入指定 TXT 文件。
  Future<ImportResult> importFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return ImportResult.fail('文件不存在：$path');
      }
      final size = await file.length();

      // 头部取样用于书籍识别哈希
      final head = await EncodingDetector.readHead(path, bookKeySampleBytes);

      // 文件名作为书名（去掉扩展名）
      final title = _fileNameToTitle(path);

      final bookKey = BookKey.compute(
          title: title, fileSize: size, headBytes: head);

      // 已存在则跳过重复导入
      final existing = await _books.findByBookKey(bookKey);
      if (existing != null) {
        return ImportResult.ok(existing);
      }

      final content = await EncodingDetector.decodeFile(path);
      final parsed = ChapterParser.parse(content);

      final book = Book(
        id: 0,
        title: title,
        author: '',
        filePath: path,
        fileSize: size,
        bookKey: bookKey,
        chapterCount: parsed.length,
        addedAt: DateTime.now(),
      );
      final chapters = <Chapter>[];
      for (var i = 0; i < parsed.length; i++) {
        final c = parsed[i];
        chapters.add(Chapter(
          id: 0,
          bookId: 0,
          idx: i,
          title: c.title,
          startOffset: c.startOffset,
          endOffset: c.endOffset,
        ));
      }
      final id = await _books.insertBook(book, chapters);
      return ImportResult.ok(Book(
        id: id,
        title: book.title,
        author: book.author,
        filePath: book.filePath,
        fileSize: book.fileSize,
        bookKey: book.bookKey,
        chapterCount: book.chapterCount,
        addedAt: book.addedAt,
      ));
    } catch (e) {
      return ImportResult.fail('导入失败：$e');
    }
  }

  /// 读取整本书内容。
  Future<String> readBookContent(Book book) async {
    return EncodingDetector.decodeFile(book.filePath);
  }

  static String _fileNameToTitle(String path) {
    var name = path.replaceAll('\\', '/').split('/').last;
    if (name.toLowerCase().endsWith('.txt')) {
      name = name.substring(0, name.length - 4);
    }
    return name.isEmpty ? '未命名书籍' : name;
  }
}
