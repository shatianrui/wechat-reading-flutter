import 'package:flutter/foundation.dart';

import '../data/book_repository.dart';
import '../data/builtin_guide.dart';
import '../models/annotation.dart';
import '../models/book.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import '../storage/local_store.dart';

/// 全局图书馆状态:书架、进度、批注、统计,全部本地持久化。
class LibraryController extends ChangeNotifier {
  LibraryController(this._store);

  final LocalStore _store;

  final List<Book> _books = [];
  final Map<String, ReadingProgress> _progress = {};
  final List<Annotation> _annotations = [];
  ReadingStats _stats = const ReadingStats();

  List<Book> get books => List.unmodifiable(_books);
  List<Annotation> get annotations => List.unmodifiable(_annotations);
  ReadingStats get stats => _stats;

  void load() {
    _books.clear();
    final shelfJson = _store.readJsonList(StoreKeys.shelf);
    if (shelfJson != null) {
      _books.addAll(shelfJson
          .map((e) => Book.fromJson(e as Map<String, dynamic>)));
    }
    if (_books.isEmpty) {
      _books.add(BuiltinGuide.book);
    }

    _progress.clear();
    final progressJson = _store.readJsonList(StoreKeys.progress);
    if (progressJson != null) {
      for (final e in progressJson) {
        final p = ReadingProgress.fromJson(e as Map<String, dynamic>);
        _progress[p.bookId] = p;
      }
    }

    _annotations.clear();
    final annJson = _store.readJsonList(StoreKeys.annotations);
    if (annJson != null) {
      _annotations.addAll(
          annJson.map((e) => Annotation.fromJson(e as Map<String, dynamic>)));
    }

    final statsJson = _store.readJson(StoreKeys.stats);
    if (statsJson != null) {
      _stats = ReadingStats.fromJson(statsJson);
    }
    _rolloverToday();
    notifyListeners();
  }

  // ---- 书架 ----

  Future<void> importBook({
    required String sourceName,
    required Uint8List bytes,
  }) async {
    final book = await BookRepository.instance
        .importFile(sourceName: sourceName, bytes: bytes);
    _books.insert(0, book);
    await _saveShelf();
    notifyListeners();
  }

  Future<void> removeBook(Book book) async {
    _books.removeWhere((b) => b.id == book.id);
    _progress.remove(book.id);
    _annotations.removeWhere((a) => a.bookId == book.id);
    await BookRepository.instance.deleteBookFile(book);
    await _saveShelf();
    await _saveProgress();
    await _saveAnnotations();
    notifyListeners();
  }

  Future<void> _saveShelf() =>
      _store.writeJson(StoreKeys.shelf, _books.map((b) => b.toJson()).toList());

  // ---- 进度 ----

  ReadingProgress? progressFor(String bookId) => _progress[bookId];

  Future<void> updateProgress(ReadingProgress progress) async {
    // 冲突策略:最新时间戳优先(为将来云同步预留)。
    final old = _progress[progress.bookId];
    if (old != null && old.updatedAt.isAfter(progress.updatedAt)) return;
    _progress[progress.bookId] = progress;
    await _saveProgress();
    notifyListeners();
  }

  Future<void> _saveProgress() => _store.writeJson(
      StoreKeys.progress, _progress.values.map((p) => p.toJson()).toList());

  // ---- 批注 ----

  List<Annotation> annotationsFor(String bookId) =>
      _annotations.where((a) => a.bookId == bookId).toList()
        ..sort((a, b) {
          final c = a.chapterIndex.compareTo(b.chapterIndex);
          return c != 0 ? c : a.start.compareTo(b.start);
        });

  Future<void> addAnnotation(Annotation annotation) async {
    _annotations.add(annotation);
    await _saveAnnotations();
    notifyListeners();
  }

  Future<void> removeAnnotation(String id) async {
    _annotations.removeWhere((a) => a.id == id);
    await _saveAnnotations();
    notifyListeners();
  }

  bool hasBookmark(String bookId, int chapterIndex, int pageStart, int pageEnd) =>
      _annotations.any((a) =>
          a.bookId == bookId &&
          a.type == AnnotationType.bookmark &&
          a.chapterIndex == chapterIndex &&
          a.start >= pageStart &&
          a.start < pageEnd);

  Future<void> _saveAnnotations() => _store.writeJson(StoreKeys.annotations,
      _annotations.map((a) => a.toJson()).toList());

  // ---- 统计 ----

  Future<void> recordTime({int readSeconds = 0, int listenSeconds = 0}) async {
    _rolloverToday();
    _stats = _stats.copyWith(
      totalSeconds: _stats.totalSeconds + readSeconds + listenSeconds,
      todaySeconds: _stats.todaySeconds + readSeconds + listenSeconds,
      listenSeconds: _stats.listenSeconds + listenSeconds,
    );
    await _store.writeJson(StoreKeys.stats, _stats.toJson());
    notifyListeners();
  }

  Future<void> markFinished() async {
    _stats = _stats.copyWith(finishedBooks: _stats.finishedBooks + 1);
    await _store.writeJson(StoreKeys.stats, _stats.toJson());
    notifyListeners();
  }

  void _rolloverToday() {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_stats.todayKey != key) {
      _stats = _stats.copyWith(todayKey: key, todaySeconds: 0);
    }
  }
}
