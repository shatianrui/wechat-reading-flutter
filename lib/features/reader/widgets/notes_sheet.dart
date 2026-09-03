import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/annotation.dart';
import '../../../core/state/library_controller.dart';
import '../../../core/state/reader_settings.dart';
import '../pagination.dart';

/// 笔记/划线/书签列表:回看、跳转、删除。
Future<Annotation?> showNotesSheet({
  required BuildContext context,
  required String bookId,
  required PaginatedBook book,
  required ReaderTheme theme,
}) {
  return showModalBottomSheet<Annotation>(
    context: context,
    backgroundColor: theme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.72,
    ),
    builder: (sheetContext) => _NotesList(
      bookId: bookId,
      book: book,
      theme: theme,
    ),
  );
}

class _NotesList extends StatelessWidget {
  const _NotesList({
    required this.bookId,
    required this.book,
    required this.theme,
  });

  final String bookId;
  final PaginatedBook book;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final annotations = library.annotationsFor(bookId);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              '笔记 · ${annotations.length}条',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
          ),
          Divider(height: 1, color: theme.secondaryText.withValues(alpha: 0.2)),
          if (annotations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  '长按选中正文即可划线、写想法\n点击工具栏书签图标可添加书签',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: theme.secondaryText),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                itemCount: annotations.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 20,
                  color: theme.secondaryText.withValues(alpha: 0.15),
                ),
                itemBuilder: (context, i) {
                  final a = annotations[i];
                  return _NoteTile(
                    annotation: a,
                    chapterTitle: a.chapterIndex < book.chapterTitles.length
                        ? book.chapterTitles[a.chapterIndex]
                        : '',
                    theme: theme,
                    onTap: () => Navigator.pop(context, a),
                    onDelete: () => library.removeAnnotation(a.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.annotation,
    required this.chapterTitle,
    required this.theme,
    required this.onTap,
    required this.onDelete,
  });

  final Annotation annotation;
  final String chapterTitle;
  final ReaderTheme theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (annotation.type) {
      AnnotationType.highlight => (CupertinoIcons.underline, '划线'),
      AnnotationType.note => (CupertinoIcons.text_bubble, '想法'),
      AnnotationType.bookmark => (CupertinoIcons.bookmark_fill, '书签'),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: const Color(0xFF4C8AF0)),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF4C8AF0))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 11, color: theme.secondaryText),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(CupertinoIcons.trash,
                      size: 16, color: theme.secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              annotation.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: theme.text, height: 1.5),
            ),
            if (annotation.noteContent.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  annotation.noteContent,
                  style: TextStyle(
                      fontSize: 12.5, color: theme.text, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
