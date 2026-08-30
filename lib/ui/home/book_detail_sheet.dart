/// 书籍详情弹层：封面预览、书名/作者编辑、章节与进度信息。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/providers.dart';

class BookDetailSheet extends ConsumerStatefulWidget {
  final BookWithProgress item;
  final VoidCallback onEditSaved;

  const BookDetailSheet({
    super.key,
    required this.item,
    required this.onEditSaved,
  });

  @override
  ConsumerState<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends ConsumerState<BookDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.book.title);
    _authorController = TextEditingController(text: widget.item.book.author);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    await ref
        .read(bookRepositoryProvider)
        .updateBookMeta(widget.item.book.id,
            title: title, author: _authorController.text.trim());
    widget.onEditSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.item.book;
    final progress = widget.item.progress;
    final percent = progress?.percent ?? 0.0;
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    height: 120,
                    child: book.coverPath.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(book.coverPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _coverPlaceholder(context),
                            ),
                          )
                        : _coverPlaceholder(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('章节：${book.chapterCount} 章',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('添加时间：${_formatDate(book.addedAt)}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          progress == null
                              ? '尚未开始阅读'
                              : '阅读进度：${(percent * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: TextField(
                controller: _titleController,
                maxLength: 60,
                onChanged: (_) => setState(() => _dirty = true),
                decoration: const InputDecoration(
                  labelText: '书名',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: TextField(
                controller: _authorController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '作者',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: FilledButton(
                onPressed: _dirty ? _save : null,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_outlined, size: 32),
    );
  }

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
