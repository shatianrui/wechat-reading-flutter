import 'package:flutter_test/flutter_test.dart';

import 'package:we_reader/core/content/txt_parser.dart';
import 'package:we_reader/features/reader/tts_controller.dart';

void main() {
  group('TxtParser', () {
    test('识别「第x章」标题', () {
      const raw = '''
第一章 起风了

风从山谷里吹来。少年抬起头。

第二章 落雨时

雨点敲打着屋檐。
''';
      final chapters = TxtParser.parse(raw);
      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章 起风了');
      expect(chapters[0].paragraphs.length, 1);
      expect(chapters[1].title, '第二章 落雨时');
    });

    test('无章节结构时按块切分', () {
      final raw = List.generate(100, (i) => '这是第$i段,平平无奇的正文内容,用于验证分块逻辑是否稳定可靠。').join('\n');
      final chapters = TxtParser.parse(raw);
      expect(chapters, isNotEmpty);
      expect(chapters.first.paragraphs, isNotEmpty);
    });
  });

  group('句子切分(听读联动)', () {
    test('按中文句读切分并保留偏移', () {
      const text = '\u3000\u3000春天来了。花开了!你听见了吗?';
      final sentences = TtsController.splitSentences(text, 0);
      expect(sentences.length, 3);
      expect(sentences[0].text, '春天来了。');
      expect(text.substring(sentences[1].start, sentences[1].end), '花开了!');
      // 区间连续覆盖全文。
      expect(sentences.first.start, 0);
      expect(sentences.last.end, text.length);
    });
  });
}
