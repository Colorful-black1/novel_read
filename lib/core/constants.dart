/// 全局常量定义。
library;

import 'package:flutter/material.dart';

/// 应用名称
const String appName = '静读';

/// 同步服务默认端口
const int syncPort = 9876;

/// 同步配对码有效期（秒）
const int pairCodeTtlSeconds = 300;

/// 无章节书籍的分卷大小（字符数），作为伪章节切分依据
const int pseudoChapterSize = 50000;

/// 书籍识别哈希取样的头部字节数
const int bookKeySampleBytes = 64 * 1024;

/// 阅读背景主题定义
class ReaderTheme {
  final String name;
  final int background;
  final int foreground;

  const ReaderTheme(this.name, this.background, this.foreground);
}

/// 内置阅读背景：纸白 / 米黄 / 护眼绿 / 羊皮纸 / 夜黑
const List<ReaderTheme> readerThemes = [
  ReaderTheme('纸白', 0xFFF7F7F5, 0xFF2B2B2B),
  ReaderTheme('米黄', 0xFFF5EFDC, 0xFF3B3226),
  ReaderTheme('护眼绿', 0xFFCCE8CF, 0xFF243326),
  ReaderTheme('羊皮纸', 0xFFE8DCC0, 0xFF4A3B2A),
  ReaderTheme('夜黑', 0xFF121212, 0xFFB8B8B8),
];

/// 夜间模式背景与前景
const Color nightBackground = Color(0xFF121212);
const Color nightForeground = Color(0xFF9E9E9E);

/// 阅读排版内边距
const EdgeInsets readerPadding = EdgeInsets.fromLTRB(20, 44, 20, 44);

/// 软件背景预设（index 对应 ReadConfig.appBgPreset，只能往后追加）
class AppBgPreset {
  final String name;
  final int color;
  final bool dark; // 是否套用暗色主题

  const AppBgPreset(this.name, this.color, this.dark);
}

/// 内置软件背景：白 / 灰 / 黑
const List<AppBgPreset> appBgPresets = [
  AppBgPreset('白', 0xFFFFFFFF, false),
  AppBgPreset('灰', 0xFFF2F3F5, false),
  AppBgPreset('黑', 0xFF121212, true),
];
