/// 用户导入的书籍。
///
/// v1 内容来自用户上传的本地文件(EPUB/TXT),文件复制到应用文档目录;
/// 字段设计兼容将来云书架同步(以 importedAt/updatedAt 时间戳合并)。
class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.fileName,
    required this.contentType,
    required this.importedAt,
    this.wordCount = 0,
    this.coverSeed = 0,
  });

  final String id;
  final String title;
  final String author;

  /// 应用文档目录 books/ 下的文件名(不含路径,便于沙盒路径变化)。
  final String fileName;
  final BookContentType contentType;
  final DateTime importedAt;

  /// 导入时统计的总字数(用于展示)。
  final int wordCount;

  /// 程序化封面配色种子。
  final int coverSeed;

  Book copyWith({String? title, String? author}) => Book(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        fileName: fileName,
        contentType: contentType,
        importedAt: importedAt,
        wordCount: wordCount,
        coverSeed: coverSeed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'fileName': fileName,
        'contentType': contentType.name,
        'importedAt': importedAt.millisecondsSinceEpoch,
        'wordCount': wordCount,
        'coverSeed': coverSeed,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String? ?? '',
        fileName: json['fileName'] as String,
        contentType: BookContentType.values.firstWhere(
          (e) => e.name == (json['contentType'] as String? ?? 'txt'),
          orElse: () => BookContentType.txt,
        ),
        importedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['importedAt'] as num?)?.toInt() ?? 0,
        ),
        wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
        coverSeed: (json['coverSeed'] as num?)?.toInt() ?? 0,
      );
}

enum BookContentType { txt, epub }
