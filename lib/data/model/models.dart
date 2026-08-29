/// 数据实体定义。
library;

/// 书籍
class Book {
  final int id;
  final String title;
  final String author;
  final String filePath;
  final int fileSize;
  final String bookKey;
  final int chapterCount;
  final DateTime addedAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.fileSize,
    required this.bookKey,
    required this.chapterCount,
    required this.addedAt,
  });

  Map<String, Object?> toMap() => {
        // id 为 0 表示新增记录，省略以交给 SQLite 自增，避免主键冲突
        if (id != 0) 'id': id,
        'title': title,
        'author': author,
        'filePath': filePath,
        'fileSize': fileSize,
        'bookKey': bookKey,
        'chapterCount': chapterCount,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  static Book fromMap(Map<String, Object?> map) => Book(
        id: map['id'] as int,
        title: map['title'] as String,
        author: (map['author'] as String?) ?? '',
        filePath: map['filePath'] as String,
        fileSize: map['fileSize'] as int,
        bookKey: map['bookKey'] as String,
        chapterCount: map['chapterCount'] as int,
        addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
      );
}

/// 章节
class Chapter {
  final int id;
  final int bookId;
  final int idx;
  final String title;
  final int startOffset;
  final int endOffset;

  Chapter({
    required this.id,
    required this.bookId,
    required this.idx,
    required this.title,
    required this.startOffset,
    required this.endOffset,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'bookId': bookId,
        'idx': idx,
        'title': title,
        'startOffset': startOffset,
        'endOffset': endOffset,
      };

  static Chapter fromMap(Map<String, Object?> map) => Chapter(
        id: map['id'] as int,
        bookId: map['bookId'] as int,
        idx: map['idx'] as int,
        title: map['title'] as String,
        startOffset: map['startOffset'] as int,
        endOffset: map['endOffset'] as int,
      );
}

/// 阅读进度（以 bookKey 为主键，便于双端同步匹配）
class ReadingProgress {
  final String bookKey;
  final int chapterIndex;
  final int charOffset;
  final double percent;
  final int updatedAtMs;

  ReadingProgress({
    required this.bookKey,
    required this.chapterIndex,
    required this.charOffset,
    required this.percent,
    required this.updatedAtMs,
  });

  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

  Map<String, Object?> toMap() => {
        'bookKey': bookKey,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'percent': percent,
        'updatedAt': updatedAtMs,
      };

  static ReadingProgress fromMap(Map<String, Object?> map) =>
      ReadingProgress(
        bookKey: map['bookKey'] as String,
        chapterIndex: map['chapterIndex'] as int,
        charOffset: map['charOffset'] as int,
        percent: (map['percent'] as num?)?.toDouble() ?? 0,
        updatedAtMs: map['updatedAt'] as int,
      );

  /// 同步协议序列化
  Map<String, Object?> toSyncJson() => toMap();

  static ReadingProgress fromSyncJson(Map<String, Object?> json) =>
      fromMap(json);
}

/// 已配对设备
class SyncPair {
  final int id;
  final String deviceId;
  final String deviceName;
  final String token;
  final String host;
  final int port;
  final int lastSyncAtMs;

  SyncPair({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.token,
    required this.host,
    required this.port,
    required this.lastSyncAtMs,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'token': token,
        'host': host,
        'port': port,
        'lastSyncAt': lastSyncAtMs,
      };

  static SyncPair fromMap(Map<String, Object?> map) => SyncPair(
        id: map['id'] as int,
        deviceId: map['deviceId'] as String,
        deviceName: (map['deviceName'] as String?) ?? '',
        token: map['token'] as String,
        host: map['host'] as String,
        port: map['port'] as int,
        lastSyncAtMs: map['lastSyncAt'] as int,
      );
}

/// 同步记录
class SyncLog {
  final int id;
  final DateTime time;
  final String direction; // push / pull / merge
  final String detail;

  SyncLog({
    this.id = 0,
    required this.time,
    required this.direction,
    required this.detail,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'time': time.millisecondsSinceEpoch,
        'direction': direction,
        'detail': detail,
      };

  static SyncLog fromMap(Map<String, Object?> map) => SyncLog(
        id: map['id'] as int,
        time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
        direction: map['direction'] as String,
        detail: map['detail'] as String,
      );
}

/// 冲突快照：同步覆盖前保留的旧进度
class ConflictSnapshot {
  final int id;
  final String bookKey;
  final int chapterIndex;
  final int charOffset;
  final int updatedAtMs;
  final DateTime savedAt;

  ConflictSnapshot({
    this.id = 0,
    required this.bookKey,
    required this.chapterIndex,
    required this.charOffset,
    required this.updatedAtMs,
    required this.savedAt,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'bookKey': bookKey,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'updatedAt': updatedAtMs,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  static ConflictSnapshot fromMap(Map<String, Object?> map) =>
      ConflictSnapshot(
        id: map['id'] as int,
        bookKey: map['bookKey'] as String,
        chapterIndex: map['chapterIndex'] as int,
        charOffset: map['charOffset'] as int,
        updatedAtMs: map['updatedAt'] as int,
        savedAt:
            DateTime.fromMillisecondsSinceEpoch(map['savedAt'] as int),
      );
}
