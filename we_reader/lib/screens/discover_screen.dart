import 'package:flutter/material.dart';

import '../data/book_repository.dart';
import '../data/sample_books.dart';
import '../models/models.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';
import 'search_screen.dart';

/// 发现页：搜索、分类、榜单、推荐书列表。
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _category = '全部';

  List<Book> get _filteredBooks {
    final books = BookRepository.instance.allBooks;
    if (_category == '全部') return books;
    return books.where((b) => b.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildSearchBar(context),
          _buildRankings(context),
          _buildCategoryChips(),
          ..._filteredBooks.map((book) => _BookListTile(book: book)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                '搜索书名 / 作者',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankings(BuildContext context) {
    final books = BookRepository.instance.allBooks;
    final rankings = <(String, String, List<Book>)>[
      (
        '神作榜',
        '高分好评',
        [...books]..sort((a, b) => b.rating.compareTo(a.rating)),
      ),
      (
        '飙升榜',
        '热度上升',
        [...books]..sort((a, b) => b.readers.compareTo(a.readers)),
      ),
      (
        '新书榜',
        '新鲜上架',
        books.where((b) => b.isNew).toList(),
      ),
    ];

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: rankings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final (title, subtitle, list) = rankings[index];
          return _RankingCard(title: title, subtitle: subtitle, books: list);
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: bookCategories.map((category) {
          final selected = category == _category;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _category = category),
          );
        }).toList(),
      ),
    );
  }
}

/// 榜单卡片：展示榜单前三本书。
class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.subtitle,
    required this.books,
  });

  final String title;
  final String subtitle;
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (i, book) in books.take(3).indexed)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookDetailScreen(book: book),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: i == 0 ? Colors.orange : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${book.title} · ${book.author}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 书籍列表项。
class _BookListTile extends StatelessWidget {
  const _BookListTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(book: book, width: 72),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (book.format == BookFormat.epub)
                        _tag(context, 'EPUB'),
                      if (book.isNew) _tag(context, '新书'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.intro,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(book.rating / 10).toStringAsFixed(1)} 分 · '
                    '${_readersText(book.readers)}人在读',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  static String _readersText(int readers) {
    if (readers >= 10000) {
      return '${(readers / 10000).toStringAsFixed(1)}万';
    }
    return '$readers';
  }
}
