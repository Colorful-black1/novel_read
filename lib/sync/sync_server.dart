/// PC 端同步服务（shelf HTTP server）。
///
/// 只监听局域网请求，接口：
/// - GET  /api/ping  连通性探测
/// - POST /api/pair  配对码换 token（配对码一次性、限时）
/// - POST /api/sync  进度/设置双向合并（token 鉴权，LWW 冲突策略）
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../core/constants.dart';
import '../data/model/models.dart';
import '../data/repository/book_repository.dart';
import '../data/repository/sync_repository.dart';
import 'protocol.dart';

class SyncServer {
  final String Function() _generatePairCode;
  final ProgressRepository _progress;
  final SyncRepository _syncPairs;

  HttpServer? _server;
  String? _pairCode;
  DateTime _pairCodeExpires = DateTime.now();
  final String serverName;

  SyncServer({
    required String Function() generatePairCode,
    required ProgressRepository progress,
    required SyncRepository syncPairs,
    this.serverName = 'PC',
  })  : _generatePairCode = generatePairCode,
        _progress = progress,
        _syncPairs = syncPairs;

  bool get isRunning => _server != null;

  /// 当前有效配对码（过期自动视为无效）
  String? get currentPairCode =>
      DateTime.now().isBefore(_pairCodeExpires) ? _pairCode : null;

  /// 生成新配对码并启动服务。
  Future<void> start() async {
    if (isRunning) return;
    _pairCode = _generatePairCode();
    _pairCodeExpires =
        DateTime.now().add(const Duration(seconds: pairCodeTtlSeconds));

    final router = Router()
      ..get(SyncProtocol.apiPing, _handlePing)
      ..post(SyncProtocol.apiPair, _handlePair)
      ..post(SyncProtocol.apiSync, _handleSync);

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests(logger: (message, isError) {}))
        .addHandler(router.call);

    _server = await serveHandler(handler);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// 绑定监听（测试可覆写以注入临时端口）。
  Future<HttpServer> serveHandler(shelf.Handler handler) {
    return shelf_io.serve(handler, InternetAddress.anyIPv4, syncPort);
  }

  // ---------------- handlers ----------------

  Future<shelf.Response> _handlePing(shelf.Request request) async {
    return _json(PairResponse(
            token: '', serverName: serverName, serverTimeMs: _nowMs())
        .toJson());
  }

  Future<shelf.Response> _handlePair(shelf.Request request) async {
    try {
      final body = await _readJson(request);
      final req = PairRequest.fromJson(body);
      final code = currentPairCode;
      if (code == null || req.code != code) {
        return _json({'error': '配对码无效或已过期'}, status: 401);
      }
      // 配对码一次性：用后即焚
      _pairCode = null;
      _pairCodeExpires = DateTime.now();

      final existing = await _syncPairs.findPairByDeviceId(req.deviceId);
      final token = existing?.token ?? _newToken();
      await _syncPairs.upsertPair(SyncPair(
        id: existing?.id ?? 0,
        deviceId: req.deviceId,
        deviceName: req.deviceName,
        token: token,
        host: '',
        port: 0,
        lastSyncAtMs: 0,
      ));
      return _json(PairResponse(
        token: token,
        serverName: serverName,
        serverTimeMs: _nowMs(),
      ).toJson());
    } catch (e) {
      return _json({'error': '配对失败：$e'}, status: 400);
    }
  }

  Future<shelf.Response> _handleSync(shelf.Request request) async {
    final token = request.headers['authorization']?.replaceFirst('Bearer ', '');
    if (token == null || token.isEmpty) {
      return _json({'error': '未授权'}, status: 401);
    }
    final pair = await _syncPairs.findPairByToken(token);
    if (pair == null) {
      return _json({'error': 'token 无效'}, status: 401);
    }
    try {
      final req = SyncRequest.fromJson(await _readJson(request));

      // 1) 合并客户端上行进度（LWW + 冲突快照）
      final remote = req.progresses.map(ReadingProgress.fromSyncJson).toList();
      final snapshotKeys = await _progress.mergeRemote(remote);

      // 2) 返回合并后的全量进度供客户端下行合并
      final all = await _progress.listAll();
      await _syncPairs.updatePairSyncTime(pair.deviceId, _nowMs());
      await _syncPairs.addLog('merge',
          '与 ${pair.deviceName} 同步：上行 ${remote.length} 条，'
          '覆盖冲突 ${snapshotKeys.length} 条');

      return _json(SyncResponse(
        progresses: all.map((p) => p.toSyncJson()).toList(),
        serverTimeMs: _nowMs(),
      ).toJson());
    } catch (e) {
      return _json({'error': '同步失败：$e'}, status: 400);
    }
  }

  // ---------------- utils ----------------

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static String _newToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return 'tk_${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  static Future<Map<String, Object?>> _readJson(shelf.Request request) async {
    final text = await request.readAsString();
    return Map<String, Object?>.from(jsonDecode(text) as Map);
  }

  shelf.Response _json(Object? data, {int status = 200}) {
    return shelf.Response(status,
        body: jsonEncode(data),
        headers: {'content-type': 'application/json; charset=utf-8'});
  }
}

/// 常见虚拟网卡/VPN 适配器关键字（二维码编入这些地址手机连不上）
const _virtualAdapterKeywords = [
  'vmware', 'vmnet', 'virtualbox', 'vethernet', 'hyper-v', 'wsl',
  'docker', 'tailscale', 'zerotier', 'openvpn', 'wireguard', 'bluetooth',
  'loopback', 'tap-', 'tun-',
];

/// 是否为常见私有局域网段（192.168 / 10 / 172.16-31）
bool _isPrivateLan(String ip) {
  if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
  if (ip.startsWith('172.')) {
    final second = int.tryParse(ip.split('.').length > 1 ? ip.split('.')[1] : '') ?? 0;
    return second >= 16 && second <= 31;
  }
  return false;
}

/// 获取本机局域网 IPv4 地址列表。
///
/// 过滤虚拟网卡与链路本地地址（169.254.*），真实局域网段排前面，
/// 保证 `_addresses.first` 大概率是手机可达的地址。
Future<List<String>> localIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(includeLoopback: false);
  final preferred = <String>[];
  final others = <String>[];
  for (final itf in interfaces) {
    final name = itf.name.toLowerCase();
    final isVirtual =
        _virtualAdapterKeywords.any((k) => name.contains(k));
    for (final addr in itf.addresses) {
      if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) continue;
      if (addr.address.startsWith('169.254.')) continue; // 链路本地无效
      if (!isVirtual && _isPrivateLan(addr.address)) {
        preferred.add(addr.address);
      } else {
        others.add(addr.address);
      }
    }
  }
  return [...preferred, ...others];
}
