/// 同步页：PC 端开启服务并展示二维码，手机端扫码配对与一键同步。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants.dart';
import '../../logic/providers.dart';
import '../../sync/protocol.dart';
import '../../sync/sync_client.dart';
import '../../sync/sync_server.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SyncPage extends ConsumerStatefulWidget {
  const SyncPage({super.key});

  @override
  ConsumerState<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends ConsumerState<SyncPage> {
  SyncServer? _server;
  List<String> _addresses = [];
  String? _selectedAddress;
  String? _pairCode;
  bool _starting = false;

  SyncClient? _client;
  bool _syncing = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      SyncClient.load().then((c) {
        if (mounted && c != null) setState(() => _client = c);
      });
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  // ---------------- PC 服务端 ----------------

  Future<void> _startServer() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final server = SyncServer(
        generatePairCode: _generateCode,
        progress: ref.read(progressRepositoryProvider),
        syncPairs: ref.read(syncRepositoryProvider),
        serverName: Platform.localHostname,
      );
      await server.start();
      final addresses = await localIpv4Addresses();
      if (!mounted) return;
      setState(() {
        _server = server;
        _addresses = addresses;
        _selectedAddress = addresses.isNotEmpty ? addresses.first : null;
        _pairCode = server.currentPairCode;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('服务启动失败：$e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stopServer() async {
    await _server?.stop();
    if (!mounted) return;
    setState(() {
      _server = null;
      _pairCode = null;
    });
  }

  static String _generateCode() {
    final rnd = Random.secure();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  // ---------------- 手机客户端 ----------------

  Future<void> _pairWith(String host, int port, String code) async {
    try {
      final client = SyncClient(
        host: host,
        port: port,
        deviceId: Platform.localHostname,
        deviceName: Platform.isAndroid ? 'Android 手机' : Platform.localHostname,
      );
      final resp = await client.pair(code);
      if (!mounted) return;
      setState(() {
        _client = client;
        _lastMessage = '配对成功：${resp.serverName}';
      });
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('连接超时：请确认手机与电脑在同一局域网，'
              '且电脑防火墙允许 9876 端口；也可改用「手动输入」填写电脑 IP')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('配对失败：$e')));
    }
  }

  void _showScanner() {
    showModalBottomSheet<String>(
      context: context,
      builder: (_) => const _ScannerSheet(),
    ).then((raw) {
      if (!mounted) return;
      if (raw == null || raw.isEmpty) return;
      final content = PairQrContent.tryParse(raw);
      if (content == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('二维码不是静读配对码')));
        return;
      }
      _pairWith(content.host, content.port, content.code);
    });
  }

  void _manualPair() {
    final hostCtrl = TextEditingController(text: _client?.host ?? '');
    final portCtrl =
        TextEditingController(text: (_client?.port ?? syncPort).toString());
    final codeCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动配对'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hostCtrl,
              decoration: const InputDecoration(labelText: '电脑 IP 地址'),
            ),
            TextField(
              controller: portCtrl,
              decoration:
                  const InputDecoration(labelText: '端口（默认 $syncPort）'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(labelText: '6 位配对码'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final host = hostCtrl.text.trim();
              final port = int.tryParse(portCtrl.text.trim()) ?? 0;
              final code = codeCtrl.text.trim();
              Navigator.pop(ctx);
              if (host.isEmpty || port <= 0 || code.isEmpty) return;
              _pairWith(host, port, code);
            },
            child: const Text('配对'),
          ),
        ],
      ),
    );
  }

  Future<void> _doSync() async {
    final client = _client;
    if (client == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final savedCfg = ref.read(readConfigProvider);
      final resp = await client.syncAll(
        localProgress: await ref.read(progressRepositoryProvider).listAll(),
        localConfig: savedCfg,
        savedRemoteConfig: null,
        mergeRemote: (remote) =>
            ref.read(progressRepositoryProvider).mergeRemote(remote),
        applySettings: (remote) async {
          ref.read(readConfigProvider.notifier).update((_) => remote);
        },
      );
      ref.invalidate(bookListProvider);
      if (!mounted) return;
      setState(() {
        _lastMessage =
            '同步完成：共 ${resp.progresses.length} 条进度（${DateTime.now().toLocal()}）';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('同步失败：$e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ---------------- 构建 ----------------

  @override
  Widget build(BuildContext context) {
    final isPc = Platform.isWindows;
    return Scaffold(
      appBar: AppBar(title: const Text('同步')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isPc) _buildServerSection() else _buildClientSection(),
          const SizedBox(height: 24),
          if (_lastMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_lastMessage!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServerSection() {
    final running = _server != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('电脑端同步服务',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                FilledButton(
                  onPressed:
                      _starting ? null : (running ? _stopServer : _startServer),
                  child: Text(_starting
                      ? '启动中…'
                      : running
                          ? '停止服务'
                          : '开启服务'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!running)
              const Text('开启后，手机在同一局域网内扫码即可配对并同步阅读进度。')
            else ...[
              Text('本机地址：${_addresses.join('  /  ')}'),
              // 多网卡时允许手动选择编入二维码的地址
              if (_addresses.length > 1)
                DropdownButton<String>(
                  value: _selectedAddress,
                  isExpanded: true,
                  hint: const Text('选择编入二维码的地址'),
                  items: [
                    for (final a in _addresses)
                      DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) => setState(() => _selectedAddress = v),
                ),
              const SizedBox(height: 12),
              if (_selectedAddress != null && _pairCode != null)
                Center(
                  child: Column(
                    children: [
                      QrImageView(
                        data: PairQrContent(
                          host: _selectedAddress!,
                          port: syncPort,
                          code: _pairCode!,
                        ).encode(),
                        size: 200,
                      ),
                      const SizedBox(height: 8),
                      Text('配对码：$_pairCode（5 分钟内有效，仅可使用一次）'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientSection() {
    final client = _client;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('手机端同步',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (client == null)
              const Text('先与电脑配对：电脑端打开「同步」页并开启服务，然后扫码。')
            else
              Text('已配对：${client.host}:${client.port}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _showScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('扫码配对'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _manualPair,
                    icon: const Icon(Icons.edit),
                    label: const Text('手动输入'),
                  ),
                ),
              ],
            ),
            if (client != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _syncing ? null : _doSync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: Text(_syncing ? '同步中…' : '立即同步'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 扫码浮层，返回二维码原始内容。
class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('扫描电脑端二维码',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    Navigator.pop(context, raw);
                    return;
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
