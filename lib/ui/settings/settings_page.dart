/// 软件设置页：软件背景（预设 + 自定义图片）、PC 摸鱼（老板键）设置。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../logic/providers.dart';
import '../../logic/read_config.dart';
import '../../services/update_service.dart';
import '../home/hotkey_settings_dialog.dart';
import 'update_dialog.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(readConfigProvider);
    final sectionStyle = Theme.of(context)
        .textTheme
        .titleSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('设置'),
      ),
      body: ListView(
        // 底部留白：主框架 extendBody 后内容会延伸到透明导航栏后面
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text('外观', style: sectionStyle),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildBackgroundPicker(context, ref, cfg),
            ),
          ),
          if (Platform.isWindows) ...[
            const SizedBox(height: 8),
            Text('PC 摸鱼', style: sectionStyle),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.keyboard_alt_outlined),
                    title: const Text('老板键快捷键'),
                    trailing: Text(cfg.bossHotkey,
                        style: Theme.of(context).textTheme.bodySmall),
                    onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const HotkeySettingsDialog()),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.grid_on_outlined),
                            SizedBox(width: 8),
                            Text('老板键伪装对象'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('「无」= 直接隐藏窗口（含任务栏图标），再按恢复',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        SegmentedButton<DisguiseTarget>(
                          segments: const [
                            ButtonSegment(
                                value: DisguiseTarget.none, label: Text('无')),
                            ButtonSegment(
                                value: DisguiseTarget.excel, label: Text('Excel')),
                            ButtonSegment(
                                value: DisguiseTarget.word, label: Text('Word')),
                          ],
                          selected: {cfg.disguiseTarget},
                          onSelectionChanged: (s) => ref
                              .read(readConfigProvider.notifier)
                              .update((c) => c.copyWith(disguiseTarget: s.first)),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('失去焦点时自动最小化'),
                    value: cfg.blurOnFocusLost,
                    onChanged: (v) => ref
                        .read(readConfigProvider.notifier)
                        .update((c) => c.copyWith(blurOnFocusLost: v)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text('关于', style: sectionStyle),
          Card(
            child: ListTile(
              leading: const Icon(Icons.system_update_outlined),
              title: const Text('检查更新'),
              subtitle: FutureBuilder<String>(
                future: UpdateService().currentVersion(),
                builder: (ctx, snap) =>
                    Text('当前版本 v${snap.data ?? '…'}'),
              ),
              onTap: () => showCheckUpdateFlow(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 软件背景 ----------------

  Widget _buildBackgroundPicker(
      BuildContext context, WidgetRef ref, ReadConfig cfg) {
    final usingImage = cfg.appBgImage.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('软件背景'),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < appBgPresets.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _PresetDot(
                  color: Color(appBgPresets[i].color),
                  name: appBgPresets[i].name,
                  selected: !usingImage && cfg.appBgPreset == i,
                  onTap: () => ref
                      .read(readConfigProvider.notifier)
                      .update((c) => c.copyWith(
                          appBgPreset: i, appBgImage: '')),
                ),
              ),
            const SizedBox(width: 4),
            _ImageTile(
              imagePath: cfg.appBgImage,
              selected: usingImage,
              onTap: () => _pickBackgroundImage(context, ref),
            ),
          ],
        ),
        if (usingImage)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => ref
                  .read(readConfigProvider.notifier)
                  .update((c) => c.copyWith(appBgImage: '')),
              child: const Text('恢复默认背景'),
            ),
          ),
      ],
    );
  }

  /// 选择自定义背景图：拷贝到应用支持目录，避免 Android 临时缓存路径失效。
  Future<void> _pickBackgroundImage(
      BuildContext context, WidgetRef ref) async {
    try {
      // file_picker 12.x：静态方法，取消时返回空列表
      final result = await FilePicker.pickFiles(type: FileType.image);
      final src = result.isEmpty ? null : result.single.path;
      if (src == null) return;

      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'backgrounds'));
      await dir.create(recursive: true);
      final dest = p.join(
          dir.path, 'bg_${DateTime.now().millisecondsSinceEpoch}${p.extension(src)}');

      // 清理旧背景（仅限本应用拷贝的 backgrounds 目录内文件）
      final old = ref.read(readConfigProvider).appBgImage;
      if (old.isNotEmpty && p.canonicalize(old).startsWith(p.canonicalize(dir.path))) {
        try {
          await File(old).delete();
        } catch (_) {}
      }
      await File(src).copy(dest);

      ref.read(readConfigProvider.notifier).update((c) => c.copyWith(appBgImage: dest));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('背景图片设置失败：$e')));
      }
    }
  }
}

/// 预设背景色块
class _PresetDot extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _PresetDot({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                width: 2,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: selected
                ? Icon(Icons.check,
                    size: 20, color: Theme.of(context).colorScheme.primary)
                : null,
          ),
          const SizedBox(height: 4),
          Text(name, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 自定义图片背景入口（含当前图片预览）
class _ImageTile extends StatelessWidget {
  final String imagePath;
  final bool selected;
  final VoidCallback onTap;

  const _ImageTile({
    required this.imagePath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                width: 2,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: hasImage
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined, size: 18),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 20),
          ),
          const SizedBox(height: 4),
          Text('图片', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
