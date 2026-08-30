/// 老板键快捷键设置对话框（首页入口，PC 专用）。
///
/// 按下组合键实时捕获显示，保存后写入阅读设置并立即重新注册全局热键。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/providers.dart';
import '../../services/boss_mode_service.dart';

class HotkeySettingsDialog extends ConsumerStatefulWidget {
  const HotkeySettingsDialog({super.key});

  @override
  ConsumerState<HotkeySettingsDialog> createState() =>
      _HotkeySettingsDialogState();
}

class _HotkeySettingsDialogState extends ConsumerState<HotkeySettingsDialog> {
  late String _captured;

  @override
  void initState() {
    super.initState();
    _captured = ref.read(readConfigProvider).bossHotkey;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // 只在按下时捕获，单独按修饰键不作为完整快捷键
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    const modifiers = [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
    ];
    if (modifiers.contains(key)) return KeyEventResult.handled;

    final parts = <String>[];
    if (HardwareKeyboard.instance.isControlPressed) parts.add('Ctrl');
    if (HardwareKeyboard.instance.isAltPressed) parts.add('Alt');
    if (HardwareKeyboard.instance.isShiftPressed) parts.add('Shift');
    if (HardwareKeyboard.instance.isMetaPressed) parts.add('Win');
    final label = key.keyLabel.trim();
    if (label.isEmpty) return KeyEventResult.handled;
    parts.add(label.toUpperCase());
    setState(() => _captured = parts.join('+'));
    return KeyEventResult.handled;
  }

  Future<void> _save() async {
    if (parseHotkey(_captured) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('快捷键需包含 Ctrl/Alt/Shift 任一修饰键 + 主键')));
      return;
    }
    final ok = await BossModeService.instance.registerHotkey(_captured);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('快捷键 $_captured 注册失败，可能已被其他软件占用，请换一个组合')));
      return;
    }
    ref.read(readConfigProvider.notifier).update((c) => c.copyWith(bossHotkey: _captured));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('老板键快捷键'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请按下新的快捷键组合（需包含 Ctrl/Alt/Shift 任一修饰键）',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Focus(
            autofocus: true,
            onKeyEvent: _onKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _captured,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
