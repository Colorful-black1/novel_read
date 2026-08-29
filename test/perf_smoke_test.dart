import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/core/chapter_parser.dart';
import 'package:novel_read/core/paginator.dart';
import 'package:flutter/painting.dart';

void main() {
  test('大书性能冒烟：20MB / 2000 章解析与分页', () {
    // 合成一本约 20MB 的书：2000 章，每章约 10KB
    final chapterBuf = StringBuffer();
    for (var c = 0; c < 2000; c++) {
      chapterBuf.writeln('第${c + 1}章 测试章节标题$c');
      final line = '这是用于填充章节内容的测试文本行，包含一些常用汉字。' * 2;
      for (var l = 0; l < 130; l++) {
        chapterBuf.writeln(line);
      }
    }
    final text = chapterBuf.toString();
    final sizeMb = text.length / 1024 / 1024;
    // ignore: avoid_print
    print('合成书籍大小: ${sizeMb.toStringAsFixed(1)}MB');

    final sw = Stopwatch()..start();
    final chapters = ChapterParser.parse(text);
    final parseMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('章节解析: ${parseMs}ms，解析出 ${chapters.length} 章');
    expect(chapters.length, 2000); // 首行即章节标题，无"开篇"前导章

    // 单章分页耗时（每章约 10KB）
    sw.reset();
    final pages = Paginator.paginate(
      text: text.substring(chapters[1].startOffset, chapters[1].endOffset),
      style: const TextStyle(fontSize: 19, height: 1.6),
      lineHeight: 19 * 1.6,
      viewport: const Size(1200, 800),
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 44),
    );
    // ignore: avoid_print
    print('单章分页: ${sw.elapsedMilliseconds}ms，${pages.length} 页');
    expect(pages.length, greaterThan(1));

    // 导入解析总耗时应秒级完成（旧实现同步跑在 UI 线程且逐行正则，耗时显著更长）
    expect(parseMs, lessThan(10000));
  });
}
