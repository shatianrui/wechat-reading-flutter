/// 批注类型:划线、想法(笔记)、书签。
enum AnnotationType { highlight, note, bookmark }

/// 批注定位采用「章节索引 + 章内字符偏移」,对本地内容稳定;
/// 将来接入 EPUB CFI 时可在此基础上扩展 locator 字段。
class Annotation {
  const Annotation({
    required this.id,
    required this.bookId,
    required this.type,
    required this.chapterIndex,
    required this.start,
    required this.end,
    required this.text,
    this.noteContent = '',
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final AnnotationType type;
  final int chapterIndex;

  /// 章节 displayText 内的起止字符偏移(书签时为页首偏移,start == end)。
  final int start;
  final int end;

  /// 被标记的原文片段(书签为页首摘要)。
  final String text;

  /// 想法内容(仅 note 类型)。
  final String noteContent;

  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'type': type.name,
        'chapterIndex': chapterIndex,
        'start': start,
        'end': end,
        'text': text,
        'noteContent': noteContent,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        type: AnnotationType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AnnotationType.highlight,
        ),
        chapterIndex: (json['chapterIndex'] as num).toInt(),
        start: (json['start'] as num).toInt(),
        end: (json['end'] as num).toInt(),
        text: json['text'] as String? ?? '',
        noteContent: json['noteContent'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num).toInt(),
        ),
      );
}
