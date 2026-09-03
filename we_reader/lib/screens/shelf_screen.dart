import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';
import 'reader_screen.dart';

/// 书架页：网格展示已收藏书籍与阅读进度。
class ShelfScreen extends StatelessWidget {
  const ShelfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final books = appState.shelfBookIds
        .map(BookRepository.instance.bookById)
        .whereType<Book>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('书架')),
      body: books.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 56,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '书架空空如也\n去「发现」页挑一本好书吧',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.52,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) =>
                  _ShelfItem(book: books[index]),
            ),
    );
  }
}

class _ShelfItem extends StatelessWidget {
  const _ShelfItem({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final progress = appState.progressOf(book.id);
    final percentText = progress == null
        ? '未开始'
        : progress.percent >= 0.98
            ? '读完'
            : '已读 ${(progress.percent * 100).round()}%';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(book: book)),
      ),
      onLongPress: () => _showActions(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  BookCover(book: book, width: constraints.maxWidth),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            percentText,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showActions(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () {
                appState.removeFromShelf(book.id);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
