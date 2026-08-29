/// 章节解析：将整本书文本切分为章节列表。
///
/// 识别形如「第X章 / 第X节 / 第X卷 / 第X回」的标题行；
/// 无任何章节标记时按固定字符数切分为伪章节。
library;

import 'constants.dart';

class ParsedChapter {
  final String title;
  final int startOffset;
  final int endOffset;

  const ParsedChapter({
    required this.title,
    required this.startOffset,
    required this.endOffset,
  });
}

class ChapterParser {
  ChapterParser._();

  static final RegExp _chapterTitle = RegExp(
    r'^\s*(第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章节卷回部集][^\n]{0,40})\s*$',
  );

  /// 解析章节。返回至少包含一个元素的列表。
  static List<ParsedChapter> parse(String content) {
    final results = <ParsedChapter>[];
    var currentTitle = '开篇';
    var currentStart = 0;

    var lineStart = 0;
    var found = false;
    while (lineStart < content.length) {
      var lineEnd = content.indexOf('\n', lineStart);
      if (lineEnd < 0) lineEnd = content.length;
      final line = content.substring(lineStart, lineEnd);
      final match = _chapterTitle.firstMatch(line);
      if (match != null) {
        // 遇到新标题：先结算上一章（若前面有实际内容）
        if (lineStart > currentStart || results.isNotEmpty || currentStart > 0) {
          results.add(ParsedChapter(
            title: currentTitle,
            startOffset: currentStart,
            endOffset: lineStart,
          ));
        }
        currentTitle = _normalizeTitle(match.group(1)!);
        currentStart = lineStart;
        found = true;
      }
      lineStart = lineEnd + 1;
    }
    // 结算最后一章
    results.add(ParsedChapter(
      title: currentTitle,
      startOffset: currentStart,
      endOffset: content.length,
    ));

    if (!found) {
      return _splitPseudo(content);
    }
    return results;
  }

  /// 无章节标记时按固定长度切分伪章节。
  static List<ParsedChapter> _splitPseudo(String content) {
    final results = <ParsedChapter>[];
    var offset = 0;
    var index = 1;
    while (offset < content.length) {
      final end = (offset + pseudoChapterSize).clamp(0, content.length);
      results.add(ParsedChapter(
        title: '第 $index 部分',
        startOffset: offset,
        endOffset: end,
      ));
      offset = end;
      index++;
    }
    if (results.isEmpty) {
      results.add(const ParsedChapter(
        title: '正文',
        startOffset: 0,
        endOffset: 0,
      ));
    }
    return results;
  }

  static String _normalizeTitle(String raw) {
    final t = raw.trim();
    return t.length > 40 ? t.substring(0, 40) : t;
  }
}
