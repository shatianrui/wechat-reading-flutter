import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/chapter.dart';

/// EPUB 解析:基于 epubx 读取章节树,HTML 提取为纯文本段落。
///
/// v1 提取纯文本以保证分页/TTS/批注定位的一致性;
/// 富排版(插图、样式)可在后续版本用 WebView 渲染方案补充。
abstract final class EpubLoader {
  static Future<({String title, String author, List<Chapter> chapters})>
      load(Uint8List bytes) async {
    final epub = await EpubReader.readBook(bytes);

    final chapters = <Chapter>[];
    void addChapter(EpubChapter chapter, int depth) {
      final paragraphs = extractParagraphs(chapter.HtmlContent ?? '');
      final title = (chapter.Title ?? '').trim();
      if (paragraphs.isNotEmpty || title.isNotEmpty) {
        chapters.add(Chapter(
          title: title.isEmpty ? '第${chapters.length + 1}章' : title,
          paragraphs: paragraphs.isEmpty ? ['(本章无正文)'] : paragraphs,
        ));
      }
      for (final sub in chapter.SubChapters ?? <EpubChapter>[]) {
        addChapter(sub, depth + 1);
      }
    }

    for (final chapter in epub.Chapters ?? <EpubChapter>[]) {
      addChapter(chapter, 0);
    }

    // 无目录结构的 EPUB:按 spine 顺序读取 HTML 文件。
    if (chapters.isEmpty) {
      final htmlFiles = epub.Content?.Html;
      if (htmlFiles != null) {
        var index = 0;
        for (final entry in htmlFiles.entries) {
          index++;
          final paragraphs = extractParagraphs(entry.value.Content ?? '');
          if (paragraphs.isEmpty) continue;
          chapters.add(Chapter(title: '第$index章', paragraphs: paragraphs));
        }
      }
    }

    if (chapters.isEmpty) {
      chapters.add(const Chapter(title: '正文', paragraphs: ['(未能解析出正文内容)']));
    }

    return (
      title: (epub.Title ?? '').trim(),
      author: (epub.Author ?? '').trim(),
      chapters: chapters,
    );
  }

  /// 将 HTML 提取为段落列表(块级元素为段)。
  static List<String> extractParagraphs(String html) {
    if (html.trim().isEmpty) return const [];
    final document = html_parser.parse(html);
    final body = document.body;
    if (body == null) return const [];

    final paragraphs = <String>[];
    void walk(dom.Element element) {
      const blockTags = {
        'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'li', 'blockquote', 'pre', 'td',
      };
      final tag = element.localName ?? '';
      final hasBlockChild = element.children.any((c) {
        final t = c.localName ?? '';
        return blockTags.contains(t) || t == 'div' || t == 'section';
      });
      if (blockTags.contains(tag) || ((tag == 'div' || tag == 'section') && !hasBlockChild)) {
        final text = _normalize(element.text);
        if (text.isNotEmpty) paragraphs.add(text);
        return;
      }
      for (final child in element.children) {
        walk(child);
      }
    }

    walk(body);
    if (paragraphs.isEmpty) {
      final text = _normalize(body.text);
      if (text.isNotEmpty) {
        paragraphs.addAll(text.split('\n').where((s) => s.trim().isNotEmpty));
      }
    }
    return paragraphs;
  }

  static String _normalize(String text) => text
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\s*\n\s*'), '\n')
      .trim();
}
