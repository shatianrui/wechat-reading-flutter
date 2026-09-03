import '../models/chapter.dart';

/// TXT 章节切分器。
///
/// 识别常见中文小说章节标题:
/// - 「第x章 / 第x回 / 第x节 / 第x卷 / 第x部 / 第x集」(中文数字或阿拉伯数字)
/// - 「卷x」「序章」「楔子」「番外」「尾声」「后记」等
/// - 独立短行(前后空行、无句末标点)作为兜底标题
abstract final class TxtParser {
  static final RegExp _chapterPattern = RegExp(
    r'^\s*(?:'
    r'第\s*[0-9零一二三四五六七八九十百千万两]+\s*[章回节卷部集篇话]'
    r'|[Cc]hapter\s*\d+'
    r'|(?:序章|序言|自序|楔子|引子|番外|尾声|后记|终章|前言)'
    r')(?:\s|$|[::.、].{0,30}$|.{0,30}$)',
  );

  static final RegExp _endPunct = RegExp(r'[。!?!?…;;,,"]$');

  /// 将原始 TXT 文本切分为章节。无法识别章节时按字数分块。
  static List<Chapter> parse(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

    final titleIndexes = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.length <= 40 && _chapterPattern.hasMatch(line)) {
        titleIndexes.add(i);
      }
    }

    // 章节标题太少时尝试「独立短行」兜底;仍不行则按字数分块。
    if (titleIndexes.length < 2) {
      return _fallbackSplit(lines);
    }

    final chapters = <Chapter>[];
    // 第一个标题前的内容作为「开卷」。
    if (titleIndexes.first > 0) {
      final head = _collectParagraphs(lines, 0, titleIndexes.first);
      if (head.isNotEmpty) {
        chapters.add(Chapter(title: '开卷', paragraphs: head));
      }
    }
    for (var t = 0; t < titleIndexes.length; t++) {
      final start = titleIndexes[t];
      final end =
          t + 1 < titleIndexes.length ? titleIndexes[t + 1] : lines.length;
      final paragraphs = _collectParagraphs(lines, start + 1, end);
      chapters.add(Chapter(
        title: lines[start].trim(),
        paragraphs: paragraphs.isEmpty ? ['(本章无正文)'] : paragraphs,
      ));
    }
    return chapters;
  }

  static List<String> _collectParagraphs(
      List<String> lines, int start, int end) {
    final paragraphs = <String>[];
    for (var i = start; i < end; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      paragraphs.add(line);
    }
    return paragraphs;
  }

  /// 无章节结构时:先尝试把「短且无句末标点的独立行」当标题,
  /// 否则每 ~2000 字切一块。
  static List<Chapter> _fallbackSplit(List<String> lines) {
    final titleIndexes = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length > 20) continue;
      if (_endPunct.hasMatch(line)) continue;
      final prevBlank = i == 0 || lines[i - 1].trim().isEmpty;
      final nextBlank = i + 1 >= lines.length || lines[i + 1].trim().isEmpty;
      if (prevBlank && nextBlank) titleIndexes.add(i);
    }

    final paragraphs = _collectParagraphs(lines, 0, lines.length);
    if (titleIndexes.length >= 3 &&
        titleIndexes.length <= paragraphs.length ~/ 2) {
      final chapters = <Chapter>[];
      for (var t = 0; t < titleIndexes.length; t++) {
        final start = titleIndexes[t];
        final end =
            t + 1 < titleIndexes.length ? titleIndexes[t + 1] : lines.length;
        final body = _collectParagraphs(lines, start + 1, end);
        if (t == 0 && titleIndexes.first > 0) {
          final head = _collectParagraphs(lines, 0, titleIndexes.first);
          if (head.isNotEmpty) {
            chapters.add(Chapter(title: '开卷', paragraphs: head));
          }
        }
        chapters.add(Chapter(
          title: lines[start].trim(),
          paragraphs: body.isEmpty ? ['(本章无正文)'] : body,
        ));
      }
      return chapters;
    }

    // 按字数分块。
    const blockSize = 2000;
    final chapters = <Chapter>[];
    var current = <String>[];
    var count = 0;
    for (final p in paragraphs) {
      current.add(p);
      count += p.length;
      if (count >= blockSize) {
        chapters.add(
            Chapter(title: '第${chapters.length + 1}节', paragraphs: current));
        current = <String>[];
        count = 0;
      }
    }
    if (current.isNotEmpty) {
      chapters.add(
          Chapter(title: '第${chapters.length + 1}节', paragraphs: current));
    }
    if (chapters.isEmpty) {
      chapters.add(const Chapter(title: '正文', paragraphs: ['(空白文件)']));
    }
    return chapters;
  }
}
