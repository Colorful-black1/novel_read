/// 分页排版引擎。
///
/// 基于 TextPainter 按视口尺寸将章节文本切分为页，
/// 每页记录字符区间 [start, end)，用于进度定位与翻页。
///
/// 性能关键：整章只做一次布局，之后仅按行边界查询字符偏移，
/// 复杂度为 O(1) 次排版 + O(页数) 次查询。
/// （旧实现每页对"剩余全文"重新排版，为 O(页数²)，大章节严重卡顿。）
library;

import 'package:flutter/painting.dart';

class PageRange {
  final int start;
  final int end;

  const PageRange(this.start, this.end);

  bool contains(int charOffset) =>
      charOffset >= start && charOffset < end;
}

class Paginator {
  Paginator._();

  /// 将 [text] 分页。
  ///
  /// [lineHeight] 为单行实际占高（字号 * 行距倍数），
  /// [viewport] 为阅读区域总尺寸，[padding] 为内边距。
  static List<PageRange> paginate({
    required String text,
    required TextStyle style,
    required double lineHeight,
    required Size viewport,
    required EdgeInsets padding,
  }) {
    if (text.isEmpty) {
      return [const PageRange(0, 0)];
    }

    final maxWidth = (viewport.width - padding.horizontal).clamp(1.0, 100000.0);
    final maxPageHeight =
        (viewport.height - padding.vertical).clamp(1.0, 100000.0);
    final linesPerPage = (maxPageHeight / lineHeight).floor().clamp(1, 500);

    // 整章一次布局（注意不能设置 maxLines，否则溢出被截断、无法探测分页边界）
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: maxWidth);

    final metrics = tp.computeLineMetrics();
    final totalLines = metrics.length;

    final pages = <PageRange>[];
    var pageStart = 0;
    var boundaryLine = linesPerPage;
    while (boundaryLine < totalLines) {
      // 第 boundaryLine 行的顶部 y 坐标 → 该行起始字符偏移（页尾边界）
      final m = metrics[boundaryLine];
      var pos = tp
          .getPositionForOffset(Offset(0, m.baseline - m.height + 1))
          .offset;
      if (pos <= pageStart) {
        // 防御：偏移未推进（异常排版）时按字符硬切，避免死循环
        pos = (pageStart + 1).clamp(0, text.length);
      }
      pages.add(PageRange(pageStart, pos));
      pageStart = pos;
      boundaryLine += linesPerPage;
    }
    pages.add(PageRange(pageStart, text.length));
    tp.dispose();

    return pages;
  }

  /// 查找字符偏移所在的页索引。
  static int locate(List<PageRange> pages, int charOffset) {
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].contains(charOffset)) return i;
    }
    return charOffset <= 0 ? 0 : pages.length - 1;
  }

  /// 计算单行实际高度。
  static double lineHeightFor(double fontSize, double multiplier) {
    return fontSize * multiplier;
  }
}
