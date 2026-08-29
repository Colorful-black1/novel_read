/// Excel 伪装皮肤页。
///
/// 外观模拟 Excel 界面（窗口标题由 BossModeService 同步改为 "Book1 - Excel"），
/// 最近阅读的章节内容渲染在中间一片"选中单元格区域"里，Esc 可退出，
/// 窗口失焦时自动高斯模糊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;

import '../../data/model/models.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';
import '../../services/boss_mode_service.dart';

class ExcelDisguisePage extends ConsumerStatefulWidget {
  const ExcelDisguisePage({super.key});

  @override
  ConsumerState<ExcelDisguisePage> createState() => _ExcelDisguisePageState();
}

class _ExcelDisguisePageState extends ConsumerState<ExcelDisguisePage> {
  static const _grid = Color(0xFFD4D4D4);
  static const _headerBg = Color(0xFF217346);
  static const _barBg = Color(0xFFF3F2F1);
  static const _selectedBorder = Color(0xFF217346);

  final FocusNode _focusNode = FocusNode();
  Future<String>? _contentFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentFuture ??= _loadLatestChapterText();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// 加载最近一次阅读的章节文本（伪装页里展示的内容）
  Future<String> _loadLatestChapterText() async {
    final books = await ref.read(bookRepositoryProvider).listBooks();
    if (books.isEmpty) return '';
    final progressRepo = ref.read(progressRepositoryProvider);
    // 取 updatedAt 最新的进度对应的书
    BookTarget? target;
    DateTime? latest;
    for (final b in books) {
      final p = await progressRepo.getProgress(b.bookKey);
      if (p != null && (latest == null || p.updatedAt.isAfter(latest))) {
        latest = p.updatedAt;
        target = BookTarget(book: b, chapterIndex: p.chapterIndex);
      }
    }
    final t = target ?? BookTarget(book: books.first, chapterIndex: 0);
    final chapters =
        await ref.read(bookRepositoryProvider).listChapters(t.book.id);
    if (chapters.isEmpty) return '';
    final idx = t.chapterIndex.clamp(0, chapters.length - 1);
    final content =
        await ImportService(ref.read(bookRepositoryProvider))
            .readBookContent(t.book);
    final c = chapters[idx];
    return content.substring(
        c.startOffset.clamp(0, content.length),
        c.endOffset.clamp(0, content.length));
  }

  @override
  Widget build(BuildContext context) {
    final blurred = ref.watch(windowBlurredProvider);
    final cfg = ref.watch(readConfigProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            BossModeService.instance.exitDisguise();
          },
        },
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRibbon(),
              _buildFormulaBar(),
              Expanded(
                child: _buildGrid(
                  child: FutureBuilder<String>(
                    future: _contentFuture,
                    builder: (ctx, snap) {
                      final text = snap.data ?? '';
                      if (text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final content = Text(
                        text,
                        style: TextStyle(
                          fontSize: cfg.fontSize,
                          height: cfg.lineSpacing,
                          color: const Color(0xFF333333),
                        ),
                      );
                      if (blurred && cfg.blurOnFocusLost) {
                        return ImageFiltered(
                          imageFilter: ImageFilter.blur(
                              sigmaX: 14, sigmaY: 14, tileMode: TileMode.decal),
                          child: content,
                        );
                      }
                      return SingleChildScrollView(child: content);
                    },
                  ),
                ),
              ),
              _buildStatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRibbon() {
    return Container(
      color: _headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.grid_on, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('工作簿1 - Excel',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const Spacer(),
          _ribbonTab('文件', true),
          _ribbonTab('开始', false),
          _ribbonTab('插入', false),
          _ribbonTab('页面布局', false),
          _ribbonTab('公式', false),
          _ribbonTab('数据', false),
          _ribbonTab('审阅', false),
          _ribbonTab('视图', false),
        ],
      ),
    );
  }

  Widget _ribbonTab(String label, bool active) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : Colors.white70,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );

  Widget _buildFormulaBar() {
    return Container(
      color: _barBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _fakeCell('A1', width: 70),
          const SizedBox(width: 8),
          const Icon(Icons.functions, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.white,
              child: const Text('季度统计表',
                  style: TextStyle(fontSize: 13, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid({required Widget child}) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
              child: CustomPaint(painter: _GridPainter(_grid))),
          // 选中区域：阅读内容所在
          Positioned(
            left: 120,
            top: 30,
            right: 200,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _selectedBorder, width: 2),
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: _barBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: const Row(
        children: [
          Text('就绪', style: TextStyle(fontSize: 12, color: Colors.black54)),
          Spacer(),
          Text('100%', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _fakeCell(String text, {double width = 60}) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: Colors.white,
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      );
}

class BookTarget {
  final Book book;
  final int chapterIndex;

  const BookTarget({required this.book, required this.chapterIndex});
}

class _GridPainter extends CustomPainter {
  final Color color;

  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const cellW = 90.0;
    const cellH = 24.0;
    for (var x = 0.0; x < size.width; x += cellW) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += cellH) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
