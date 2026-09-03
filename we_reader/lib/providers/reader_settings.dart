import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器配色主题。
enum ReaderTheme { day, night, eyeCare }

/// 翻页方式。
enum PageTurnMode { slide, scroll }

/// 单个阅读主题的配色定义。
class ReaderThemeColors {
  const ReaderThemeColors({
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.highlight,
    required this.ttsHighlight,
    required this.brightness,
  });

  final Color background;
  final Color text;
  final Color secondaryText;

  /// 用户划线的底色。
  final Color highlight;

  /// TTS 朗读中当前句子的底色。
  final Color ttsHighlight;
  final Brightness brightness;
}

const Map<ReaderTheme, ReaderThemeColors> readerThemeColors = {
  ReaderTheme.day: ReaderThemeColors(
    background: Color(0xFFFAF6EE),
    text: Color(0xFF2B2B2B),
    secondaryText: Color(0xFF8A8778),
    highlight: Color(0x553D8BFF),
    ttsHighlight: Color(0x66FFC93D),
    brightness: Brightness.light,
  ),
  ReaderTheme.night: ReaderThemeColors(
    background: Color(0xFF121212),
    text: Color(0xFF9E9E9E),
    secondaryText: Color(0xFF5C5C5C),
    highlight: Color(0x4D3D8BFF),
    ttsHighlight: Color(0x40C7A93D),
    brightness: Brightness.dark,
  ),
  ReaderTheme.eyeCare: ReaderThemeColors(
    background: Color(0xFFCFE6C8),
    text: Color(0xFF2E3B2A),
    secondaryText: Color(0xFF6B7D66),
    highlight: Color(0x553D8BFF),
    ttsHighlight: Color(0x66E8B33D),
    brightness: Brightness.light,
  ),
};

/// 阅读器设置：字号、行距、主题、翻页方式、TTS 语速，全部持久化。
class ReaderSettings extends ChangeNotifier {
  ReaderSettings(this._prefs) {
    _fontSize = _prefs.getDouble(_kFontSize) ?? 18;
    _lineHeight = _prefs.getDouble(_kLineHeight) ?? 1.8;
    _theme = ReaderTheme
        .values[_prefs.getInt(_kTheme) ?? ReaderTheme.day.index];
    _pageTurnMode = PageTurnMode
        .values[_prefs.getInt(_kPageMode) ?? PageTurnMode.slide.index];
    _ttsRate = _prefs.getDouble(_kTtsRate) ?? 1.0;
  }

  static const _kFontSize = 'reader_font_size';
  static const _kLineHeight = 'reader_line_height';
  static const _kTheme = 'reader_theme';
  static const _kPageMode = 'reader_page_mode';
  static const _kTtsRate = 'reader_tts_rate';

  static const double minFontSize = 14;
  static const double maxFontSize = 28;

  final SharedPreferences _prefs;

  late double _fontSize;
  late double _lineHeight;
  late ReaderTheme _theme;
  late PageTurnMode _pageTurnMode;
  late double _ttsRate;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  ReaderTheme get theme => _theme;
  PageTurnMode get pageTurnMode => _pageTurnMode;

  /// TTS 语速倍率（0.5 - 2.0）。
  double get ttsRate => _ttsRate;

  ReaderThemeColors get colors => readerThemeColors[_theme]!;

  set fontSize(double value) {
    _fontSize = value.clamp(minFontSize, maxFontSize);
    _prefs.setDouble(_kFontSize, _fontSize);
    notifyListeners();
  }

  set lineHeight(double value) {
    _lineHeight = value;
    _prefs.setDouble(_kLineHeight, _lineHeight);
    notifyListeners();
  }

  set theme(ReaderTheme value) {
    _theme = value;
    _prefs.setInt(_kTheme, value.index);
    notifyListeners();
  }

  set pageTurnMode(PageTurnMode value) {
    _pageTurnMode = value;
    _prefs.setInt(_kPageMode, value.index);
    notifyListeners();
  }

  set ttsRate(double value) {
    _ttsRate = value.clamp(0.5, 2.0);
    _prefs.setDouble(_kTtsRate, _ttsRate);
    notifyListeners();
  }
}
