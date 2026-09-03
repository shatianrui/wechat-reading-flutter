import 'package:epubx/epubx.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';
import 'sample_books.dart';

/// 书籍内容仓库：负责把 TXT / EPUB 统一解析为 [Chapter] 列表。
/// 正式产品中此处对接下载 / 缓存 / 解密逻辑，MVP 阶段读取本地 Mock 数据。
class BookRepository {
  BookRepository._();

  static final BookRepository instance = BookRepository._();

  final Map<String, List<Chapter>> _cache = {};

  List<Book> get allBooks => sampleBooks;

  Book? bookById(String id) {
    for (final book in sampleBooks) {
      if (book.id == id) return book;
    }
    return null;
  }

  Future<List<Chapter>> loadChapters(Book book) async {
    final cached = _cache[book.id];
    if (cached != null) return cached;

    final List<Chapter> chapters;
    switch (book.format) {
      case BookFormat.txt:
        chapters = _parseTxt(book.txtContent ?? '');
      case BookFormat.epub:
        chapters = await _parseEpub(book.epubAssetPath!);
    }
    _cache[book.id] = chapters;
    return chapters;
  }

  /// TXT 解析：以「第X章」开头的行作为章节标题。
  static final RegExp _chapterTitle = RegExp(r'^第[一二三四五六七八九十百千0-9]+章.*$');

  List<Chapter> _parseTxt(String raw) {
    final lines = raw.split('\n');
    final chapters = <Chapter>[];
    String? title;
    final buffer = StringBuffer();

    void flush() {
      final content = buffer.toString().trim();
      if (title != null || content.isNotEmpty) {
        chapters.add(Chapter(title: title ?? '正文', content: content));
      }
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (_chapterTitle.hasMatch(trimmed)) {
        if (title != null || buffer.isNotEmpty) flush();
        title = trimmed;
      } else if (trimmed.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(trimmed);
      }
    }
    flush();
    return chapters;
  }

  Future<List<Chapter>> _parseEpub(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final epub = await EpubReader.readBook(bytes.buffer.asUint8List());
    final chapters = <Chapter>[];

    void collect(List<EpubChapter> list) {
      for (final ch in list) {
        final text = _htmlToPlainText(ch.HtmlContent ?? '');
        final title = ch.Title?.trim();
        if (text.isNotEmpty) {
          chapters.add(Chapter(
            title: (title == null || title.isEmpty)
                ? '第${chapters.length + 1}章'
                : title,
            content: text,
          ));
        }
        collect(ch.SubChapters ?? []);
      }
    }

    collect(epub.Chapters ?? []);

    // 部分 EPUB 没有目录结构，退化为按 spine 内容拆分。
    if (chapters.isEmpty) {
      final contents = epub.Content?.Html?.values ?? const [];
      var index = 1;
      for (final file in contents) {
        final text = _htmlToPlainText(file.Content ?? '');
        if (text.isNotEmpty) {
          chapters.add(Chapter(title: '第$index章', content: text));
          index++;
        }
      }
    }
    return chapters;
  }

  /// 极简 HTML -> 纯文本（演示用，正式产品应使用完整 HTML 渲染器）。
  String _htmlToPlainText(String html) {
    var text = html
        .replaceAll(RegExp(r'<head[\s\S]*?</head>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<h[1-6][^>]*>[\s\S]*?</h[1-6]>',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'</p>|<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"');
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    return lines.join('\n');
  }
}
