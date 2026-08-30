/// 书架页：书籍网格展示、TXT 导入入口、删除管理。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';
import '../reader/reader_page.dart';
import 'hotkey_settings_dialog.dart';

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key});

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage> {
  bool _importing = false;

  Future<void> _import() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final service = ImportService(ref.read(bookRepositoryProvider));
      final result = await service.pickAndImport();
      if (!mounted) return;
      if (result.success) {
        ref.invalidate(bookListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)));
      } else if (result.message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(BookWithProgress item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定从书架移除《${item.book.title}》吗？\n（不会删除磁盘上的 TXT 文件）'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(bookRepositoryProvider).deleteBook(item.book.id);
    ref.invalidate(bookListProvider);
  }

  void _openReader(BookWithProgress item) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReaderPage(book: item.book),
    )).then((_) => ref.invalidate(bookListProvider));
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(bookListProvider);
    final appNameStyle = Theme.of(context).textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(
        title: Text(appName, style: appNameStyle),
        actions: [
          // PC：老板键快捷键设置入口
          if (Platform.isWindows)
            IconButton(
              tooltip: '老板键快捷键设置',
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => const HotkeySettingsDialog()),
              icon: const Icon(Icons.keyboard_alt_outlined),
            ),
          IconButton(
            tooltip: '导入 TXT',
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text('书架空空如也'),
                  const SizedBox(height: 4),
                  Text('点击右上角按钮导入本地 TXT 小说',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: books.length,
            itemBuilder: (ctx, i) {
              final item = books[i];
              return _BookCard(
                item: item,
                onTap: () => _openReader(item),
                onLongPress: () => _delete(item),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookWithProgress item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  static const _coverColors = [
    Color(0xFF5B7C99),
    Color(0xFF8A9A5B),
    Color(0xFFB0715E),
    Color(0xFF7B6D8D),
    Color(0xFF4E8069),
  ];

  @override
  Widget build(BuildContext context) {
    final progress = item.progress;
    final percent = progress?.percent ?? 0;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _coverColors[item.book.id % _coverColors.length],
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6), bottom: Radius.circular(2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Text(
                item.book.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.book.chapterCount} 章',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                LinearProgressIndicator(
                  value: percent <= 0 ? null : percent.clamp(0, 1),
                  minHeight: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
