/// 目录选择浮层。
///
/// 支持打开时定位到当前章节、常显滚动条、正序/倒序切换。
library;

import 'package:flutter/material.dart';

import '../../data/model/models.dart';

/// 与 itemBuilder 的固定行高一致，用于计算定位偏移
const double _kRowExtent = 44;

class TocSheet extends StatefulWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Color foreground;
  final Color background;
  final ValueChanged<int> onSelect;

  const TocSheet({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.foreground,
    required this.background,
    required this.onSelect,
  });

  @override
  State<TocSheet> createState() => _TocSheetState();
}

class _TocSheetState extends State<TocSheet> {
  final _controller = ScrollController();
  bool _reversed = false;

  @override
  void initState() {
    super.initState();
    // 等列表完成首次布局（controller attach）后再定位
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateCurrent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 定位到当前章节（显示序 → 真实索引换算后滚动）
  void _locateCurrent() {
    if (!_controller.hasClients) return;
    final displayIndex = _reversed
        ? widget.chapters.length - 1 - widget.currentIndex
        : widget.currentIndex;
    final target = displayIndex * _kRowExtent;
    _controller.jumpTo(target.clamp(0.0, _controller.position.maxScrollExtent));
  }

  void _toggleOrder() {
    setState(() => _reversed = !_reversed);
    _locateCurrent();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('目录（${widget.chapters.length} 章）',
                    style: TextStyle(
                        color: widget.foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  tooltip: _reversed ? '切换为正序' : '切换为倒序',
                  onPressed: _toggleOrder,
                  icon: Icon(
                    _reversed ? Icons.arrow_upward : Icons.arrow_downward,
                    color: widget.foreground,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: widget.foreground),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.chapters.length,
                itemExtent: _kRowExtent,
                itemBuilder: (ctx, i) {
                  // 显示序 → 真实章节索引
                  final chapterIndex = _reversed
                      ? widget.chapters.length - 1 - i
                      : i;
                  final current = chapterIndex == widget.currentIndex;
                  return ListTile(
                    dense: true,
                    selected: current,
                    selectedTileColor: Colors.blueAccent.withValues(alpha: 0.15),
                    title: Text(
                      widget.chapters[chapterIndex].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: current ? Colors.blueAccent : widget.foreground,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () => widget.onSelect(chapterIndex),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
