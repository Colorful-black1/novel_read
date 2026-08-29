/// 手机端同步客户端：扫码配对、进度上下行。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/models.dart';
import '../logic/read_config.dart';
import 'protocol.dart';

class SyncClient {
  String host;
  int port;
  String? token;
  final String deviceId;
  final String deviceName;

  SyncClient({
    required this.host,
    required this.port,
    required this.deviceId,
    required this.deviceName,
    this.token,
  });

  String get baseUrl => 'http://$host:$port';

  // ---------------- 配对 ----------------

  /// 用配对码向 PC 换取 token。
  Future<PairResponse> pair(String code) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl${SyncProtocol.apiPair}'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(PairRequest(
                  code: code, deviceName: deviceName, deviceId: deviceId)
              .toJson()),
        )
        .timeout(const Duration(seconds: 5));
    final map = _decode(resp);
    if (resp.statusCode != 200) {
      throw SyncException(map['error']?.toString() ?? '配对失败');
    }
    final result = PairResponse.fromJson(map);
    token = result.token;
    await _savePairState();
    return result;
  }

  /// 同步：上行本地进度与设置，下行合并服务端数据。
  ///
  /// [mergeRemote] 由调用方注入（ProgressRepository.mergeRemote），
  /// [applySettings] 将下行设置写回本地。
  Future<SyncResponse> syncAll({
    required List<ReadingProgress> localProgress,
    required ReadConfig localConfig,
    required ReadConfig? savedRemoteConfig,
    required Future<List<String>> Function(List<ReadingProgress>) mergeRemote,
    required Future<void> Function(ReadConfig remote) applySettings,
  }) async {
    if (token == null) throw SyncException('尚未配对');
    final resp = await http
        .post(
          Uri.parse('$baseUrl${SyncProtocol.apiSync}'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $token',
          },
          body: jsonEncode(SyncRequest(
            deviceId: deviceId,
            progresses: localProgress.map((p) => p.toSyncJson()).toList(),
            settings: _settingsPayload(localConfig, savedRemoteConfig),
          ).toJson()),
        )
        .timeout(const Duration(seconds: 15));
    final map = _decode(resp);
    if (resp.statusCode != 200) {
      throw SyncException(map['error']?.toString() ?? '同步失败');
    }
    final result = SyncResponse.fromJson(map);
    await mergeRemote(
        result.progresses.map(ReadingProgress.fromSyncJson).toList());
    if (result.settings != null) {
      await applySettings(ReadConfig.fromMap(result.settings!));
    }
    return result;
  }

  /// 上行设置只在本地比远端新时才携带（LWW）。
  Map<String, Object?>? _settingsPayload(
      ReadConfig local, ReadConfig? savedRemote) {
    // 简化策略：始终携带本地设置，由 PC 端按 updatedAt 决定；
    // MVP 中设置合并粒度为整体覆盖。
    return local.toMap();
  }

  // ---------------- 持久化配对信息 ----------------

  static const _prefPrefix = 'sync_client_';

  Future<void> _savePairState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_prefPrefix}host', host);
    await prefs.setInt('${_prefPrefix}port', port);
    await prefs.setString('${_prefPrefix}token', token ?? '');
    await prefs.setString('${_prefPrefix}deviceId', deviceId);
    await prefs.setString('${_prefPrefix}deviceName', deviceName);
  }

  static Future<SyncClient?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('${_prefPrefix}token');
    final host = prefs.getString('${_prefPrefix}host');
    final port = prefs.getInt('${_prefPrefix}port');
    final deviceId = prefs.getString('${_prefPrefix}deviceId');
    final deviceName = prefs.getString('${_prefPrefix}deviceName');
    if (token == null || token.isEmpty || host == null || port == null ||
        deviceId == null) {
      return null;
    }
    return SyncClient(
      host: host,
      port: port,
      token: token,
      deviceId: deviceId,
      deviceName: deviceName ?? '',
    );
  }

  static Map<String, Object?> _decode(http.Response resp) {
    try {
      return Map<String, Object?>.from(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map);
    } catch (_) {
      return {'error': '响应解析失败（HTTP ${resp.statusCode}）'};
    }
  }
}

class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => message;
}
