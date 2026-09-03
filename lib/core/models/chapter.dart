/// 章节与整书内容模型。
class Chapter {
  const Chapter({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  /// 阅读器使用的纯文本:段落间以换行分隔,段首缩进两格(全角空格)。
  String get displayText =>
      paragraphs.map((p) => '\u3000\u3000${p.trim()}').join('\n');

  int get charCount =>
      paragraphs.fold(0, (sum, p) => sum + p.length) + title.length;
}

/// 一本书解析后的完整内容。
class BookContent {
  const BookContent({required this.bookId, required this.chapters});

  final String bookId;
  final List<Chapter> chapters;

  int get totalChars =>
      chapters.fold(0, (sum, c) => sum + c.charCount);
}
