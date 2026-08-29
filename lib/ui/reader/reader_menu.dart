/// 阅读菜单浮层与设置面板。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/model/models.dart';
import '../../logic/providers.dart';
import '../../logic/read_config.dart';

class ReaderMenu extends StatelessWidget {
  final bool visible;
  final Book book;
  final int chapterIndex;
  final int chapterCount;
  final int pageIndex;
  final int pageCount;
  final VoidCallback onBack;
  final VoidCallback onToggleToc;
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
    required this.onBack,
    required this.onToggleToc,
    required this.onPrevChapter,
    required this.onNextChapter,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
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
                    tooltip: '目录',
                    color: Colors.white,
                    onPressed: visible ? onToggleToc : null,
                    icon: const Icon(Icons.menu_book_outlined),
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
                  Row(
                    children: [
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
            // PC 专属选项
            if (Platform.isWindows) ...[
              const Divider(height: 1),
              _SettingSwitch(
                label: '老板键切换伪装皮肤（Alt+Q）',
                value: cfg.disguiseEnabled,
                color: fg,
                onChanged: (v) => change((c) => c.copyWith(disguiseEnabled: v)),
              ),
              _SettingSwitch(
                label: '失去焦点时自动模糊',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text(label, style: TextStyle(color: color))),
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
