import 'package:flutter/material.dart';

/// 书籍内容格式。
enum BookFormat { txt, epub }

/// 书籍元数据。正式产品中由服务端下发，MVP 阶段为本地 Mock。
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.intro,
    required this.format,
    required this.coverColors,
    this.txtContent,
    this.epubAssetPath,
    this.rating = 80,
    this.readers = 1000,
    this.isNew = false,
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String intro;
  final BookFormat format;

  /// 封面渐变色（无真实封面图，使用程序化封面）。
  final List<Color> coverColors;

  /// TXT 格式：内容内联在代码中（模拟从服务端拉取的正文）。
  final String? txtContent;

  /// EPUB 格式：打包在 assets 中的 epub 文件路径。
  final String? epubAssetPath;

  /// 推荐值（0-100），用于「神作榜」。
  final int rating;

  /// 模拟在读人数，用于「飙升榜」。
  final int readers;

  /// 是否新书，用于「新书榜」。
  final bool isNew;
}

/// 章节：统一 TXT / EPUB 解析后的结构。
class Chapter {
  const Chapter({required this.title, required this.content});

  final String title;

  /// 纯文本正文，段落之间以 \n 分隔。
  final String content;
}

/// 标注类型。
enum AnnotationType { highlight, note, bookmark }

/// 标注（划线 / 想法 / 书签），定位方式为「章节索引 + 字符偏移」。
class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.start,
    required this.end,
    required this.type,
    required this.selectedText,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final int chapterIndex;

  /// 章节内字符起始偏移（含）。
  final int start;

  /// 章节内字符结束偏移（不含）。书签的 start == end。
  final int end;
  final AnnotationType type;
  final String selectedText;
  final String? note;

  /// 毫秒时间戳。未来云同步时按「最新时间戳获胜」策略合并。
  final int createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'start': start,
        'end': end,
        'type': type.name,
        'selectedText': selectedText,
        'note': note,
        'createdAt': createdAt,
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        chapterIndex: json['chapterIndex'] as int,
        start: json['start'] as int,
        end: json['end'] as int,
        type: AnnotationType.values.byName(json['type'] as String),
        selectedText: json['selectedText'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: json['createdAt'] as int,
      );
}

/// 阅读进度。
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.percent,
    required this.updatedAt,
  });

  final String bookId;
  final int chapterIndex;

  /// 章节内字符偏移（当前页首字符）。
  final int charOffset;

  /// 全书进度 0.0 - 1.0。
  final double percent;

  /// 毫秒时间戳，云同步时按最新时间戳获胜。
  final int updatedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'percent': percent,
        'updatedAt': updatedAt,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        bookId: json['bookId'] as String,
        chapterIndex: json['chapterIndex'] as int,
        charOffset: json['charOffset'] as int,
        percent: (json['percent'] as num).toDouble(),
        updatedAt: json['updatedAt'] as int,
      );
}
