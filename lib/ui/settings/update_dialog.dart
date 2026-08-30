/// 检查更新流程与新版本下载弹窗。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/update_service.dart';

/// 检查更新入口：检查中弹提示，完成按结果分流（已是最新 / 新版本弹窗 / 失败提示）。
Future<void> showCheckUpdateFlow(BuildContext context) async {
  final service = UpdateService();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('正在检查更新…'),
        ],
      ),
    ),
  );
  try {
    final info = await service.checkUpdate();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (info == null) {
      final version = await service.currentVersion();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版本（v$version）')));
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => UpdateDialog(info: info),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('检查更新失败：$e')));
  }
}

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  /// 下载进度 0~1，null 表示未在下载
  double? _progress;

  /// 下载完成后刷新本页状态，避免监听后再次进入
  String? _downloadedPath;
  String? _error;
  bool _installing = false;

  UpdateService get _service => _serviceInstance ??= UpdateService();
  UpdateService? _serviceInstance;

  bool get _isAndroid => Platform.isAndroid;

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final path = await _service.download(
        widget.info.assetUrl,
        widget.info.assetName,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() => _progress = received / total);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadedPath = path;
        _progress = null;
      });
      // Android 下载完成后直接拉起安装器
      if (_isAndroid) await _install();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _progress = null;
      });
    }
  }

  Future<void> _install() async {
    final path = _downloadedPath;
    if (path == null) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await _service.install(path);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _installing = false;
      });
    }
  }

  String _sizeLabel() {
    final size = widget.info.assetSize;
    if (size <= 0) return '';
    return size < 1024 * 1024
        ? '${(size / 1024).toStringAsFixed(0)} KB'
        : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AlertDialog(
      title: Text('发现新版本 ${info.tagName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<String>(
              future: _serviceInstance?.currentVersion() ??
                  _service.currentVersion(),
              builder: (ctx, snap) => Text('当前版本 v${snap.data ?? '…'}'),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes.isEmpty ? '（无更新说明）' : info.releaseNotes,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (_progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 4),
              Text('下载中 ${((_progress ?? 0) * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text('出错了：$_error',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _progress == null && !_installing
              ? () => Navigator.of(context).pop()
              : null,
          child: const Text('稍后'),
        ),
        if (_downloadedPath == null)
          FilledButton(
            onPressed: _progress == null ? _download : null,
            child: Text(_progress != null
                ? '下载中…'
                : '下载安装包${_sizeLabel().isEmpty ? '' : '（${_sizeLabel()}）'}'),
          )
        else
          FilledButton(
            onPressed: _installing ? null : _install,
            child: Text(_installing
                ? '正在启动…'
                : _isAndroid
                    ? '立即安装'
                    : '打开所在文件夹'),
          ),
      ],
    );
  }
}
