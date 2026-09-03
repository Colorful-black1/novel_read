/// Word 伪装皮肤页。
///
/// 外观模拟 Word 界面（窗口标题由 BossModeService 同步改为 "文档1 - Word"），
/// 最近阅读的章节内容渲染在居中的白色文档页里，Esc 可退出，
/// 窗口失焦时自动高斯模糊。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;

import '../../logic/providers.dart';
import '../../services/boss_mode_service.dart';
import 'disguise_common.dart';

class WordDisguisePage extends ConsumerStatefulWidget {
  const WordDisguisePage({super.key});

  @override
  ConsumerState<WordDisguisePage> createState() => _WordDisguisePageState();
}

class _WordDisguisePageState extends ConsumerState<WordDisguisePage> {
  static const _ribbonBg = Color(0xFF2B579A);
  static const _barBg = Color(0xFFF3F2F1);

  final FocusNode _focusNode = FocusNode();
  Future<String>? _contentFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contentFuture ??= loadLatestChapterText(ref);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blurred = ref.watch(windowBlurredProvider);
    final cfg = ref.watch(readConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
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
              _buildToolbar(),
              _buildRuler(),
              Expanded(
                child: Center(
                  child: FutureBuilder<String>(
                    future: _contentFuture,
                    builder: (ctx, snap) {
                      final text = snap.data ?? '';
                      if (text.isEmpty) return const SizedBox.shrink();
                      final content = Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 72, vertical: 56),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: cfg.fontSize,
                            height: cfg.lineSpacing,
                            color: const Color(0xFF000000),
                            fontFamily: 'SimSun',
                          ),
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
      color: _ribbonBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text('文档1 - Word',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const Spacer(),
          _ribbonTab('文件', true),
          _ribbonTab('开始', false),
          _ribbonTab('插入', false),
          _ribbonTab('设计', false),
          _ribbonTab('布局', false),
          _ribbonTab('引用', false),
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

  Widget _buildToolbar() {
    return Container(
      color: _barBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _fakeField('宋体', width: 72),
          const SizedBox(width: 8),
          _fakeField('11', width: 44),
          const SizedBox(width: 12),
          const Icon(Icons.format_bold, size: 16, color: Colors.black87),
          const SizedBox(width: 10),
          const Icon(Icons.format_italic, size: 16, color: Colors.black87),
          const SizedBox(width: 10),
          const Icon(Icons.format_underlined, size: 16, color: Colors.black87),
          const SizedBox(width: 16),
          const Icon(Icons.format_align_left, size: 16, color: Colors.black87),
          const SizedBox(width: 10),
          const Icon(Icons.format_align_center, size: 16, color: Colors.black87),
          const SizedBox(width: 10),
          const Icon(Icons.format_align_right, size: 16, color: Colors.black87),
          const Spacer(),
          const Icon(Icons.search, size: 16, color: Colors.black54),
        ],
      ),
    );
  }

  Widget _fakeField(String text, {double width = 60}) => Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        color: Colors.white,
        decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD0D0D0))),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      );

  Widget _buildRuler() {
    return Container(
      height: 20,
      color: const Color(0xFFEFEFEF),
      child: CustomPaint(painter: _RulerPainter()),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: _ribbonBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Text('页: 1/1',
              style: TextStyle(fontSize: 12, color: Colors.white)),
          const SizedBox(width: 16),
          const Text('中文字数: 1286',
              style: TextStyle(fontSize: 12, color: Colors.white)),
          const Spacer(),
          const Text('100%',
              style: TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}

/// 标尺刻度绘制
class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 1;
    // 长刻度每 60px，短刻度每 12px
    for (var x = 0.0; x < size.width; x += 12) {
      final isLong = (x / 12).floor() % 5 == 0;
      final h = isLong ? 8.0 : 4.0;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) => false;
}
