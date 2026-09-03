/// 阅读进度:章节索引 + 章内字符偏移 + 全书百分比。
///
/// 云同步冲突策略(v2 预留):以 [updatedAt] 最新时间戳为准(latest-wins),
/// 本地与云端进度合并时取更新时间较晚者。
class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    this.chapterIndex = 0,
    this.charOffset = 0,
    this.percent = 0,
    required this.updatedAt,
  });

  final String bookId;
  final int chapterIndex;
  final int charOffset;

  /// 0.0 ~ 1.0 的全书进度。
  final double percent;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'percent': percent,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      ReadingProgress(
        bookId: json['bookId'] as String,
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        charOffset: (json['charOffset'] as num?)?.toInt() ?? 0,
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (json['updatedAt'] as num?)?.toInt() ?? 0,
        ),
      );
}
