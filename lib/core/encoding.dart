/// 文本编码探测与解码工具。
///
/// 优先级：BOM 声明 > UTF-8 严格解码 > GBK 回退。
/// 覆盖常见中文 TXT 场景（UTF-8 / UTF-8 BOM / GBK / UTF-16）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

class EncodingDetector {
  EncodingDetector._();

  /// 读取整个文件并解码为字符串。
  static Future<String> decodeFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeBytes(bytes);
  }

  /// 仅读取文件头部字节（用于计算书籍识别哈希）。
  static Future<Uint8List> readHead(String path, int count) async {
    final raf = await File(path).open();
    try {
      return await raf.read(count);
    } finally {
      await raf.close();
    }
  }

  /// 将字节解码为字符串。
  static String decodeBytes(List<int> bytes) {
    // UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    // UTF-16 LE / BE BOM
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
            (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
      return _decodeUtf16(bytes);
    }
    // 无 BOM：先尝试严格 UTF-8，失败按 GBK 处理
    try {
      return utf8.decode(bytes);
    } on FormatException {
      try {
        return gbk.decode(bytes);
      } catch (_) {
        // 最后兜底：容忍非法字节的 UTF-8 解码，避免崩溃
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  static String _decodeUtf16(List<int> bytes) {
    final bom = (bytes[0] == 0xFF) ? Endian.little : Endian.big;
    final body = bytes.sublist(2);
    final buffer = StringBuffer();
    for (var i = 0; i + 1 < body.length; i += 2) {
      final unit = bom == Endian.little
          ? body[i] | (body[i + 1] << 8)
          : (body[i] << 8) | body[i + 1];
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }
}
