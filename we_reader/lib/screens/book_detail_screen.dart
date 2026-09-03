import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/book_repository.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../widgets/book_cover.dart';
import 'reader_screen.dart';

/// 书籍详情页：简介、目录预览、加入书架 / 开始阅读。
class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.book});

  final Book book;

  void _openReader(BuildContext context, {bool startTts = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book, autoStartTts: startTts),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final onShelf = appState.isOnShelf(book.id);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('书籍详情')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(book: book, width: 100),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.author,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          label: Text(book.category),
                          visualDensity: VisualDensity.compact,
                        ),
                        Chip(
                          label: Text(book.format.name.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(book.rating / 10).toStringAsFixed(1)} 分 · '
                      '推荐值 ${book.rating}%',
                      style: TextStyle(fontSize: 13, color: primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '简介',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            book.intro,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '目录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<Chapter>>(
            future: BookRepository.instance.loadChapters(book),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final chapters = snapshot.data!;
              return Column(
                children: [
                  for (final (i, chapter) in chapters.indexed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(chapter.title),
                      trailing: Text(
                        '${chapter.content.length} 字',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(
                            book: book,
                            initialChapterIndex: i,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (onShelf) {
                      appState.removeFromShelf(book.id);
                    } else {
                      appState.addToShelf(book.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已加入书架'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: Icon(onShelf ? Icons.check : Icons.add),
                  label: Text(onShelf ? '已在书架' : '加入书架'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openReader(context, startTts: true),
                  icon: const Icon(Icons.headphones),
                  label: const Text('听书'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openReader(context),
                  icon: const Icon(Icons.menu_book),
                  label: const Text('阅读'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
