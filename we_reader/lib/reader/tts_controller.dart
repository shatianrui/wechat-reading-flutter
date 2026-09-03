import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/models.dart';
import 'sentence_splitter.dart';

/// TTS 听书控制器：逐句朗读、当前句高亮、语速控制、自动跨章。
///
/// MVP 使用系统 TTS（flutter_tts：iOS AVSpeechSynthesizer / Android TTS）。
/// 接入云端语音（Azure TTS / 讯飞开放平台）的方式：
/// 把 [_speakSentence] 替换为「请求云端合成音频 + 本地播放」，
/// 其余逐句调度、高亮与语速逻辑均可复用；
/// 云端返回的音素/字级时间戳还可以把高亮粒度细化到字。
class TtsController extends ChangeNotifier {
  TtsController();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  List<Chapter> _chapters = [];
  List<Sentence> _sentences = [];
  int _chapterIndex = 0;
  int _sentenceIndex = 0;

  /// 是否处于听书会话中（包含暂停状态）。
  bool _active = false;

  /// 是否正在朗读（未暂停）。
  bool _playing = false;
  double _rate = 1.0;
  int _session = 0;

  /// 当前句变化时通知（用于翻页跟随）。
  void Function(int chapterIndex, Sentence sentence)? onSentenceChanged;

  /// 全书读完时通知。
  VoidCallback? onBookFinished;

  bool get isActive => _active;
  bool get isPlaying => _playing;
  int get chapterIndex => _chapterIndex;
  double get rate => _rate;

  /// 当前朗读句在章节内的区间（用于渲染高亮）。
  TextRange? get currentRange {
    if (!_active || _sentenceIndex >= _sentences.length) return null;
    final s = _sentences[_sentenceIndex];
    return TextRange(start: s.start, end: s.end);
  }

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('zh-CN');
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // 模拟器 / 桌面端可能没有 TTS 引擎，忽略并走兜底延时逻辑。
    }
  }

  /// 从指定章节与偏移开始听书。
  Future<void> start({
    required List<Chapter> chapters,
    required int chapterIndex,
    int fromOffset = 0,
    required double rate,
  }) async {
    await stop();
    await _ensureInit();
    _chapters = chapters;
    _chapterIndex = chapterIndex.clamp(0, chapters.length - 1);
    _rate = rate;
    _sentences = splitSentences(_chapters[_chapterIndex].content);
    _sentenceIndex = _sentences.indexWhere((s) => s.end > fromOffset);
    if (_sentenceIndex < 0) _sentenceIndex = 0;
    _active = true;
    _playing = true;
    notifyListeners();
    _speakLoop(++_session);
  }

  /// 暂停（通过 stop 实现，恢复时从当前句重读，跨平台行为一致）。
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    _session++;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!_active || _playing) return;
    _playing = true;
    notifyListeners();
    _speakLoop(++_session);
  }

  /// 结束听书会话。
  Future<void> stop() async {
    _active = false;
    _playing = false;
    _session++;
    notifyListeners();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// 调整语速；朗读中从当前句立即生效。
  Future<void> setRate(double rate) async {
    _rate = rate;
    notifyListeners();
    if (_playing) {
      _session++;
      try {
        await _tts.stop();
      } catch (_) {}
      _speakLoop(++_session);
    }
  }

  /// 跳到上一章 / 下一章继续朗读。
  Future<void> skipToChapter(int chapterIndex) async {
    if (!_active || chapterIndex < 0 || chapterIndex >= _chapters.length) {
      return;
    }
    _session++;
    try {
      await _tts.stop();
    } catch (_) {}
    _chapterIndex = chapterIndex;
    _sentences = splitSentences(_chapters[_chapterIndex].content);
    _sentenceIndex = 0;
    notifyListeners();
    if (_playing) _speakLoop(++_session);
  }

  Future<void> _speakLoop(int session) async {
    while (_playing && session == _session) {
      if (_sentenceIndex >= _sentences.length) {
        // 本章读完，自动进入下一章。
        if (_chapterIndex + 1 < _chapters.length) {
          _chapterIndex++;
          _sentences = splitSentences(_chapters[_chapterIndex].content);
          _sentenceIndex = 0;
        } else {
          await stop();
          onBookFinished?.call();
          return;
        }
      }
      final sentence = _sentences[_sentenceIndex];
      onSentenceChanged?.call(_chapterIndex, sentence);
      notifyListeners();
      await _speakSentence(sentence);
      if (session != _session) return;
      _sentenceIndex++;
    }
  }

  /// 朗读单句。云端 TTS（Azure / 讯飞）接入点：替换本方法即可。
  Future<void> _speakSentence(Sentence sentence) async {
    // flutter_tts 语速：0.5 约为常速，按用户倍率映射。
    final platformRate = (0.5 * _rate).clamp(0.1, 1.0);
    final stopwatch = Stopwatch()..start();
    try {
      await _tts.setSpeechRate(platformRate);
      await _tts.speak(sentence.text);
    } catch (_) {
      // 无 TTS 引擎时静默失败。
    }
    // 兜底：无引擎（或引擎立即返回）时按字数模拟朗读时长，
    // 保证「当前句高亮 + 自动翻页」在任何环境都可演示。
    final expectedMs = (sentence.text.length * 220 / _rate).round();
    final remaining = expectedMs - stopwatch.elapsedMilliseconds;
    if (remaining > 0 && stopwatch.elapsedMilliseconds < 300) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
  }

  @override
  void dispose() {
    _session++;
    _tts.stop();
    super.dispose();
  }
}
