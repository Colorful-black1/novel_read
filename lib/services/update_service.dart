/// GitHub Release 更新检查、安装包下载与升级触发。
///
/// 发布约定（owner/repo 见 [kUpdateRepoSlug]）：
/// - Release tag 形如 `v0.2.0`（可带 v 前缀，与 pubspec 版本号对应）；
/// - Android 资产为 `.apk` 文件，Windows 资产为 `.zip` 文件（Release 目录压缩包）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// GitHub 仓库（owner/repo）
const String kUpdateRepoSlug = 'Colorful-black1/novel_read';

/// 新版本信息
class UpdateInfo {
  /// 不带 v 前缀的版本号，如 `0.3.0`
  final String version;

  /// 原始 tag 名
  final String tagName;

  /// Release 说明（Markdown 纯文本展示）
  final String releaseNotes;

  final String assetUrl;
  final String assetName;
  final int assetSize;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseNotes,
    required this.assetUrl,
    required this.assetName,
    required this.assetSize,
  });
}

class UpdateService {
  static const _apiBase = 'https://api.github.com';

  final http.Client _client;

  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  /// 当前应用版本号（来自 pubspec，构建时注入）
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return normalizeVersion(info.version);
  }

  /// 检查更新。返回 null 表示已是最新；无网络 / 无 Release / 无资产时抛异常。
  Future<UpdateInfo?> checkUpdate() async {
    final resp = await _client
        .get(
          Uri.parse('$_apiBase/repos/$kUpdateRepoSlug/releases/latest'),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 404) {
      throw Exception('仓库还没有发布过 Release');
    }
    if (resp.statusCode != 200) {
      throw Exception('GitHub 返回 ${resp.statusCode}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final current = await currentVersion();
    final tagName = (json['tag_name'] as String?) ?? '';
    final latest = normalizeVersion(tagName);
    if (compareVersions(latest, current) <= 0) return null;

    // 按平台选择安装包资产
    final suffix = Platform.isAndroid ? '.apk' : '.zip';
    String? url;
    String? name;
    var size = 0;
    for (final asset in (json['assets'] as List? ?? const [])) {
      final map = asset as Map<String, dynamic>;
      final assetName = (map['name'] as String?) ?? '';
      if (assetName.toLowerCase().endsWith(suffix)) {
        url = (map['browser_download_url'] as String?) ?? '';
        name = assetName;
        size = (map['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }
    if (url == null || url.isEmpty) {
      throw Exception(
          '最新 Release（$tagName）没有 $suffix 安装包资产，请联系发布者补传');
    }
    return UpdateInfo(
      version: latest,
      tagName: tagName,
      releaseNotes: (json['body'] as String?) ?? '',
      assetUrl: url,
      assetName: name!,
      assetSize: size,
    );
  }

  /// 下载安装包，返回保存路径。
  /// Android 存临时目录（仅用于拉起安装器），Windows 存系统「下载」目录便于留存。
  Future<String> download(
    String url,
    String fileName, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = Platform.isAndroid
        ? await getTemporaryDirectory()
        : (await getDownloadsDirectory() ??
            await getApplicationSupportDirectory());
    final savePath = p.join(dir.path, fileName);
    final resp = await _client.send(http.Request('GET', Uri.parse(url)));
    if (resp.statusCode != 200) {
      throw Exception('下载失败：HTTP ${resp.statusCode}');
    }
    final total = resp.contentLength ?? 0;
    var received = 0;
    final sink = File(savePath).openWrite();
    try {
      await for (final chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (total > 0 && received < total) {
      throw Exception('下载不完整：$received / $total 字节');
    }
    return savePath;
  }

  /// 触发升级：
  /// - Android：拉起系统包安装器（需用户授予「安装未知应用」权限）；
  /// - Windows：资源管理器定位到下载的文件（运行中的 exe 无法自我替换，
  ///   由用户解压新包手动覆盖）。
  Future<void> install(String filePath) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(filePath,
          type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        throw Exception('无法启动安装器：${result.message}');
      }
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', p.normalize(filePath)]);
    }
  }

  /// 版本比较：a < b 返回 -1，相等返回 0，a > b 返回 1。
  /// 兼容 `v0.2.1` / `0.2.1` / `0.2.1+2` 等写法，缺失的段按 0 处理。
  static int compareVersions(String a, String b) {
    final pa = _versionParts(a);
    final pb = _versionParts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static List<int> _versionParts(String v) => normalizeVersion(v)
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();

  /// 去掉 v/V 前缀与 `+build` 构建号后缀
  static String normalizeVersion(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    return s;
  }
}
