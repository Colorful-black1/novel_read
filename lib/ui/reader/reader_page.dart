/// 阅读页：分页渲染、翻页/滚动模式、菜单浮层、进度保存。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/paginator.dart';
import '../../data/model/models.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';
import '../../logic/read_config.dart';
import 'reader_menu.dart';
import 'search_sheet.dart';
import 'toc_sheet.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final Book book;

  const ReaderPage({super.key, required this.book});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  String _content = '';
  List<Chapter> _chapters = [];
  List<Bookmark> _bookmarks = [];
  bool _loading = true;
  String? _error;

  int _chapterIndex = 0;
  int _pageIndex = 0;
  bool _menuVisible = false;

  PageController? _pageController;
  ScrollController? _scrollController;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _pageController?.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  Future<void> _loadBook() async {
    try {
      final service = ImportService(ref.read(bookRepositoryProvider));
      final content = await service.readBookContent(widget.book);
      final chapters =
          await ref.read(bookRepositoryProvider).listChapters(widget.book.id);
      final bookmarks = await ref
          .read(bookmarkRepositoryProvider)
          .listBookmarks(widget.book.bookKey);

      // 恢复上次进度
      var chapterIndex = 0;
      var charOffset = 0;
      final progress = await ref
          .read(progressRepositoryProvider)
          .getProgress(widget.book.bookKey);
      if (progress != null) {
        chapterIndex = progress.chapterIndex.clamp(0, chapters.length - 1);
        charOffset = progress.charOffset;
      }
      if (!mounted) return;
      setState(() {
        _content = content;
        _chapters = chapters;
        _bookmarks = bookmarks;
        _chapterIndex = chapterIndex;
        _pendingCharOffset = charOffset;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// 恢复进度时使用的目标字符偏移（定位到页后清零）
  int _pendingCharOffset = 0;

  Chapter get _currentChapter => _chapters[_chapterIndex];

  String get _chapterText {
    final c = _currentChapter;
    final end = c.endOffset.clamp(0, _content.length);
    final start = c.startOffset.clamp(0, end);
    return _content.substring(start, end);
  }

  TextStyle _bodyStyle(ReadConfig cfg, ReaderTheme theme) {
    return TextStyle(
      fontSize: cfg.fontSize,
      height: cfg.lineSpacing,
      color: Color(theme.foreground),
      fontFamily: cfg.fontFamily.isEmpty ? null : cfg.fontFamily,
    );
  }

  void _onPageChanged(int index, List<PageRange> pages) {
    setState(() {
      _pageIndex = index.clamp(0, pages.length - 1);
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _saveNow);
  }

  Future<void> _saveNow() async {
    if (_chapters.isEmpty) return;
    final pages = _lastPages;
    if (pages == null || pages.isEmpty) return;
    final page = pages[_pageIndex.clamp(0, pages.length - 1)];
    final chapter = _currentChapter;
    final globalOffset = chapter.startOffset + page.start;
    final percent =
        _content.isEmpty ? 0.0 : globalOffset / _content.length;
    await ref.read(progressRepositoryProvider).saveProgress(ReadingProgress(
          bookKey: widget.book.bookKey,
          chapterIndex: _chapterIndex,
          charOffset: page.start,
          percent: percent.clamp(0.0, 1.0),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
  }

  List<PageRange>? _lastPages;

  /// 分页缓存（key = 章节+样式+视口，见 build 中说明）
  String? _pagesCacheKey;
  List<PageRange>? _cachedPages;

  /// 当前翻页控制器所属章节（章节切换时需重建控制器）
  int _controllerChapterIndex = -1;

  // ---------------- 翻页 ----------------

  void _goPage(int delta, List<PageRange> pages) {
    final target = _pageIndex + delta;
    if (target >= 0 && target < pages.length) {
      _jumpToPage(target, pages);
    } else if (target < 0) {
      _goChapter(_chapterIndex - 1, toLastPage: true);
    } else {
      _goChapter(_chapterIndex + 1);
    }
  }

  void _jumpToPage(int index, List<PageRange> pages) {
    index = index.clamp(0, pages.length - 1);
    final cfg = ref.read(readConfigProvider);
    if (cfg.pageMode != PageMode.scroll) {
      _pageController?.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      final viewport = _viewportHeight ?? 800;
      _scrollController?.animateTo(
        index * viewport,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    _onPageChanged(index, pages);
  }

  Future<void> _goChapter(int index, {bool toLastPage = false}) async {
    if (index < 0 || index >= _chapters.length) return;
    setState(() {
      _chapterIndex = index;
      // 跳上一章时定位到章末（locate 对超出范围的偏移返回最后一页）
      _pendingCharOffset = toLastPage ? _chapters[index].endOffset : 0;
      _pageIndex = 0;
    });
    _scheduleSave();
  }

  // ---------------- 书签 / 进度跳转 / 搜索 ----------------

  /// 当前页锚点：本章内首个字符偏移（与进度保存的 charOffset 同语义）
  int? _anchorOffset() {
    final pages = _lastPages;
    if (pages == null || pages.isEmpty || _chapters.isEmpty) return null;
    final page = pages[_pageIndex.clamp(0, pages.length - 1)];
    return page.start;
  }

  bool _isCurrentPageBookmarked() {
    final anchor = _anchorOffset();
    if (anchor == null) return false;
    return _bookmarks.any(
        (b) => b.chapterIndex == _chapterIndex && b.charOffset == anchor);
  }

  Future<void> _toggleBookmark() async {
    final anchor = _anchorOffset();
    if (anchor == null) return;
    final repo = ref.read(bookmarkRepositoryProvider);
    final existing = _bookmarks.where(
        (b) => b.chapterIndex == _chapterIndex && b.charOffset == anchor);
    if (existing.isNotEmpty) {
      for (final b in existing) {
        await repo.deleteBookmark(b.id);
      }
      setState(() {
        _bookmarks.removeWhere((b) => existing.contains(b));
      });
      return;
    }
    // 摘录：从页首起 60 字，压平换行便于列表预览
    final text = _chapterText;
    final raw =
        text.substring(anchor.clamp(0, text.length), (anchor + 60).clamp(0, text.length));
    final snippet =
        raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final bookmark = Bookmark(
      bookKey: widget.book.bookKey,
      chapterIndex: _chapterIndex,
      charOffset: anchor,
      snippet: snippet,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final id = await repo.addBookmark(bookmark);
    setState(() {
      _bookmarks.add(Bookmark(
        id: id,
        bookKey: bookmark.bookKey,
        chapterIndex: bookmark.chapterIndex,
        charOffset: bookmark.charOffset,
        snippet: bookmark.snippet,
        createdAtMs: bookmark.createdAtMs,
      ));
    });
  }

  void _jumpToBookmark(Bookmark bookmark) {
    if (bookmark.chapterIndex < 0 ||
        bookmark.chapterIndex >= _chapters.length) {
      return;
    }
    setState(() {
      _chapterIndex = bookmark.chapterIndex;
      _pendingCharOffset = bookmark.charOffset;
      _pageIndex = 0;
    });
    _scheduleSave();
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    await ref.read(bookmarkRepositoryProvider).deleteBookmark(bookmark.id);
    setState(() {
      _bookmarks.remove(bookmark);
    });
  }

  /// 全书进度滑条落点：按字符偏移定位章节与页
  void _seekTo(double value) {
    if (_content.isEmpty || _chapters.isEmpty) return;
    final global = (value * _content.length).round().clamp(0, _content.length - 1);
    // 二分找 startOffset <= global 的最后一个章节
    var idx = 0;
    var lo = 0;
    var hi = _chapters.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_chapters[mid].startOffset <= global) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final chapter = _chapters[idx];
    final chapterLen = chapter.endOffset - chapter.startOffset;
    final local = chapterLen <= 0 ? 0 : (global - chapter.startOffset).clamp(0, chapterLen - 1);
    setState(() {
      _chapterIndex = idx;
      _pendingCharOffset = local;
      _pageIndex = 0;
    });
    _scheduleSave();
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchSheet(
        content: _content,
        chapters: _chapters,
        foreground: Color(ref.read(effectiveThemeProvider).foreground),
        background: Color(ref.read(effectiveThemeProvider).background),
        onSelect: (chapterIndex, globalOffset) {
          Navigator.pop(context);
          final chapter = _chapters[chapterIndex];
          final chapterLen = chapter.endOffset - chapter.startOffset;
          setState(() {
            _chapterIndex = chapterIndex;
            _pendingCharOffset = chapterLen <= 0
                ? 0
                : (globalOffset - chapter.startOffset).clamp(0, chapterLen - 1);
            _pageIndex = 0;
          });
          _scheduleSave();
        },
      ),
    );
  }

  double? _viewportHeight;
  double? _viewportWidth;

  void _onTapZone(TapUpDetails d, BoxConstraints c, List<PageRange> pages) {
    final x = d.localPosition.dx;
    if (x < c.maxWidth * 0.3) {
      _goPage(-1, pages);
    } else if (x > c.maxWidth * 0.7) {
      _goPage(1, pages);
    } else {
      setState(() => _menuVisible = !_menuVisible);
    }
  }

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(readConfigProvider);
    final theme = ref.watch(effectiveThemeProvider);
    final bg = Color(theme.background);
    final fg = Color(theme.foreground);
    final style = _bodyStyle(cfg, theme);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, foregroundColor: fg),
        body: Center(
          child: Text('加载失败：$_error\n请检查原 TXT 文件是否仍存在。',
              textAlign: TextAlign.center, style: TextStyle(color: fg)),
        ),
      );
    }
    if (_chapters.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(child: Text('该书没有章节信息', style: TextStyle(color: fg))),
      );
    }

    final chapterTitle = _currentChapter.title;

    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(builder: (ctx, constraints) {
        _viewportHeight = constraints.maxHeight;
        _viewportWidth = constraints.maxWidth;
        // 分页缓存：章节/字号/行距/字体/视口 任一变化才重排。
        // 排版是 UI 线程上的重操作，翻页/呼出菜单/失焦等普通重建必须复用缓存，
        // 否则大章节每次 setState 都会重新分页导致明显卡顿。
        final pageKey = '$_chapterIndex|${cfg.fontSize}|${cfg.lineSpacing}|'
            '${cfg.fontFamily}|'
            '${constraints.maxWidth.round()}x${constraints.maxHeight.round()}';
        if (pageKey != _pagesCacheKey || _cachedPages == null) {
          _cachedPages = Paginator.paginate(
            text: _chapterText,
            style: style,
            lineHeight: cfg.effectiveLineHeight,
            viewport: constraints.biggest,
            padding: readerPadding,
          );
          _pagesCacheKey = pageKey;
        }
        final pages = _cachedPages!;
        _lastPages = pages;

        // 解析本章目标页：恢复的进度 / 章末回跳 / 普通越界钳制
        var targetPage = _pageIndex;
        if (_pendingCharOffset > 0) {
          targetPage = Paginator.locate(pages, _pendingCharOffset);
          _pendingCharOffset = 0;
        } else if (_pageIndex >= pages.length) {
          targetPage = pages.length - 1;
        }

        // 章节切换后必须重建翻页控制器：旧控制器停留在上一章的页位置，
        // 直接复用会让新章节从旧页码开始显示（表现为跳过新章节前面的页）。
        if (_controllerChapterIndex != _chapterIndex) {
          final oldPageController = _pageController;
          final oldScrollController = _scrollController;
          // 延迟到帧末销毁，避免与当前帧仍在引用旧控制器的组件树冲突
          WidgetsBinding.instance.addPostFrameCallback((_) {
            oldPageController?.dispose();
            oldScrollController?.dispose();
          });
          _pageController = PageController(initialPage: targetPage);
          _scrollController = ScrollController(
            initialScrollOffset: targetPage * constraints.maxHeight,
          );
          _controllerChapterIndex = _chapterIndex;
        }
        if (_pageIndex != targetPage) {
          _pageIndex = targetPage;
        }

        final contentStack = Stack(
          children: [
            Positioned.fill(
              child: cfg.pageMode == PageMode.horizontal
                  ? _buildPageView(pages, style, bg)
                  : cfg.pageMode == PageMode.cover
                      ? _buildCoverView(pages, style, bg)
                      : _buildScrollList(pages, style, bg),
            ),
            // 亮度遮罩（最上层内容，不拦截手势）
            if (cfg.brightnessMask > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Colors.black
                        .withValues(alpha: cfg.brightnessMask.clamp(0.0, 0.6)),
                  ),
                ),
              ),
            // 手势层：点击翻页 / 呼出菜单
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => _onTapZone(d, constraints, pages),
                child: Container(color: Colors.transparent),
              ),
            ),
            // 页眉章节名
            Positioned(
              top: 12,
              left: 20,
              right: 20,
              child: Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.5)),
              ),
            ),
            // 菜单浮层
            ReaderMenu(
              visible: _menuVisible,
              book: widget.book,
              chapterIndex: _chapterIndex,
              chapterCount: _chapters.length,
              pageIndex: _pageIndex,
              pageCount: pages.length,
              chapters: _chapters,
              contentLength: _content.length,
              globalPercent: _content.isEmpty
                  ? 0.0
                  : ((_currentChapter.startOffset +
                              pages[_pageIndex.clamp(0, pages.length - 1)]
                                  .start) /
                          _content.length)
                      .clamp(0.0, 1.0),
              bookmarked: _isCurrentPageBookmarked(),
              onBack: () {
                _saveNow();
                Navigator.of(context).pop();
              },
              onToggleToc: () => _openToc(context, cfg),
              onSearch: () => _openSearch(context),
              onToggleBookmark: _toggleBookmark,
              onSeek: _seekTo,
              onPrevChapter: () =>
                  _goChapter(_chapterIndex - 1, toLastPage: true),
              onNextChapter: () => _goChapter(_chapterIndex + 1),
              onOpenSettings: () => _openSettings(context),
            ),
          ],
        );

        // PC：失焦自动最小化由 BossModeService.onWindowBlur 处理
        return contentStack;
      }),
    );
  }

  PageController _ensurePageController() {
    return _pageController ??= PageController(initialPage: _pageIndex);
  }

  ScrollController _ensureScrollController() {
    return _scrollController ??=
        ScrollController(initialScrollOffset: _pageIndex * (_viewportHeight ?? 800));
  }

  Widget _pageContent(
      PageRange page, TextStyle style, Color bg, double height) {
    final text = _chapterText.substring(
        page.start.clamp(0, _chapterText.length),
        page.end.clamp(0, _chapterText.length));
    return SizedBox(
      height: height,
      child: Padding(
        padding: readerPadding,
        child: Text(text, style: style),
      ),
    );
  }

  Widget _buildPageView(List<PageRange> pages, TextStyle style, Color bg) {
    final controller = _ensurePageController();
    // Key 必须随章节变化：Flutter 的 Scrollable 在只换 controller 时会复用旧
    // ScrollPosition（新控制器的 initialPage 不生效，画面停留在上一章页位），
    // 只有让 Scrollable 元素整体重建，initialPage 才会真正应用。
    return PageView.builder(
      key: ValueKey<int>(_chapterIndex),
      controller: controller,
      itemCount: pages.length,
      onPageChanged: (i) => _onPageChanged(i, pages),
      itemBuilder: (ctx, i) =>
          _pageContent(pages[i], style, bg, _viewportHeight ?? 800),
    );
  }

  /// 覆盖翻页：当前页保持不动，新页带阴影从右侧滑入盖住旧页。
  ///
  /// 原理：PageView 内所有页随视口一起平移，对视口左侧的页（d > i，d 为当前
  /// 滚动位置）反向平移 (d-i)*页宽 抵消视口移动，视觉上保持静止；右侧的页
  /// （滑入页）不做变换，自然滑入。仅相邻一页参与动画，左侧更远的页 clamp 后
  /// 仍位于屏幕外，不会穿帮。
  Widget _buildCoverView(List<PageRange> pages, TextStyle style, Color bg) {
    final controller = _ensurePageController();
    return PageView.builder(
      key: ValueKey<int>(_chapterIndex),
      controller: controller,
      itemCount: pages.length,
      onPageChanged: (i) => _onPageChanged(i, pages),
      itemBuilder: (ctx, i) {
        final width = _viewportWidth ?? 800;
        final height = _viewportHeight ?? 800;
        return AnimatedBuilder(
          animation: controller,
          builder: (ctx, _) {
            final d = controller.hasClients &&
                    controller.position.hasContentDimensions
                ? controller.position.pixels / width
                : i.toDouble();
            // 本页在视口左侧（被覆盖的旧页）：反向平移保持静止
            final coverOffset = (d - i).clamp(0.0, 1.0) * width;
            // 本页作为上层滑入页的进度（0~1），用于阴影强度
            final t = (i - d).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(coverOffset, 0),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: t > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3 * t),
                            blurRadius: 24 * t,
                            offset: Offset(-6 * t, 0),
                          ),
                        ]
                      : null,
                ),
                child: _pageContent(pages[i], style, bg, height),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScrollList(List<PageRange> pages, TextStyle style, Color bg) {
    final controller = _ensureScrollController();
    final pageHeight = _viewportHeight ?? 800;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels == 0 && n is ScrollUpdateNotification) return false;
        final idx = (n.metrics.pixels / pageHeight).round();
        if (idx != _pageIndex && idx >= 0 && idx < pages.length) {
          _onPageChanged(idx, pages);
        }
        return false;
      },
      child: ListView.builder(
        key: ValueKey<int>(_chapterIndex),
        controller: controller,
        itemCount: pages.length,
        itemExtent: pageHeight,
        itemBuilder: (ctx, i) =>
            _pageContent(pages[i], style, bg, pageHeight),
      ),
    );
  }

  // ---------------- 目录 / 设置 ----------------

  void _openToc(BuildContext context, ReadConfig cfg) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TocSheet(
        chapters: _chapters,
        bookmarks: _bookmarks,
        currentIndex: _chapterIndex,
        foreground: Color(ref.read(effectiveThemeProvider).foreground),
        background: Color(ref.read(effectiveThemeProvider).background),
        onSelect: (i) {
          Navigator.pop(context);
          _goChapter(i);
        },
        onSelectBookmark: (b) {
          Navigator.pop(context);
          _jumpToBookmark(b);
        },
        onDeleteBookmark: _deleteBookmark,
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReaderSettingsPanel(),
    );
  }
}
