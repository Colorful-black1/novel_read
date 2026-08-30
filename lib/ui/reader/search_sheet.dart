/// 书内全文搜索浮层。
///
/// 在阅读页已加载的整书内容上搜索（Isolate 中执行，避免大书卡 UI），
/// 结果展示命中上下文摘录，点击跳转到对应章节与页。
library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../data/model/models.dart';

/// 单条搜索结果
class SearchResult {
  final int chapterIndex;
  final int globalOffset;

  /// 命中词前后的上下文摘录（换行已压平）
  final String before;
  final String match;
  final String after;

  const SearchResult({
    required this.chapterIndex,
    required this.globalOffset,
    required this.before,
    required this.match,
    required this.after,
  });
}

/// 结果条数上限，防止大书泛匹配刷爆列表
const int _kMaxResults = 200;

class SearchSheet extends StatefulWidget {
  final String content;
  final List<Chapter> chapters;
  final Color foreground;
  final Color background;
  final void Function(int chapterIndex, int globalOffset) onSelect;

  const SearchSheet({
    super.key,
    required this.content,
    required this.chapters,
    required this.foreground,
    required this.background,
    required this.onSelect,
  });

  @override
  State<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<SearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<SearchResult> _results = const [];
  bool _searching = false;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final runId = ++_runId;
    setState(() => _searching = true);
    final results = await Isolate.run(() => searchContent(
          widget.content,
          widget.chapters,
          query,
        ));
    // 防止旧搜索的迟到结果覆盖新搜索
    if (!mounted || runId != _runId) return;
    setState(() {
      _results = results;
      _searching = false;
    });
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
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _runSearch(),
                    style: TextStyle(color: fg, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '搜索正文内容',
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
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: fg),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _resultSummary(),
              style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12),
            ),
          ),
          Divider(height: 1, color: fg.withValues(alpha: 0.15)),
          Expanded(child: _buildResults(fg)),
        ],
      ),
    );
  }

  String _resultSummary() {
    if (_searching) return '搜索中…';
    final q = _controller.text.trim();
    if (q.isEmpty) return '输入关键词搜索全书';
    if (_results.isEmpty) return '没有找到「$q」';
    var summary = '共 ${_results.length} 条结果';
    if (_results.length >= _kMaxResults) summary += '（已达上限）';
    return summary;
  }

  Widget _buildResults(Color fg) {
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      itemBuilder: (ctx, i) {
        final r = _results[i];
        final chapter = r.chapterIndex >= 0 && r.chapterIndex < widget.chapters.length
            ? widget.chapters[r.chapterIndex].title
            : '第${r.chapterIndex + 1}章';
        return ListTile(
          dense: true,
          title: Text.rich(
            TextSpan(
              style: TextStyle(color: fg, fontSize: 14),
              children: [
                if (r.before.isNotEmpty) TextSpan(text: r.before),
                TextSpan(
                  text: r.match,
                  style: const TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.w600),
                ),
                if (r.after.isNotEmpty) TextSpan(text: r.after),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            chapter,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12),
          ),
          onTap: () => widget.onSelect(r.chapterIndex, r.globalOffset),
        );
      },
    );
  }
}

/// 全书搜索（在 Isolate 中执行）：大小写不敏感，返回摘录与全局偏移。
List<SearchResult> searchContent(
    String content, List<Chapter> chapters, String query) {
  if (content.isEmpty || query.isEmpty) return const [];
  final lower = content.toLowerCase();
  final q = query.toLowerCase();
  final results = <SearchResult>[];
  var pos = 0;
  var chapterIdx = 0;
  while (results.length < _kMaxResults) {
    final hit = lower.indexOf(q, pos);
    if (hit < 0) break;
    // 命中位置单调递增，章节游标只需前进不需回退
    while (chapterIdx < chapters.length - 1 &&
        chapters[chapterIdx].endOffset <= hit) {
      chapterIdx++;
    }
    final matchEnd = hit + q.length;
    final excerptStart = (hit - 20).clamp(0, content.length);
    final excerptEnd = (matchEnd + 20).clamp(0, content.length);
    String flatten(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
    results.add(SearchResult(
      chapterIndex: chapterIdx,
      globalOffset: hit,
      before: flatten(
          content.substring(excerptStart, hit)),
      match: content.substring(hit, matchEnd),
      after: flatten(content.substring(matchEnd, excerptEnd)),
    ));
    pos = matchEnd;
  }
  return results;
}
