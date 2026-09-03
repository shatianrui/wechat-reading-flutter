import 'package:flutter/material.dart';

import '../storage/local_store.dart';

/// 阅读主题(仿微信读书四色:白纸/米黄/护眼绿/夜间)。
enum ReaderThemeKind { paper, sepia, green, night }

class ReaderTheme {
  const ReaderTheme({
    required this.kind,
    required this.label,
    required this.background,
    required this.surface,
    required this.text,
    required this.secondaryText,
    required this.highlight,
    required this.ttsHighlight,
  });

  final ReaderThemeKind kind;
  final String label;
  final Color background;
  final Color surface;
  final Color text;
  final Color secondaryText;

  /// 划线底色。
  final Color highlight;

  /// 听读联动的当前句底色。
  final Color ttsHighlight;

  bool get isDark => kind == ReaderThemeKind.night;

  static const paper = ReaderTheme(
    kind: ReaderThemeKind.paper,
    label: '白纸',
    background: Color(0xFFFAFAF8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF2A2A2A),
    secondaryText: Color(0xFF8A8A86),
    highlight: Color(0x3355A8F0),
    ttsHighlight: Color(0x2E43A047),
  );

  static const sepia = ReaderTheme(
    kind: ReaderThemeKind.sepia,
    label: '米黄',
    background: Color(0xFFF5EFDF),
    surface: Color(0xFFFBF6E9),
    text: Color(0xFF3D3528),
    secondaryText: Color(0xFF97907C),
    highlight: Color(0x33D08718),
    ttsHighlight: Color(0x3343A047),
  );

  static const green = ReaderTheme(
    kind: ReaderThemeKind.green,
    label: '护眼',
    background: Color(0xFFDDEEDD),
    surface: Color(0xFFE9F5E9),
    text: Color(0xFF25382A),
    secondaryText: Color(0xFF7C9482),
    highlight: Color(0x333F84D6),
    ttsHighlight: Color(0x38268C3C),
  );

  static const night = ReaderTheme(
    kind: ReaderThemeKind.night,
    label: '夜间',
    background: Color(0xFF17181A),
    surface: Color(0xFF222326),
    text: Color(0xFF9FA3A8),
    secondaryText: Color(0xFF5E6165),
    highlight: Color(0x40497FBF),
    ttsHighlight: Color(0x3A2F7D43),
  );

  static const all = [paper, sepia, green, night];

  static ReaderTheme of(ReaderThemeKind kind) =>
      all.firstWhere((t) => t.kind == kind, orElse: () => paper);
}

/// 翻页模式。
enum PageTurnMode { slide, scroll }

/// 阅读器设置(持久化)。
class ReaderSettingsController extends ChangeNotifier {
  ReaderSettingsController(this._store) {
    final json = _store.readJson(StoreKeys.readerSettings);
    if (json != null) {
      _fontSize = (json['fontSize'] as num?)?.toDouble() ?? 18;
      _lineHeight = (json['lineHeight'] as num?)?.toDouble() ?? 1.9;
      _themeKind = ReaderThemeKind.values.firstWhere(
        (e) => e.name == (json['theme'] as String? ?? 'paper'),
        orElse: () => ReaderThemeKind.paper,
      );
      _pageMode = PageTurnMode.values.firstWhere(
        (e) => e.name == (json['pageMode'] as String? ?? 'slide'),
        orElse: () => PageTurnMode.slide,
      );
      _ttsRate = (json['ttsRate'] as num?)?.toDouble() ?? 0.5;
      _useSerif = json['useSerif'] as bool? ?? false;
    }
  }

  final LocalStore _store;

  double _fontSize = 18;
  double _lineHeight = 1.9;
  ReaderThemeKind _themeKind = ReaderThemeKind.paper;
  PageTurnMode _pageMode = PageTurnMode.slide;
  double _ttsRate = 0.5;
  bool _useSerif = false;

  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  ReaderTheme get theme => ReaderTheme.of(_themeKind);
  PageTurnMode get pageMode => _pageMode;
  double get ttsRate => _ttsRate;
  bool get useSerif => _useSerif;

  /// 正文样式;中文排版:衬线可选,系统字体兜底。
  TextStyle bodyStyle(ReaderTheme theme) => TextStyle(
        fontSize: _fontSize,
        height: _lineHeight,
        color: theme.text,
        letterSpacing: 0.2,
        fontFamilyFallback: _useSerif
            ? const ['Songti SC', 'STSong', 'Noto Serif CJK SC', 'serif']
            : null,
      );

  set fontSize(double v) {
    _fontSize = v.clamp(13, 30);
    _save();
  }

  set lineHeight(double v) {
    _lineHeight = v.clamp(1.4, 2.4);
    _save();
  }

  set themeKind(ReaderThemeKind v) {
    _themeKind = v;
    _save();
  }

  set pageMode(PageTurnMode v) {
    _pageMode = v;
    _save();
  }

  set ttsRate(double v) {
    _ttsRate = v.clamp(0.2, 1.0);
    _save();
  }

  set useSerif(bool v) {
    _useSerif = v;
    _save();
  }

  void _save() {
    _store.writeJson(StoreKeys.readerSettings, {
      'fontSize': _fontSize,
      'lineHeight': _lineHeight,
      'theme': _themeKind.name,
      'pageMode': _pageMode.name,
      'ttsRate': _ttsRate,
      'useSerif': _useSerif,
    });
    notifyListeners();
  }
}
