/// 阅读统计(本地累计)。
class ReadingStats {
  const ReadingStats({
    this.totalSeconds = 0,
    this.todaySeconds = 0,
    this.todayKey = '',
    this.finishedBooks = 0,
    this.listenSeconds = 0,
  });

  final int totalSeconds;
  final int todaySeconds;

  /// 形如 2026-09-03,用于跨天清零今日时长。
  final String todayKey;
  final int finishedBooks;
  final int listenSeconds;

  ReadingStats copyWith({
    int? totalSeconds,
    int? todaySeconds,
    String? todayKey,
    int? finishedBooks,
    int? listenSeconds,
  }) =>
      ReadingStats(
        totalSeconds: totalSeconds ?? this.totalSeconds,
        todaySeconds: todaySeconds ?? this.todaySeconds,
        todayKey: todayKey ?? this.todayKey,
        finishedBooks: finishedBooks ?? this.finishedBooks,
        listenSeconds: listenSeconds ?? this.listenSeconds,
      );

  Map<String, dynamic> toJson() => {
        'totalSeconds': totalSeconds,
        'todaySeconds': todaySeconds,
        'todayKey': todayKey,
        'finishedBooks': finishedBooks,
        'listenSeconds': listenSeconds,
      };

  factory ReadingStats.fromJson(Map<String, dynamic> json) => ReadingStats(
        totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 0,
        todaySeconds: (json['todaySeconds'] as num?)?.toInt() ?? 0,
        todayKey: json['todayKey'] as String? ?? '',
        finishedBooks: (json['finishedBooks'] as num?)?.toInt() ?? 0,
        listenSeconds: (json['listenSeconds'] as num?)?.toInt() ?? 0,
      );
}
