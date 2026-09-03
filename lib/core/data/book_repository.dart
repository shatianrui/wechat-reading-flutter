import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../content/epub_loader.dart';
import '../content/text_decoder.dart';
import '../content/txt_parser.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import 'builtin_guide.dart';

/// 书籍仓库:文件导入、内容解析与缓存。
///
/// 将来接入云书架时,此层负责本地文件与远端内容源的统一调度。
class BookRepository {
  BookRepository._();

  static final BookRepository instance = BookRepository._();

  final Map<String, BookContent> _cache = {};

  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/books');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 从用户选择的文件导入书籍:复制到沙盒并解析元数据。
  Future<Book> importFile({
    required String sourceName,
    required Uint8List bytes,
  }) async {
    final lower = sourceName.toLowerCase();
    final isEpub = lower.endsWith('.epub');
    final id = 'b${DateTime.now().millisecondsSinceEpoch}';
    final ext = isEpub ? 'epub' : 'txt';
    final fileName = '$id.$ext';

    final dir = await _booksDir();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    var title = sourceName.replaceAll(RegExp(r'\.(epub|txt)$', caseSensitive: false), '');
    var author = '';
    int wordCount;

    if (isEpub) {
      final parsed = await EpubLoader.load(bytes);
      if (parsed.title.isNotEmpty) title = parsed.title;
      author = parsed.author;
      wordCount = parsed.chapters.fold(0, (s, c) => s + c.charCount);
      _cache[id] = BookContent(bookId: id, chapters: parsed.chapters);
    } else {
      final text = TextDecoder.decode(bytes);
      final chapters = TxtParser.parse(text);
      wordCount = chapters.fold(0, (s, c) => s + c.charCount);
      _cache[id] = BookContent(bookId: id, chapters: chapters);
    }

    return Book(
      id: id,
      title: title.trim().isEmpty ? '未命名书籍' : title.trim(),
      author: author,
      fileName: fileName,
      contentType: isEpub ? BookContentType.epub : BookContentType.txt,
      importedAt: DateTime.now(),
      wordCount: wordCount,
      coverSeed: title.hashCode.abs(),
    );
  }

  /// 加载书籍内容(带内存缓存)。
  Future<BookContent> loadContent(Book book) async {
    final cached = _cache[book.id];
    if (cached != null) return cached;

    if (book.id == BuiltinGuide.bookId) {
      final content =
          BookContent(bookId: book.id, chapters: BuiltinGuide.chapters);
      _cache[book.id] = content;
      return content;
    }

    final dir = await _booksDir();
    final file = File('${dir.path}/${book.fileName}');
    if (!await file.exists()) {
      return BookContent(bookId: book.id, chapters: const [
        Chapter(title: '文件缺失', paragraphs: ['原始文件已被删除,请重新导入。']),
      ]);
    }
    final bytes = await file.readAsBytes();

    late final List<Chapter> chapters;
    if (book.contentType == BookContentType.epub) {
      final parsed = await EpubLoader.load(bytes);
      chapters = parsed.chapters;
    } else {
      chapters = TxtParser.parse(TextDecoder.decode(bytes));
    }
    final content = BookContent(bookId: book.id, chapters: chapters);
    _cache[book.id] = content;
    return content;
  }

  /// 删除书籍文件并清缓存。
  Future<void> deleteBookFile(Book book) async {
    _cache.remove(book.id);
    if (book.fileName.isEmpty) return;
    final dir = await _booksDir();
    final file = File('${dir.path}/${book.fileName}');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
