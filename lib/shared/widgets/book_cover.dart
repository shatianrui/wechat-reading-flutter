import 'package:flutter/material.dart';

import '../../core/models/book.dart';

/// 程序化封面:按 coverSeed 生成渐变底 + 竖排书名,
/// EPUB 内嵌封面图可在后续版本替换此组件。
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.book, this.width = 96});

  final Book book;
  final double width;

  static const _palettes = <List<Color>>[
    [Color(0xFF39598F), Color(0xFF1F3554)],
    [Color(0xFF7A4E3B), Color(0xFF4A2C1E)],
    [Color(0xFF3E6B4F), Color(0xFF224030)],
    [Color(0xFF6D5285), Color(0xFF43325A)],
    [Color(0xFF8A6D3B), Color(0xFF5C4423)],
    [Color(0xFF4E6E81), Color(0xFF2C4552)],
    [Color(0xFF9F5F5F), Color(0xFF5E3232)],
    [Color(0xFF52708D), Color(0xFF32475E)],
  ];

  @override
  Widget build(BuildContext context) {
    final height = width * 1.42;
    final palette = _palettes[book.coverSeed % _palettes.length];
    final titleChars = book.title.replaceAll(RegExp(r'[((].*[))]'), '');
    final displayTitle =
        titleChars.length > 8 ? titleChars.substring(0, 8) : titleChars;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 书脊高光。
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3.5,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: width * 0.16,
              top: width * 0.14,
              right: width * 0.1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 竖排书名。
                Expanded(
                  child: Wrap(
                    direction: Axis.vertical,
                    spacing: 2,
                    children: [
                      for (final ch in displayTitle.characters)
                        Text(
                          ch,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: width * 0.148,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                    ],
                  ),
                ),
                if (book.author.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: width * 0.1),
                    child: Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: width * 0.095,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
