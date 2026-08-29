/// 局域网同步协议定义。
///
/// 端点：
/// - POST /api/pair        首次配对（配对码换 token）
/// - POST /api/sync        进度/设置双向同步（token 鉴权）
/// - GET  /api/ping        连通性探测
library;

class SyncProtocol {
  static const apiPair = '/api/pair';
  static const apiSync = '/api/sync';
  static const apiPing = '/api/ping';
}

/// 配对请求体
class PairRequest {
  final String code;
  final String deviceName;
  final String deviceId;

  PairRequest({
    required this.code,
    required this.deviceName,
    required this.deviceId,
  });

  Map<String, Object?> toJson() =>
      {'code': code, 'deviceName': deviceName, 'deviceId': deviceId};

  static PairRequest fromJson(Map<String, Object?> json) => PairRequest(
        code: json['code'] as String,
        deviceName: (json['deviceName'] as String?) ?? '',
        deviceId: (json['deviceId'] as String?) ?? '',
      );
}

/// 配对响应体
class PairResponse {
  final String token;
  final String serverName;
  final int serverTimeMs;

  PairResponse({
    required this.token,
    required this.serverName,
    required this.serverTimeMs,
  });

  Map<String, Object?> toJson() =>
      {'token': token, 'serverName': serverName, 'serverTime': serverTimeMs};

  static PairResponse fromJson(Map<String, Object?> json) => PairResponse(
        token: json['token'] as String,
        serverName: (json['serverName'] as String?) ?? '',
        serverTimeMs: (json['serverTime'] as num?)?.toInt() ?? 0,
      );
}

/// 同步请求体：客户端携带本地全部进度与设置
class SyncRequest {
  final String deviceId;
  final List<Map<String, Object?>> progresses;
  final Map<String, Object?>? settings;

  SyncRequest({
    required this.deviceId,
    required this.progresses,
    this.settings,
  });

  Map<String, Object?> toJson() => {
        'deviceId': deviceId,
        'progresses': progresses,
        if (settings != null) 'settings': settings,
      };

  static SyncRequest fromJson(Map<String, Object?> json) => SyncRequest(
        deviceId: (json['deviceId'] as String?) ?? '',
        progresses: ((json['progresses'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, Object?>.from(e))
            .toList(),
        settings: json['settings'] == null
            ? null
            : Map<String, Object?>.from(json['settings'] as Map),
      );
}

/// 同步响应体：服务端合并后的全量进度与设置
class SyncResponse {
  final List<Map<String, Object?>> progresses;
  final Map<String, Object?>? settings;
  final int serverTimeMs;

  SyncResponse({
    required this.progresses,
    this.settings,
    required this.serverTimeMs,
  });

  Map<String, Object?> toJson() => {
        'progresses': progresses,
        if (settings != null) 'settings': settings,
        'serverTime': serverTimeMs,
      };

  static SyncResponse fromJson(Map<String, Object?> json) => SyncResponse(
        progresses: ((json['progresses'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, Object?>.from(e))
            .toList(),
        settings: json['settings'] == null
            ? null
            : Map<String, Object?>.from(json['settings'] as Map),
        serverTimeMs: (json['serverTime'] as num?)?.toInt() ?? 0,
      );
}

/// 二维码内容
class PairQrContent {
  final String host;
  final int port;
  final String code;

  const PairQrContent({
    required this.host,
    required this.port,
    required this.code,
  });

  String encode() => 'novelread://pair?host=$host&port=$port&code=$code';

  static PairQrContent? tryParse(String raw) {
    if (!raw.startsWith('novelread://pair?')) return null;
    final query = Uri.parse(raw).queryParameters;
    final host = query['host'];
    final port = int.tryParse(query['port'] ?? '');
    final code = query['code'];
    if (host == null || host.isEmpty || port == null || code == null) {
      return null;
    }
    return PairQrContent(host: host, port: port, code: code);
  }
}
