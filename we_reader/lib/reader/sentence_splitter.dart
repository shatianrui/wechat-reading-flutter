/// 带偏移信息的句子，用于 TTS 朗读与当前句高亮。
class Sentence {
  const Sentence({required this.start, required this.end, required this.text});

  /// 章节内起始偏移（含）。
  final int start;

  /// 章节内结束偏移（不含）。
  final int end;
  final String text;
}

const _sentenceBreakers = {'。', '！', '？', '；', '…', '\n'};
const _trailingQuotes = {'」', '』', '"', '\u2019', ')', '）'};

/// 按中文标点把章节文本切成句子，保留每句在章节内的偏移。
List<Sentence> splitSentences(String text) {
  final sentences = <Sentence>[];
  var start = 0;

  void addSentence(int end) {
    final raw = text.substring(start, end);
    final trimmed = raw.trim();
    if (trimmed.isNotEmpty) {
      // 偏移按原始区间记录，保证与正文高亮对齐。
      sentences.add(Sentence(start: start, end: end, text: trimmed));
    }
    start = end;
  }

  var i = 0;
  while (i < text.length) {
    if (_sentenceBreakers.contains(text[i])) {
      var end = i + 1;
      // 连续标点（如 ……、！？）与右引号并入当前句。
      while (end < text.length &&
          (_sentenceBreakers.contains(text[end]) ||
              _trailingQuotes.contains(text[end]))) {
        end++;
      }
      addSentence(end);
      i = end;
    } else {
      i++;
    }
  }
  if (start < text.length) addSentence(text.length);
  return sentences;
}
