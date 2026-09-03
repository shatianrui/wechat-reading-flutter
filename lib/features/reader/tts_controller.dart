import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'pagination.dart';

/// 句子切片:章内字符区间。
class SentenceSlice {
  const SentenceSlice({
    required this.chapterIndex,
    required this.start,
    required this.end,
    required this.text,
  });

  final int chapterIndex;
  final int start;
  final int end;
  final String text;
}

/// 听书控制器:系统 TTS 逐句朗读 + 听读联动。
///
/// v1 使用平台离线语音(iOS AVSpeechSynthesizer / Android TTS)。
/// 云端高品质音色(Azure / 讯飞)接入点:替换 [_speak] 为云端合成音频流播放,
/// 句子边界与高亮逻辑无需改动。
class TtsController extends ChangeNotifier {
  TtsController({required this.rate}) {
    _tts.setCompletionHandler(_onSentenceDone);
    _tts.setCancelHandler(() {});
  }

  final FlutterTts _tts = FlutterTts();
  double rate;

  PaginatedBook? _book;
  List<SentenceSlice> _sentences = [];
  int _sentenceIndex = -1;
  bool _active = false;
  bool _playing = false;
  bool _initialized = false;
  int _speakToken = 0;

  DateTime? _playStartedAt;
  int _accumulatedListenSeconds = 0;

  /// 当前朗读的句子(用于渲染高亮与自动翻页)。
  SentenceSlice? get currentSentence =>
      _active && _sentenceIndex >= 0 && _sentenceIndex < _sentences.length
          ? _sentences[_sentenceIndex]
          : null;

  bool get active => _active;
  bool get playing => _playing;

  /// 本次会话累计听书秒数。
  int get listenSeconds {
    var total = _accumulatedListenSeconds;
    final started = _playStartedAt;
    if (started != null) {
      total += DateTime.now().difference(started).inSeconds;
    }
    return total;
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(rate);
      // iOS:允许后台/静音开关下播放。
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
        IosTextToSpeechAudioMode.spokenAudio,
      );
    } catch (_) {
      // 桌面/模拟器可能缺少中文语音,静默降级。
    }
  }

  /// 从指定位置开始听书。
  Future<void> start({
    required PaginatedBook book,
    required int chapterIndex,
    required int charOffset,
  }) async {
    await _ensureInit();
    _book = book;
    _loadChapterSentences(chapterIndex);
    _sentenceIndex = _sentences.indexWhere(
        (s) => charOffset >= s.start && charOffset < s.end);
    if (_sentenceIndex < 0) _sentenceIndex = 0;
    _active = true;
    await _play();
  }

  Future<void> toggle() async {
    if (_playing) {
      await pause();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    if (!_active || currentSentence == null) return;
    _playing = true;
    _playStartedAt ??= DateTime.now();
    notifyListeners();
    await _speakCurrent();
  }

  Future<void> pause() async {
    _playing = false;
    _flushListenTime();
    _speakToken++;
    await _tts.stop();
    notifyListeners();
  }

  Future<void> stop() async {
    _active = false;
    _playing = false;
    _flushListenTime();
    _speakToken++;
    await _tts.stop();
    notifyListeners();
  }

  Future<void> setRate(double value) async {
    rate = value;
    await _tts.setSpeechRate(value);
    // 语速变化立即生效:重读当前句。
    if (_playing) {
      _speakToken++;
      await _tts.stop();
      await _speakCurrent();
    }
  }

  Future<void> skipSentence(int delta) async {
    if (!_active) return;
    final next = _sentenceIndex + delta;
    if (next < 0 || next >= _sentences.length) {
      await _advanceChapter(delta > 0 ? 1 : -1);
      return;
    }
    _sentenceIndex = next;
    notifyListeners();
    if (_playing) {
      _speakToken++;
      await _tts.stop();
      await _speakCurrent();
    }
  }

  Future<void> _speakCurrent() async {
    final sentence = currentSentence;
    if (sentence == null) return;
    final token = ++_speakToken;
    try {
      await _tts.speak(sentence.text);
    } catch (_) {
      // 朗读失败(如缺语音包):停止,避免死循环。
      if (token == _speakToken) await stop();
    }
  }

  void _onSentenceDone() {
    if (!_playing || !_active) return;
    final token = _speakToken;
    Future<void>(() async {
      if (token != _speakToken) return;
      if (_sentenceIndex + 1 < _sentences.length) {
        _sentenceIndex++;
        notifyListeners();
        await _speakCurrent();
      } else {
        await _advanceChapter(1);
      }
    });
  }

  Future<void> _advanceChapter(int delta) async {
    final book = _book;
    if (book == null) return;
    final current = _sentences.isEmpty
        ? 0
        : _sentences[_sentenceIndex.clamp(0, _sentences.length - 1)]
            .chapterIndex;
    final next = current + delta;
    if (next < 0 || next >= book.chapterTexts.length) {
      await stop();
      return;
    }
    _loadChapterSentences(next);
    _sentenceIndex = 0;
    notifyListeners();
    if (_playing) await _speakCurrent();
  }

  void _loadChapterSentences(int chapterIndex) {
    final book = _book;
    if (book == null) return;
    _sentences = splitSentences(book.chapterTexts[chapterIndex], chapterIndex);
  }

  void _flushListenTime() {
    final started = _playStartedAt;
    if (started != null) {
      _accumulatedListenSeconds +=
          DateTime.now().difference(started).inSeconds;
      _playStartedAt = null;
    }
  }

  /// 按中文句读切分,保留定位区间。
  @visibleForTesting
  static List<SentenceSlice> splitSentences(String text, int chapterIndex) {
    final result = <SentenceSlice>[];
    final breaker = RegExp(r'[。!?;!?;…\n]+["」』”]?');
    var start = 0;
    for (final match in breaker.allMatches(text)) {
      final end = match.end;
      final raw = text.substring(start, end);
      final spoken = raw.replaceAll('\u3000', '').trim();
      if (spoken.isNotEmpty) {
        result.add(SentenceSlice(
          chapterIndex: chapterIndex,
          start: start,
          end: end,
          text: spoken,
        ));
      }
      start = end;
    }
    if (start < text.length) {
      final raw = text.substring(start);
      final spoken = raw.replaceAll('\u3000', '').trim();
      if (spoken.isNotEmpty) {
        result.add(SentenceSlice(
          chapterIndex: chapterIndex,
          start: start,
          end: text.length,
          text: spoken,
        ));
      }
    }
    if (result.isEmpty) {
      result.add(SentenceSlice(
          chapterIndex: chapterIndex, start: 0, end: text.length, text: text));
    }
    return result;
  }

  @override
  void dispose() {
    _flushListenTime();
    _speakToken++;
    _tts.stop();
    super.dispose();
  }
}
