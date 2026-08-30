/// 目录选择浮层。
///
/// 目录/书签双 Tab；目录支持标题搜索、正序/倒序切换、打开时定位当前章节；
/// 书签显示章节名与正文摘录，点击跳转、长按删除。
library;

import 'package:flutter/material.dart';

import '../../data/model/models.dart';

/// 与 itemBuilder 的固定行高一致，用于计算定位偏移
const double _kRowExtent = 44;

class TocSheet extends StatefulWidget {
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final int currentIndex;
  final Color foreground;
  final Color background;
  final ValueChanged<int> onSelect;
  final ValueChanged<Bookmark> onSelectBookmark;
  final Future<void> Function(Bookmark bookmark) onDeleteBookmark;

  const TocSheet({
    super.key,
    required this.chapters,
    required this.bookmarks,
    required this.currentIndex,
    required this.foreground,
    required this.background,
    required this.onSelect,
    required this.onSelectBookmark,
    required this.onDeleteBookmark,
  });

  @override
  State<TocSheet> createState() => _TocSheetState();
}

class _TocSheetState extends State<TocSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _reversed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 等列表完成首次布局（controller attach）后再定位
    WidgetsBinding.instance.addPostFrameCallback((_) => _locateCurrent());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 按标题过滤后的章节索引列表（真实索引）
  List<int> get _filteredIndices {
    final q = _query.trim().toLowerCase();
    final all = List<int>.generate(widget.chapters.length, (i) => i);
    if (q.isEmpty) return _reversed ? all.reversed.toList() : all;
    final matched = all
        .where((i) => widget.chapters[i].title.toLowerCase().contains(q))
        .toList();
    return _reversed ? matched.reversed.toList() : matched;
  }

  /// 定位到当前章节（显示序 → 真实索引换算后滚动）
  void _locateCurrent() {
    if (!_controllerReady) return;
    if (_query.isNotEmpty) return;
    final displayIndex = _reversed
        ? widget.chapters.length - 1 - widget.currentIndex
        : widget.currentIndex;
    final target = displayIndex * _kRowExtent;
    _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent));
  }

  bool get _controllerReady =>
      _scrollController.hasClients && _scrollController.position.hasContentDimensions;

  void _toggleOrder() {
    setState(() => _reversed = !_reversed);
    _locateCurrent();
  }

  Future<void> _confirmDelete(Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书签'),
        content: Text('确定删除「${_chapterTitleOf(bookmark)}」处的书签吗？'),
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
    if (confirmed != true || !mounted) return;
    // 阅读页删除后列表已原地移除，这里刷新本弹层
    await widget.onDeleteBookmark(bookmark);
    if (mounted) setState(() {});
  }

  String _chapterTitleOf(Bookmark bookmark) {
    final idx = bookmark.chapterIndex;
    if (idx < 0 || idx >= widget.chapters.length) return '第${idx + 1}章';
    return widget.chapters[idx].title;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground;
    final bg = widget.background;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: fg,
                    indicatorColor: Colors.blueAccent,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '目录'),
                      Tab(text: '书签'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: fg),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: fg.withValues(alpha: 0.15)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTocTab(fg), _buildBookmarkTab(fg)],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 目录 Tab ----------------

  Widget _buildTocTab(Color fg) {
    final indices = _filteredIndices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: fg, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '搜索章节标题',
                    hintStyle: TextStyle(color: fg.withValues(alpha: 0.4)),
                    prefixIcon: Icon(Icons.search,
                        size: 20, color: fg.withValues(alpha: 0.5)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _reversed ? '切换为正序' : '切换为倒序',
                onPressed: _toggleOrder,
                icon: Icon(
                  _reversed ? Icons.arrow_upward : Icons.arrow_downward,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: fg.withValues(alpha: 0.15)),
        Expanded(
          child: indices.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? '暂无章节' : '没有匹配的章节',
                    style: TextStyle(color: fg.withValues(alpha: 0.5)),
                  ),
                )
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: indices.length,
                    itemExtent: _kRowExtent,
                    itemBuilder: (ctx, i) {
                      final chapterIndex = indices[i];
                      final current = chapterIndex == widget.currentIndex;
                      return ListTile(
                        dense: true,
                        selected: current,
                        selectedTileColor:
                            Colors.blueAccent.withValues(alpha: 0.15),
                        title: Text(
                          widget.chapters[chapterIndex].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                current ? Colors.blueAccent : fg,
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
    );
  }

  // ---------------- 书签 Tab ----------------

  Widget _buildBookmarkTab(Color fg) {
    final bookmarks = widget.bookmarks;
    if (bookmarks.isEmpty) {
      return Center(
        child: Text('暂无书签\n打开菜单点击书签按钮即可收藏当前页',
            textAlign: TextAlign.center,
            style: TextStyle(color: fg.withValues(alpha: 0.5))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: bookmarks.length,
      itemBuilder: (ctx, i) {
        final bookmark = bookmarks[i];
        return ListTile(
          dense: true,
          leading: Icon(Icons.bookmark, size: 20, color: Colors.blueAccent),
          title: Text(
            _chapterTitleOf(bookmark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontSize: 14),
          ),
          subtitle: bookmark.snippet.isEmpty
              ? null
              : Text(
                  bookmark.snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.5), fontSize: 12),
                ),
          onTap: () => widget.onSelectBookmark(bookmark),
          onLongPress: () => _confirmDelete(bookmark),
        );
      },
    );
  }
}
