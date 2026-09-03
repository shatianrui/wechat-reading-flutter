import 'package:flutter/material.dart';

import '../models/models.dart';

/// 阅读器（占位，完整实现见后续提交）。
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.autoStartTts = false,
  });

  final Book book;
  final int? initialChapterIndex;
  final bool autoStartTts;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: const Center(child: Text('阅读器开发中')),
    );
  }
}
