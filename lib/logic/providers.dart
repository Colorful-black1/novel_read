/// Riverpod 全局 Provider 定义。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../data/model/models.dart';
import '../data/repository/book_repository.dart';
import '../data/repository/sync_repository.dart';
import 'read_config.dart';

/// SharedPreferences 实例（main 中预热后注入）
final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

/// 数据库实例（main 中预热后注入）
final databaseProvider =
    Provider<Database>((ref) => throw UnimplementedError());

final bookRepositoryProvider = Provider<BookRepository>(
    (ref) => BookRepository(ref.watch(databaseProvider)));

final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => ProgressRepository(ref.watch(databaseProvider)));

final syncRepositoryProvider = Provider<SyncRepository>(
    (ref) => SyncRepository(ref.watch(databaseProvider)));

/// 书架列表（含每本书的最新进度），删除或导入后调用 invalidate 刷新
final bookListProvider = FutureProvider<List<BookWithProgress>>((ref) async {
  final books = await ref.watch(bookRepositoryProvider).listBooks();
  final result = <BookWithProgress>[];
  for (final b in books) {
    final progress =
        await ref.watch(progressRepositoryProvider).getProgress(b.bookKey);
    result.add(BookWithProgress(book: b, progress: progress));
  }
  return result;
});

/// 书籍 + 进度组合视图
class BookWithProgress {
  final Book book;
  final ReadingProgress? progress;

  const BookWithProgress({required this.book, this.progress});
}

/// 阅读设置状态
class ReadConfigNotifier extends StateNotifier<ReadConfig> {
  final SharedPreferences _prefs;

  static const _key = 'read_config';

  ReadConfigNotifier(this._prefs) : super(_load(_prefs));

  static ReadConfig _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return const ReadConfig();
    try {
      return ReadConfig.fromJson(raw);
    } catch (_) {
      return const ReadConfig();
    }
  }

  void update(ReadConfig Function(ReadConfig) updater) {
    state = updater(state);
    _prefs.setString(_key, state.toJson());
  }
}

final readConfigProvider =
    StateNotifierProvider<ReadConfigNotifier, ReadConfig>(
        (ref) => ReadConfigNotifier(ref.watch(sharedPrefsProvider)));

/// 当前生效的阅读主题（夜间模式优先）
final effectiveThemeProvider = Provider<ReaderTheme>((ref) {
  final cfg = ref.watch(readConfigProvider);
  if (cfg.nightMode) {
    return const ReaderTheme('夜间', 0xFF121212, 0xFF9E9E9E);
  }
  return readerThemes[cfg.themeIndex.clamp(0, readerThemes.length - 1)];
});
