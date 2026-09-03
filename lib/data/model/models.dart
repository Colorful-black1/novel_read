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

  /// 书架自定义排序值，越小越靠前；全部为 0 时退化为按 addedAt 倒序
  final int sortIndex;

  /// 所属分组 id，null 表示未分组
  final int? groupId;

  /// 自定义封面图片路径，空串表示使用默认色块封面
  final String coverPath;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.filePath,
    required this.fileSize,
    required this.bookKey,
    required this.chapterCount,
    required this.addedAt,
    this.sortIndex = 0,
    this.groupId,
    this.coverPath = '',
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
        'sortIndex': sortIndex,
        'groupId': groupId,
        'coverPath': coverPath,
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
        sortIndex: (map['sortIndex'] as int?) ?? 0,
        groupId: map['groupId'] as int?,
        coverPath: (map['coverPath'] as String?) ?? '',
      );
}

/// 书架分组
class BookGroup {
  final int id;
  final String name;
  final int sortIndex;

  const BookGroup({
    required this.id,
    required this.name,
    this.sortIndex = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'name': name,
        'sortIndex': sortIndex,
      };

  static BookGroup fromMap(Map<String, Object?> map) => BookGroup(
        id: map['id'] as int,
        name: map['name'] as String,
        sortIndex: (map['sortIndex'] as int?) ?? 0,
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

/// 书签：定位到某章某页内偏移，附带正文摘录用于列表预览
class Bookmark {
  final int id;
  final String bookKey;
  final int chapterIndex;
  final int charOffset;
  final String snippet;
  final int createdAtMs;

  Bookmark({
    this.id = 0,
    required this.bookKey,
    required this.chapterIndex,
    required this.charOffset,
    this.snippet = '',
    required this.createdAtMs,
  });

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id,
        'bookKey': bookKey,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'snippet': snippet,
        'createdAt': createdAtMs,
      };

  static Bookmark fromMap(Map<String, Object?> map) => Bookmark(
        id: map['id'] as int,
        bookKey: map['bookKey'] as String,
        chapterIndex: map['chapterIndex'] as int,
        charOffset: map['charOffset'] as int,
        snippet: (map['snippet'] as String?) ?? '',
        createdAtMs: map['createdAt'] as int,
      );
}

/// 阅读统计（按天聚合）
class ReadingStat {
  /// 日期键，格式 YYYY-MM-DD
  final String date;

  /// 当日阅读时长（毫秒）
  final int durationMs;

  /// 当日阅读字数
  final int charCount;

  const ReadingStat({
    required this.date,
    this.durationMs = 0,
    this.charCount = 0,
  });

  Map<String, Object?> toMap() => {
        'date': date,
        'durationMs': durationMs,
        'charCount': charCount,
      };

  static ReadingStat fromMap(Map<String, Object?> map) => ReadingStat(
        date: map['date'] as String,
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
        charCount: (map['charCount'] as num?)?.toInt() ?? 0,
      );
}
