import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/state/library_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/book_cover.dart';
import '../reader/reader_page.dart';

/// 书架:用户导入的全部书籍 + 阅读进度。
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  bool _importing = false;

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final library = context.read<LibraryController>();
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['epub', 'txt'],
      );
      if (files.isEmpty) return;
      setState(() => _importing = true);
      var imported = 0;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        await library.importBook(sourceName: file.name, bytes: bytes);
        imported++;
      }
      messenger.showSnackBar(SnackBar(
        content: Text(imported > 0 ? '已导入 $imported 本书' : '未能读取所选文件'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('导入失败:$e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _openBook(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReaderPage(book: book)),
    );
  }

  void _showBookActions(Book book) {
    final library = context.read<LibraryController>();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(book.title),
        message: Text(
          [
            if (book.author.isNotEmpty) book.author,
            book.contentType == BookContentType.epub ? 'EPUB' : 'TXT',
            if (book.wordCount > 0) '约${_formatWordCount(book.wordCount)}字',
          ].join(' · '),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _openBook(book);
            },
            child: const Text('继续阅读'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(sheetContext);
              library.removeBook(book);
            },
            child: const Text('移出书架'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('取消'),
        ),
      ),
    );
  }

  static String _formatWordCount(int count) =>
      count >= 10000 ? '${(count / 10000).toStringAsFixed(1)}万' : '$count';

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final books = library.books;
    final stats = library.stats;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('书架'),
            actions: [
              if (_importing)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CupertinoActivityIndicator(),
                )
              else
                IconButton(
                  tooltip: '导入图书',
                  icon: const Icon(CupertinoIcons.add, size: 22),
                  onPressed: _import,
                ),
            ],
          ),
          SliverToBoxAdapter(child: _TodayBanner(seconds: stats.todaySeconds)),
          if (books.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyShelf(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  mainAxisSpacing: 22,
                  crossAxisSpacing: 18,
                  childAspectRatio: 0.52,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final book = books[i];
                    final progress = library.progressFor(book.id);
                    return _ShelfItem(
                      book: book,
                      percent: progress?.percent ?? 0,
                      onTap: () => _openBook(book),
                      onLongPress: () => _showBookActions(book),
                    );
                  },
                  childCount: books.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayBanner extends StatelessWidget {
  const _TodayBanner({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.time, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              seconds > 0 ? '今日已阅读 ${formatDuration(seconds)}' : '今天还没有开始阅读',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfItem extends StatelessWidget {
  const _ShelfItem({
    required this.book,
    required this.percent,
    required this.onTap,
    required this.onLongPress,
  });

  final Book book;
  final double percent;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Center(child: BookCover(book: book, width: 96))),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            percent > 0 ? '已读 ${(percent * 100).toStringAsFixed(0)}%' : '未开始',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.book, size: 56, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Text(
            '书架空空如也\n点击右上角 + 导入 EPUB / TXT',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
