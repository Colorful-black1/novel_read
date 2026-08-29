/// 阅读页：分页渲染、翻页/滚动模式、菜单浮层、进度保存。
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/paginator.dart';
import '../../data/model/models.dart';
import '../../logic/import_service.dart';
import '../../logic/providers.dart';
import '../../logic/read_config.dart';
import '../../services/boss_mode_service.dart';
import 'reader_menu.dart';
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
    if (cfg.pageMode == PageMode.horizontal) {
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

  double? _viewportHeight;

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
    // PC：失焦自动模糊
    final blurred = Platform.isWindows &&
        cfg.blurOnFocusLost &&
        ref.watch(windowBlurredProvider);

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
        final pages = Paginator.paginate(
          text: _chapterText,
          style: style,
          lineHeight: cfg.effectiveLineHeight,
          viewport: constraints.biggest,
          padding: readerPadding,
        );
        _lastPages = pages;

        // 初次进入：定位到恢复的进度页
        if (_pendingCharOffset > 0) {
          final target = Paginator.locate(pages, _pendingCharOffset);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (cfg.pageMode == PageMode.horizontal) {
              _ensurePageController().jumpToPage(target);
            } else {
              _ensureScrollController().jumpTo(target * constraints.maxHeight);
            }
            setState(() => _pageIndex = target);
          });
          _pendingCharOffset = 0;
        } else if (_pageIndex >= pages.length) {
          _pageIndex = pages.length - 1;
        }

        final contentStack = Stack(
          children: [
            Positioned.fill(
              child: cfg.pageMode == PageMode.horizontal
                  ? _buildPageView(pages, style, bg)
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
              onBack: () {
                _saveNow();
                Navigator.of(context).pop();
              },
              onToggleToc: () => _openToc(context, cfg),
              onPrevChapter: () =>
                  _goChapter(_chapterIndex - 1, toLastPage: true),
              onNextChapter: () => _goChapter(_chapterIndex + 1),
              onOpenSettings: () => _openSettings(context),
            ),
          ],
        );

        // PC：窗口失焦时整页模糊
        if (blurred) {
          return ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: contentStack,
            ),
          );
        }
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
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      onPageChanged: (i) => _onPageChanged(i, pages),
      itemBuilder: (ctx, i) =>
          _pageContent(pages[i], style, bg, _viewportHeight ?? 800),
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
        currentIndex: _chapterIndex,
        foreground: Color(ref.read(effectiveThemeProvider).foreground),
        background: Color(ref.read(effectiveThemeProvider).background),
        onSelect: (i) {
          Navigator.pop(context);
          _goChapter(i);
        },
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
