import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:we_reader/data/sample_books.dart';
import 'package:we_reader/models/models.dart';
import 'package:we_reader/reader/pagination.dart';
import 'package:we_reader/reader/sentence_splitter.dart';

void main() {
  group('分句', () {
    test('按中文标点切句并保留偏移', () {
      const text = '第一句。第二句！第三句？最后没有标点';
      final sentences = splitSentences(text);
      expect(sentences.length, 4);
      expect(sentences[0].text, '第一句。');
      expect(sentences[0].start, 0);
      expect(sentences[0].end, 4);
      expect(sentences[3].text, '最后没有标点');
      // 偏移可还原原文。
      for (final s in sentences) {
        expect(text.substring(s.start, s.end).trim(), s.text);
      }
    });

    test('连续标点并入当前句', () {
      final sentences = splitSentences('真的吗？！当然。');
      expect(sentences.length, 2);
      expect(sentences[0].text, '真的吗？！');
    });
  });

  group('分页', () {
    test('页区间连续且覆盖全文', () {
      const text = '这是一段用于测试分页的中文文本，'
          '它需要足够长才能产生多页。\n'
          '第二段继续补充一些文字，确保跨行与跨页的边界都被覆盖到，'
          '分页应当在整行处断开，并且各页区间首尾相接。';
      final ranges = Paginator.paginateChapter(
        text: text,
        style: const TextStyle(fontSize: 20, height: 2.0),
        pageSize: const Size(200, 120),
      );
      expect(ranges.length, greaterThan(1));
      expect(ranges.first.start, 0);
      expect(ranges.last.end, text.length);
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].start, ranges[i - 1].end);
      }
    });
  });

  group('示例书库', () {
    test('TXT 书籍章节标题可被解析出来', () {
      for (final book in sampleBooks.where(
        (b) => b.format == BookFormat.txt,
      )) {
        final titles = RegExp(r'^第.+章.*$', multiLine: true)
            .allMatches(book.txtContent!)
            .length;
        expect(titles, greaterThanOrEqualTo(3),
            reason: '${book.title} 至少 3 章');
      }
    });
  });
}
