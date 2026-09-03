import 'package:flutter/rendering.dart';

import '../../core/models/chapter.dart';

/// 一页的内容切片:章节索引 + 章内字符区间 [start, end)。
class PageSlice {
  const PageSlice({
    required this.chapterIndex,
    required this.pageInChapter,
    required this.start,
    required this.end,
    required this.isChapterFirst,
  });

  final int chapterIndex;
  final int pageInChapter;
  final int start;
  final int end;
  final bool isChapterFirst;
}

/// 分页结果:整书的平铺页列表 + 章节文本缓存。
class PaginatedBook {
  const PaginatedBook({
    required this.pages,
    required this.chapterTexts,
    required this.chapterTitles,
    required this.chapterFirstPage,
    required this.chapterCharBase,
    required this.totalChars,
  });

  final List<PageSlice> pages;

  /// 各章 displayText(分页与批注定位共用同一文本)。
  final List<String> chapterTexts;
  final List<String> chapterTitles;

  /// 各章第一页在 pages 中的下标。
  final List<int> chapterFirstPage;

  /// 各章起始的全书累计字符数(用于全书百分比)。
  final List<int> chapterCharBase;
  final int totalChars;

  int pageIndexFor(int chapterIndex, int charOffset) {
    if (pages.isEmpty) return 0;
    final first = chapterFirstPage[chapterIndex.clamp(0, chapterFirstPage.length - 1)];
    for (var i = first; i < pages.length; i++) {
      final p = pages[i];
      if (p.chapterIndex != chapterIndex) break;
      if (charOffset >= p.start && charOffset < p.end) return i;
    }
    // 偏移超界:返回该章最后一页。
    var last = first;
    for (var i = first; i < pages.length && pages[i].chapterIndex == chapterIndex; i++) {
      last = i;
    }
    return last;
  }

  double percentAt(int pageIndex) {
    if (pages.isEmpty || totalChars == 0) return 0;
    final p = pages[pageIndex.clamp(0, pages.length - 1)];
    final pos = chapterCharBase[p.chapterIndex] + p.start;
    if (pageIndex >= pages.length - 1) return 1;
    return (pos / totalChars).clamp(0.0, 1.0);
  }
}

/// 分页引擎:TextPainter 逐行度量,把章节文本切成整页。
///
/// 页与渲染使用完全相同的宽度与 TextStyle,保证断行一致。
abstract final class Paginator {
  /// 章节首页为标题预留的高度(由调用方按标题样式计算传入)。
  static PaginatedBook paginate({
    required List<Chapter> chapters,
    required TextStyle bodyStyle,
    required Size pageSize,
    required double firstPageReserved,
  }) {
    final pages = <PageSlice>[];
    final chapterTexts = <String>[];
    final chapterTitles = <String>[];
    final chapterFirstPage = <int>[];
    final chapterCharBase = <int>[];
    var charBase = 0;

    for (var c = 0; c < chapters.length; c++) {
      final text = chapters[c].displayText;
      chapterTexts.add(text);
      chapterTitles.add(chapters[c].title);
      chapterFirstPage.add(pages.length);
      chapterCharBase.add(charBase);
      charBase += text.length;

      final breaks = _paginateChapter(
        text: text,
        style: bodyStyle,
        size: pageSize,
        firstPageReserved: firstPageReserved,
      );
      for (var p = 0; p < breaks.length; p++) {
        pages.add(PageSlice(
          chapterIndex: c,
          pageInChapter: p,
          start: breaks[p].$1,
          end: breaks[p].$2,
          isChapterFirst: p == 0,
        ));
      }
    }

    return PaginatedBook(
      pages: pages,
      chapterTexts: chapterTexts,
      chapterTitles: chapterTitles,
      chapterFirstPage: chapterFirstPage,
      chapterCharBase: chapterCharBase,
      totalChars: charBase,
    );
  }

  static List<(int, int)> _paginateChapter({
    required String text,
    required TextStyle style,
    required Size size,
    required double firstPageReserved,
  }) {
    if (text.isEmpty) return const [(0, 0)];

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) {
      painter.dispose();
      return [(0, text.length)];
    }

    final result = <(int, int)>[];
    var pageStartChar = 0;
    var pageTop = 0.0;
    var available = size.height - firstPageReserved;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineTop = line.baseline - line.ascent;
      final lineBottom = line.baseline + line.descent;
      if (lineBottom - pageTop > available && lineTop > pageTop) {
        // 当前行放不下:在此断页。
        final breakChar =
            painter.getPositionForOffset(Offset(0, lineTop + 0.1)).offset;
        if (breakChar > pageStartChar) {
          result.add((pageStartChar, breakChar));
          pageStartChar = breakChar;
        }
        pageTop = lineTop;
        available = size.height;
      }
    }
    if (pageStartChar < text.length) {
      result.add((pageStartChar, text.length));
    }
    painter.dispose();
    return result.isEmpty ? [(0, text.length)] : result;
  }
}
