import 'package:flutter/material.dart';

import '../models/models.dart';
import '../providers/reader_settings.dart';

/// 把一段正文按「用户划线 / 想法 / TTS 当前句」切成着色的 TextSpan 列表。
///
/// [text] 为页面（或整章）文本，[baseOffset] 是它在章节内的起始偏移；
/// 所有标注区间均为章节内偏移。
List<TextSpan> buildAnnotatedSpans({
  required String text,
  required int baseOffset,
  required TextStyle style,
  required List<Annotation> annotations,
  required TextRange? ttsRange,
  required ReaderThemeColors colors,
}) {
  final length = text.length;
  if (length == 0) return [TextSpan(text: text, style: style)];

  int clamp(int offset) => (offset - baseOffset).clamp(0, length);

  // 收集所有区间边界（相对 text 的局部偏移）。
  final boundaries = <int>{0, length};
  final marks = <_Mark>[];

  for (final a in annotations) {
    if (a.type == AnnotationType.bookmark) continue;
    final start = clamp(a.start);
    final end = clamp(a.end);
    if (start >= end) continue;
    marks.add(_Mark(start, end, a.type == AnnotationType.note));
    boundaries
      ..add(start)
      ..add(end);
  }

  int ttsStart = -1, ttsEnd = -1;
  if (ttsRange != null) {
    ttsStart = clamp(ttsRange.start);
    ttsEnd = clamp(ttsRange.end);
    if (ttsStart < ttsEnd) {
      boundaries
        ..add(ttsStart)
        ..add(ttsEnd);
    }
  }

  final sorted = boundaries.toList()..sort();
  final spans = <TextSpan>[];

  for (var i = 0; i < sorted.length - 1; i++) {
    final segStart = sorted[i];
    final segEnd = sorted[i + 1];
    if (segStart >= segEnd) continue;

    final inTts = ttsStart <= segStart && segEnd <= ttsEnd && ttsStart >= 0;
    _Mark? mark;
    for (final m in marks) {
      if (m.start <= segStart && segEnd <= m.end) {
        mark = m;
        break;
      }
    }

    Color? background;
    TextDecoration? decoration;
    if (inTts) {
      background = colors.ttsHighlight;
    } else if (mark != null) {
      background = colors.highlight;
    }
    if (mark != null && mark.isNote) {
      decoration = TextDecoration.underline;
    }

    spans.add(TextSpan(
      text: text.substring(segStart, segEnd),
      style: style.copyWith(
        backgroundColor: background,
        decoration: decoration,
        decorationColor: colors.secondaryText,
        decorationStyle: TextDecorationStyle.dashed,
      ),
    ));
  }
  return spans;
}

class _Mark {
  const _Mark(this.start, this.end, this.isNote);

  final int start;
  final int end;
  final bool isNote;
}
