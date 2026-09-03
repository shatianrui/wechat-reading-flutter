import 'package:flutter/material.dart';

import '../data/book_repository.dart';
import '../models/models.dart';
import '../widgets/book_cover.dart';
import 'book_detail_screen.dart';

/// 搜索页：按书名 / 作者 / 分类模糊匹配本地书库。
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Book> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) {
    final keyword = query.trim();
    setState(() {
      _searched = keyword.isNotEmpty;
      _results = keyword.isEmpty
          ? []
          : BookRepository.instance.allBooks
              .where((b) =>
                  b.title.contains(keyword) ||
                  b.author.contains(keyword) ||
                  b.category.contains(keyword))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索书名 / 作者 / 分类',
            border: InputBorder.none,
          ),
          onChanged: _search,
          onSubmitted: _search,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: !_searched
          ? Center(
              child: Text(
                '输入关键词开始搜索',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : _results.isEmpty
              ? Center(
                  child: Text(
                    '没有找到相关书籍',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final book = _results[index];
                    return ListTile(
                      leading: BookCover(book: book, width: 40),
                      title: Text(book.title),
                      subtitle: Text('${book.author} · ${book.category}'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookDetailScreen(book: book),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
