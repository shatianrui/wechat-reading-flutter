import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 全局应用状态：书架、阅读进度、标注、阅读统计。
///
/// 持久化：全部使用 shared_preferences 存 JSON。
/// 云同步（未来）：每条进度 / 标注都带 updatedAt / createdAt 毫秒时间戳，
/// 同步时与服务端逐条对比，「最新时间戳获胜」（last-write-wins）。
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _load();
  }

  static const _kShelf = 'shelf_v1';
  static const _kProgress = 'progress_v1';
  static const _kAnnotations = 'annotations_v1';
  static const _kStats = 'stats_v1';

  final SharedPreferences _prefs;

  final List<String> _shelfBookIds = [];
  final Map<String, ReadingProgress> _progress = {};
  final List<Annotation> _annotations = [];

  /// 按天统计的阅读秒数，key 为 yyyy-MM-dd。
  final Map<String, int> _readingSecondsByDay = {};

  List<String> get shelfBookIds => List.unmodifiable(_shelfBookIds);

  bool isOnShelf(String bookId) => _shelfBookIds.contains(bookId);

  ReadingProgress? progressOf(String bookId) => _progress[bookId];

  List<Annotation> annotationsOf(String bookId) =>
      _annotations.where((a) => a.bookId == bookId).toList();

  List<Annotation> get allAnnotations => List.unmodifiable(_annotations);

  int get totalReadingSeconds =>
      _readingSecondsByDay.values.fold(0, (sum, s) => sum + s);

  int get todayReadingSeconds => _readingSecondsByDay[_todayKey()] ?? 0;

  int get readingDays => _readingSecondsByDay.length;

  int get noteCount =>
      _annotations.where((a) => a.type != AnnotationType.bookmark).length;

  int get finishedBookCount =>
      _progress.values.where((p) => p.percent >= 0.98).length;

  // ---------- 书架 ----------

  void addToShelf(String bookId) {
    if (_shelfBookIds.contains(bookId)) return;
    _shelfBookIds.insert(0, bookId);
    _prefs.setStringList(_kShelf, _shelfBookIds);
    notifyListeners();
  }

  void removeFromShelf(String bookId) {
    _shelfBookIds.remove(bookId);
    _prefs.setStringList(_kShelf, _shelfBookIds);
    notifyListeners();
  }

  // ---------- 阅读进度 ----------

  void saveProgress(ReadingProgress progress) {
    _progress[progress.bookId] = progress;
    // 最近阅读的书移到书架最前。
    if (_shelfBookIds.remove(progress.bookId)) {
      _shelfBookIds.insert(0, progress.bookId);
      _prefs.setStringList(_kShelf, _shelfBookIds);
    }
    _prefs.setString(
      _kProgress,
      jsonEncode(_progress.map((k, v) => MapEntry(k, v.toJson()))),
    );
    notifyListeners();
  }

  // ---------- 标注 ----------

  void addAnnotation(Annotation annotation) {
    _annotations.add(annotation);
    _saveAnnotations();
    notifyListeners();
  }

  void removeAnnotation(String id) {
    _annotations.removeWhere((a) => a.id == id);
    _saveAnnotations();
    notifyListeners();
  }

  /// 当前章节某一页是否已有书签（按页首偏移所在区间判断）。
  Annotation? bookmarkAt(String bookId, int chapterIndex, int start, int end) {
    for (final a in _annotations) {
      if (a.type == AnnotationType.bookmark &&
          a.bookId == bookId &&
          a.chapterIndex == chapterIndex &&
          a.start >= start &&
          a.start < end) {
        return a;
      }
    }
    return null;
  }

  void _saveAnnotations() {
    _prefs.setString(
      _kAnnotations,
      jsonEncode(_annotations.map((a) => a.toJson()).toList()),
    );
  }

  // ---------- 阅读统计 ----------

  void addReadingSeconds(int seconds) {
    if (seconds <= 0) return;
    final key = _todayKey();
    _readingSecondsByDay[key] = (_readingSecondsByDay[key] ?? 0) + seconds;
    _prefs.setString(_kStats, jsonEncode(_readingSecondsByDay));
    notifyListeners();
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ---------- 加载 ----------

  void _load() {
    _shelfBookIds
      ..clear()
      ..addAll(_prefs.getStringList(_kShelf) ?? const []);

    final progressJson = _prefs.getString(_kProgress);
    if (progressJson != null) {
      final map = jsonDecode(progressJson) as Map<String, dynamic>;
      map.forEach((key, value) {
        _progress[key] =
            ReadingProgress.fromJson(value as Map<String, dynamic>);
      });
    }

    final annotationsJson = _prefs.getString(_kAnnotations);
    if (annotationsJson != null) {
      final list = jsonDecode(annotationsJson) as List<dynamic>;
      _annotations.addAll(
        list.map((e) => Annotation.fromJson(e as Map<String, dynamic>)),
      );
    }

    final statsJson = _prefs.getString(_kStats);
    if (statsJson != null) {
      final map = jsonDecode(statsJson) as Map<String, dynamic>;
      map.forEach((key, value) {
        _readingSecondsByDay[key] = value as int;
      });
    }
  }
}
