import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_read/core/chapter_parser.dart';
import 'package:novel_read/core/paginator.dart';

void main() {
  test('ChapterParser 识别章节标题', () {
    const text = '前言内容\n第一章 开始\n正文一\n第二章 继续\n正文二\n';
    final chapters = ChapterParser.parse(text);
    expect(chapters.length, 3);
    expect(chapters[0].title, '开篇');
    expect(chapters[1].title, contains('第一章'));
    expect(chapters[2].title, contains('第二章'));
    expect(chapters[1].startOffset, lessThan(chapters[1].endOffset));
  });

  test('ChapterParser 无章节时切分伪章节', () {
    final text = '字' * 120000;
    final chapters = ChapterParser.parse(text);
    expect(chapters.length, greaterThanOrEqualTo(2));
  });

  test('Paginator 分页与定位', () {
    final lines = List.generate(60, (i) => '这是第$i行的测试文本内容。');
    final text = lines.join('\n');
    final pages = Paginator.paginate(
      text: text,
      style: const TextStyle(fontSize: 16),
      lineHeight: 24,
      viewport: const Size(400, 600),
      padding: const EdgeInsets.all(20),
    );
    expect(pages.length, greaterThan(1));
    expect(pages.first.start, 0);
    expect(Paginator.locate(pages, 0), 0);
    expect(Paginator.locate(pages, text.length + 10), pages.length - 1);
  });
}
