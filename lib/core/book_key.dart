/// 书籍唯一标识（bookKey）计算。
///
/// 同一本书在手机与 PC 上各自导入后应得到相同 bookKey，
/// 作为局域网同步时进度匹配的依据。
library;

import 'package:crypto/crypto.dart';

class BookKey {
  BookKey._();

  /// 计算书籍标识：md5(书名 | 文件大小 | 内容头部取样哈希)。
  ///
  /// [headBytes] 为文件头部取样字节，取样长度由常量 [bookKeySampleBytes] 控制，
  /// 避免对超大文件整体读取。
  static String compute({
    required String title,
    required int fileSize,
    required List<int> headBytes,
  }) {
    final digest = md5.convert([
      ...title.codeUnits,
      ...'|$fileSize|'.codeUnits,
      ...headBytes,
    ]);
    return digest.toString();
  }
}
