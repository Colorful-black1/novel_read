/// 阅读菜单浮层与设置面板。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/model/models.dart';
import '../../logic/providers.dart';
import '../../logic/read_config.dart';
import '../../services/boss_mode_service.dart';

class ReaderMenu extends ConsumerWidget {
  final bool visible;
  final Book book;
  final int chapterIndex;
  final int chapterCount;
  final int pageIndex;
  final int pageCount;
  final List<Chapter> chapters;
  final int contentLength;
  final double globalPercent;
  final bool bookmarked;
  final VoidCallback onBack;
  final VoidCallback onToggleToc;
  final VoidCallback onSearch;
  final VoidCallback onToggleBookmark;
  final ValueChanged<double> onSeek;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onOpenSettings;

  const ReaderMenu({
    super.key,
    required this.visible,
    required this.book,
    required this.chapterIndex,
    required this.chapterCount,
    required this.pageIndex,
    required this.pageCount,
    required this.chapters,
    required this.contentLength,
    required this.globalPercent,
    required this.bookmarked,
    required this.onBack,
    required this.onToggleToc,
    required this.onSearch,
    required this.onToggleBookmark,
    required this.onSeek,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(readConfigProvider);
    final notifier = ref.read(readConfigProvider.notifier);
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Column(
          children: [
            // 顶栏
            Container(
              color: Colors.black87,
              padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + 4,
                  bottom: 8,
                  left: 4,
                  right: 16),
              child: Row(
                children: [
                  BackButton(
                      color: Colors.white,
                      onPressed: visible ? onBack : null),
                  Expanded(
                    child: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: '搜索',
                    color: Colors.white,
                    onPressed: visible ? onSearch : null,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: '目录',
                    color: Colors.white,
                    onPressed: visible ? onToggleToc : null,
                    icon: const Icon(Icons.menu_book_outlined),
                  ),
                  // PC：窗口钉住置顶（钉住时老板键失效）
                  if (Platform.isWindows)
                    IconButton(
                      tooltip: cfg.pinned ? '取消钉住' : '钉住窗口（置顶，老板键失效）',
                      color: Colors.white,
                      onPressed: visible
                          ? () {
                              notifier
                                  .update((c) => c.copyWith(pinned: !c.pinned));
                              BossModeService.instance
                                  .setPinned(!cfg.pinned);
                            }
                          : null,
                      icon: Icon(cfg.pinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined),
                    ),
                ],
              ),
            ),
            const Spacer(),
            // 底栏
            Container(
              color: Colors.black87,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 8,
                  top: 8,
                  left: 16,
                  right: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('第 ${chapterIndex + 1}/$chapterCount 章  ·  第 ${pageIndex + 1}/$pageCount 页',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      TextButton(
                        onPressed: visible ? onOpenSettings : null,
                        child: const Text('阅读设置',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  // 全书进度跳转滑条（拖动中实时预览目标章节，松手跳转）
                  _ProgressSlider(
                    chapters: chapters,
                    contentLength: contentLength,
                    globalPercent: globalPercent,
                    enabled: visible,
                    color: Colors.white,
                    onSeek: onSeek,
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: bookmarked ? '移除书签' : '添加书签',
                        color: Colors.white,
                        onPressed: visible ? onToggleBookmark : null,
                        icon: Icon(bookmarked
                            ? Icons.bookmark
                            : Icons.bookmark_border),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed:
                              chapterIndex > 0 && visible ? onPrevChapter : null,
                          child: const Text('上一章'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: chapterIndex < chapterCount - 1 && visible
                              ? onNextChapter
                              : null,
                          child: const Text('下一章'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 阅读设置面板（字号 / 行距 / 字体 / 背景 / 翻页模式 / 夜间 / 亮度 / PC 伪装）
class ReaderSettingsPanel extends ConsumerWidget {
  const ReaderSettingsPanel({super.key});

  static const _fontOptions = [
    ('默认', ''),
    ('宋体', 'SimSun'),
    ('黑体', 'SimHei'),
    ('楷体', 'KaiTi'),
    ('微软雅黑', 'Microsoft YaHei'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(readConfigProvider);
    final notifier = ref.read(readConfigProvider.notifier);
    final theme = ref.watch(effectiveThemeProvider);
    final bg = Color(theme.background);
    final fg = Color(theme.foreground);

    void change(ReadConfig Function(ReadConfig) updater) =>
        notifier.update(updater);

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 背景主题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  for (var i = 0; i < readerThemes.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _ThemeDot(
                        readerTheme: readerThemes[i],
                        selected: cfg.themeIndex == i && !cfg.nightMode,
                        onTap: () => change((c) =>
                            c.copyWith(themeIndex: i, nightMode: false)),
                      ),
                    ),
                  const Spacer(),
                  _SettingSwitch(
                    label: '夜间模式',
                    value: cfg.nightMode,
                    color: fg,
                    onChanged: (v) => change((c) => c.copyWith(nightMode: v)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 翻页模式
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Text('翻页', style: TextStyle(color: fg)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SegmentedButton<PageMode>(
                      segments: const [
                        ButtonSegment(
                            value: PageMode.scroll,
                            label: Text('上下滚动')),
                        ButtonSegment(
                            value: PageMode.horizontal,
                            label: Text('左右翻页')),
                        ButtonSegment(
                            value: PageMode.cover,
                            label: Text('覆盖')),
                      ],
                      selected: {cfg.pageMode},
                      onSelectionChanged: (s) =>
                          change((c) => c.copyWith(pageMode: s.first)),
                    ),
                  ),
                ],
              ),
            ),
            // 字号
            _SliderRow(
              label: '字号',
              valueLabel: cfg.fontSize.round().toString(),
              value: cfg.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              color: fg,
              onChanged: (v) => change((c) => c.copyWith(fontSize: v)),
            ),
            // 行距
            _SliderRow(
              label: '行距',
              valueLabel: cfg.lineSpacing.toStringAsFixed(2),
              value: cfg.lineSpacing,
              min: 1.1,
              max: 2.4,
              divisions: 13,
              color: fg,
              onChanged: (v) => change((c) => c.copyWith(lineSpacing: v)),
            ),
            // 亮度
            _SliderRow(
              label: '亮度',
              valueLabel: (100 - (cfg.brightnessMask / 0.6 * 100).round()).toString(),
              value: 0.6 - cfg.brightnessMask,
              min: 0,
              max: 0.6,
              divisions: 12,
              color: fg,
              onChanged: (v) =>
                  change((c) => c.copyWith(brightnessMask: 0.6 - v)),
            ),
            // 字体
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Row(
                children: [
                  Text('字体', style: TextStyle(color: fg)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final (name, value) in _fontOptions)
                          ChoiceChip(
                            label: Text(name),
                            selected: cfg.fontFamily == value,
                            onSelected: (_) =>
                                change((c) => c.copyWith(fontFamily: value)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // PC 专属选项（伪装对象在「设置」页配置）
            if (Platform.isWindows) ...[
              const Divider(height: 1),
              _SettingSwitch(
                label: '失去焦点时自动最小化',
                value: cfg.blurOnFocusLost,
                color: fg,
                onChanged: (v) => change((c) => c.copyWith(blurOnFocusLost: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeDot extends StatelessWidget {
  final ReaderTheme readerTheme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeDot({
    required this.readerTheme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: readerTheme.name,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Color(readerTheme.background),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.blueAccent : Colors.black26,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 16, color: Colors.blueAccent)
              : null,
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });

  /// 单步增量（与 Slider divisions 对齐）
  double get _step => (max - min) / divisions;

  /// 步进后量化到档位，避免浮点误差累积
  double _stepped(int direction) {
    final steps = ((value - min) / _step).round() + direction;
    return (min + steps * _step).clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text(label, style: TextStyle(color: color))),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: color,
            onPressed: value > min ? () => onChanged(_stepped(-1)) : null,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: Colors.blueAccent,
              onChanged: onChanged,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: color,
            onPressed: value < max ? () => onChanged(_stepped(1)) : null,
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
          SizedBox(
              width: 40,
              child: Text(valueLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// 全书进度滑条：拖动中按字符偏移映射章节（只查偏移不触发分页），
/// 松手后通过 onSeek 跳转（由阅读页定位章节 + 页内偏移）。
class _ProgressSlider extends StatefulWidget {
  final List<Chapter> chapters;
  final int contentLength;
  final double globalPercent;
  final bool enabled;
  final Color color;
  final ValueChanged<double> onSeek;

  const _ProgressSlider({
    required this.chapters,
    required this.contentLength,
    required this.globalPercent,
    required this.enabled,
    required this.color,
    required this.onSeek,
  });

  @override
  State<_ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<_ProgressSlider> {
  /// 拖动中的临时值，null 表示未在拖动
  double? _dragValue;

  /// 按全书比例值解析目标章节（章节按 startOffset 有序）
  Chapter? _chapterAt(double value) {
    if (widget.chapters.isEmpty || widget.contentLength <= 0) return null;
    final global = (value * widget.contentLength).round().clamp(0, widget.contentLength - 1);
    var idx = 0;
    var lo = 0;
    var hi = widget.chapters.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (widget.chapters[mid].startOffset <= global) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return widget.chapters[idx];
  }

  String _label(double value) {
    final chapter = _chapterAt(value);
    if (chapter == null) return '';
    final percent = (value * 100).toStringAsFixed(1);
    return '第${widget.chapters.indexOf(chapter) + 1}章 ${chapter.title}  ·  $percent%';
  }

  @override
  Widget build(BuildContext context) {
    final value = _dragValue ?? widget.globalPercent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: widget.enabled && widget.chapters.isNotEmpty
                ? (v) => setState(() => _dragValue = v)
                : null,
            onChangeEnd: widget.enabled && widget.chapters.isNotEmpty
                ? (v) {
                    widget.onSeek(v);
                    setState(() => _dragValue = null);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _dragValue == null
                ? '全书 ${(widget.globalPercent * 100).toStringAsFixed(1)}%'
                : _label(_dragValue!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: widget.color.withValues(alpha: 0.7), fontSize: 12),
          ),
        ),
      ],
    );
  }
}
