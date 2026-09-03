import 'package:flutter/material.dart';

import '../models/models.dart';

/// 程序化生成的书籍封面（渐变底色 + 竖排风格书名）。
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width = 96});

  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 4 / 3;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: book.coverColors,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(width * 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: width * 0.16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: width * 0.10,
            ),
          ),
        ],
      ),
    );
  }
}
