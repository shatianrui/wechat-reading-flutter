import 'package:flutter/material.dart';

import '../../../core/state/reader_settings.dart';
import '../pagination.dart';

/// 目录面板:章节跳转。
Future<int?> showTocSheet({
  required BuildContext context,
  required PaginatedBook book,
  required int currentChapter,
  required ReaderTheme theme,
  required String bookTitle,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: theme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.72,
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                '目录 · ${book.chapterTitles.length}章',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Text(
                bookTitle,
                style: TextStyle(fontSize: 12, color: theme.secondaryText),
              ),
            ),
            Divider(height: 1, color: theme.secondaryText.withValues(alpha: 0.2)),
            Flexible(
              child: ListView.builder(
                controller: ScrollController(
                  initialScrollOffset: (currentChapter * 48.0 - 100)
                      .clamp(0, double.infinity),
                ),
                itemCount: book.chapterTitles.length,
                itemBuilder: (context, i) {
                  final selected = i == currentChapter;
                  return InkWell(
                    onTap: () => Navigator.pop(sheetContext, i),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              book.chapterTitles[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: selected
                                    ? const Color(0xFF4C8AF0)
                                    : theme.text,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.play_arrow_rounded,
                                size: 16, color: Color(0xFF4C8AF0)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
