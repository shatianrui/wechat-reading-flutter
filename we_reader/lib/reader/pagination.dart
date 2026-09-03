import 'package:flutter/material.dart';

import '../models/models.dart';

/// 一页的定位信息：属于哪一章、章节内字符区间。
class PageSpec {
  const PageSpec({
    required this.chapterIndex,
    required this.start,
    required this.end,
  });

  final int chapterIndex;

  /// 章节内起始字符偏移（含）。
  final int start;

  /// 章节内结束字符偏移（不含）。
  final int end;

  bool containsOffset(int offset) => offset >= start && offset < end;
}

/// 分页引擎：用 [TextPainter] 逐行排版，把每章切成整行对齐的页。
class Paginator {
  Paginator._();

  /// 把整本书按当前排版参数切页。示例书籍很短，全量分页开销可忽略；
  /// 长书应改为按章懒分页。
  static List<PageSpec> paginateBook({
    required List<Chapter> chapters,
    required TextStyle style,
    required Size pageSize,
  }) {
    final pages = <PageSpec>[];
    for (var i = 0; i < chapters.length; i++) {
      final ranges = paginateChapter(
        text: chapters[i].content,
        style: style,
        pageSize: pageSize,
      );
      for (final range in ranges) {
        pages.add(
          PageSpec(chapterIndex: i, start: range.start, end: range.end),
        );
      }
    }
    return pages;
  }

  /// 对单章文本分页，返回章节内字符区间列表。
  static List<TextRange> paginateChapter({
    required String text,
    required TextStyle style,
    required Size pageSize,
  }) {
    if (text.isEmpty) return [const TextRange(start: 0, end: 0)];

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: pageSize.width);

    final lines = painter.computeLineMetrics();
    final ranges = <TextRange>[];
    double pageTop = 0;
    double lineTop = 0;
    int pageStart = 0;

    for (final line in lines) {
      final lineBottom = lineTop + line.height;
      // 当前行放不进本页时，在该行前断页。
      if (lineBottom - pageTop > pageSize.height + 0.5 && lineTop > pageTop) {
        final breakOffset = painter
            .getPositionForOffset(Offset(0, lineTop + line.height / 2))
            .offset;
        if (breakOffset > pageStart) {
          ranges.add(TextRange(start: pageStart, end: breakOffset));
          pageStart = breakOffset;
          pageTop = lineTop;
        }
      }
      lineTop = lineBottom;
    }
    if (pageStart < text.length) {
      ranges.add(TextRange(start: pageStart, end: text.length));
    }
    painter.dispose();
    return ranges.isEmpty ? [TextRange(start: 0, end: text.length)] : ranges;
  }
}
