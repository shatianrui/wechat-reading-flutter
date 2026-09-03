import 'package:flutter/material.dart';

import '../../../core/models/annotation.dart';
import '../../../core/state/reader_settings.dart';

/// 高亮区间(批注划线 / TTS 当前句)。
class HighlightRange {
  const HighlightRange({
    required this.start,
    required this.end,
    required this.color,
    this.underline = false,
  });

  final int start;
  final int end;
  final Color color;
  final bool underline;
}

/// 把章节文本片段渲染为带高亮的 spans。
/// [segmentStart] 为该片段在章节文本中的起始偏移。
List<InlineSpan> buildHighlightedSpans({
  required String text,
  required int segmentStart,
  required TextStyle style,
  required List<HighlightRange> ranges,
}) {
  if (text.isEmpty) return const [];
  final segmentEnd = segmentStart + text.length;

  // 收集断点。
  final points = <int>{0, text.length};
  for (final r in ranges) {
    final s = (r.start - segmentStart).clamp(0, text.length);
    final e = (r.end - segmentStart).clamp(0, text.length);
    if (s < e) {
      points.add(s);
      points.add(e);
    }
  }
  final sorted = points.toList()..sort();

  final spans = <InlineSpan>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final s = sorted[i];
    final e = sorted[i + 1];
    if (s >= e) continue;
    Color? bg;
    var underline = false;
    for (final r in ranges) {
      final rs = r.start - segmentStart;
      final re = r.end - segmentStart;
      if (rs <= s && re >= e && r.start < segmentEnd && r.end > segmentStart) {
        if (r.underline) {
          underline = true;
        } else {
          bg = bg == null ? r.color : Color.alphaBlend(r.color, bg);
        }
      }
    }
    spans.add(TextSpan(
      text: text.substring(s, e),
      style: bg != null || underline
          ? style.copyWith(
              backgroundColor: bg,
              decoration: underline ? TextDecoration.underline : null,
              decorationColor: style.color?.withValues(alpha: 0.5),
              decorationStyle: TextDecorationStyle.dashed,
            )
          : style,
    ));
  }
  return spans;
}

/// 从批注列表生成某章节的高亮区间。
List<HighlightRange> annotationRanges({
  required List<Annotation> annotations,
  required int chapterIndex,
  required ReaderTheme theme,
}) {
  return [
    for (final a in annotations)
      if (a.chapterIndex == chapterIndex && a.type != AnnotationType.bookmark)
        HighlightRange(
          start: a.start,
          end: a.end,
          color: theme.highlight,
          underline: a.type == AnnotationType.note,
        ),
  ];
}
