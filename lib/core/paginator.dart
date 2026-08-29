/// 分页排版引擎。
///
/// 基于 TextPainter 按视口尺寸将章节文本切分为页，
/// 每页记录字符区间 [start, end)，用于进度定位与翻页。
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
    final maxWidth = (viewport.width - padding.horizontal).clamp(1.0, 100000.0);
    final maxPageHeight =
        (viewport.height - padding.vertical).clamp(1.0, 100000.0);
    final linesPerPage = (maxPageHeight / lineHeight).floor().clamp(1, 500);

    final pages = <PageRange>[];
    // 注意：不能设置 maxLines，否则溢出内容被截断，
    // metrics.length 永远不会超过 linesPerPage，整章会被错误地排成单页
    final tp = TextPainter(textDirection: TextDirection.ltr);

    var pos = 0;
    var guard = 0;
    while (pos < text.length && guard < 100000) {
      guard++;
      tp.text = TextSpan(text: text.substring(pos), style: style);
      tp.layout(maxWidth: maxWidth);

      final metrics = tp.computeLineMetrics();
      if (metrics.length <= linesPerPage) {
        pages.add(PageRange(pos, text.length));
        break;
      }

      // 取第 linesPerPage 行的起始位置作为下一页起点
      final nextLineTop = metrics[linesPerPage].baseline -
          metrics[linesPerPage].height;
      final nextPos = tp
          .getPositionForOffset(Offset(0, nextLineTop + 1))
          .offset;
      if (nextPos <= pos) {
        // 防御：无法推进时强制前进，避免死循环
        pages.add(PageRange(pos, pos + 1));
        pos += 1;
      } else {
        pages.add(PageRange(pos, nextPos));
        pos = nextPos;
      }
    }
    tp.dispose();

    if (pages.isEmpty) {
      pages.add(const PageRange(0, 0));
    }
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
