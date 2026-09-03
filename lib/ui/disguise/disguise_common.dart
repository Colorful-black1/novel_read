/// 伪装皮肤公共逻辑：加载最近一次阅读的章节文本。
///
/// Excel / Word 伪装页共用，避免重复实现。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/model/models.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';

/// 加载最近一次阅读的章节文本（伪装页里展示的内容）。
///
/// 取 updatedAt 最新的进度对应的书与章节；无进度时回退到第一本书第一章。
Future<String> loadLatestChapterText(WidgetRef ref) async {
  final books = await ref.read(bookRepositoryProvider).listBooks();
  if (books.isEmpty) return '';
  final progressRepo = ref.read(progressRepositoryProvider);
  Book? targetBook;
  int targetChapter = 0;
  DateTime? latest;
  for (final b in books) {
    final p = await progressRepo.getProgress(b.bookKey);
    if (p != null && (latest == null || p.updatedAt.isAfter(latest))) {
      latest = p.updatedAt;
      targetBook = b;
      targetChapter = p.chapterIndex;
    }
  }
  final book = targetBook ?? books.first;
  final chapters = await ref.read(bookRepositoryProvider).listChapters(book.id);
  if (chapters.isEmpty) return '';
  final idx = targetChapter.clamp(0, chapters.length - 1);
  final content =
      await ImportService(ref.read(bookRepositoryProvider)).readBookContent(book);
  final c = chapters[idx];
  return content.substring(
      c.startOffset.clamp(0, content.length),
      c.endOffset.clamp(0, content.length));
}
