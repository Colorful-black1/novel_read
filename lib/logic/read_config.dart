/// 阅读设置（字号 / 行距 / 字体 / 背景 / 翻页模式 / 夜间模式 / 亮度）。
///
/// 通过 SharedPreferences 持久化，并参与局域网同步。
library;

import 'dart:convert';

/// 翻页模式
///
/// 注意：枚举按 index 序列化，只能往后追加，不能调整已有顺序。
enum PageMode { scroll, horizontal, cover }

class ReadConfig {
  final double fontSize;
  final double lineSpacing; // 行距倍数
  final String fontFamily; // 系统字体名，空串表示默认
  final int themeIndex;
  final bool nightMode;
  final PageMode pageMode;
  final double brightnessMask; // 0~0.6 亮度遮罩透明度
  final bool disguiseEnabled; // PC：老板键切换到伪装皮肤
  final bool blurOnFocusLost; // PC：失焦自动最小化
  final String bossHotkey; // PC：老板键组合，如 'Alt+H'
  final bool pinned; // PC：窗口钉住置顶（置顶时老板键失效）

  /// 软件背景预设索引：0 白 / 1 灰 / 2 黑
  final int appBgPreset;

  /// 软件自定义背景图片路径，非空时优先于预设
  final String appBgImage;

  const ReadConfig({
    this.fontSize = 19,
    this.lineSpacing = 1.6,
    this.fontFamily = '',
    this.themeIndex = 1,
    this.nightMode = false,
    this.pageMode = PageMode.scroll,
    this.brightnessMask = 0,
    this.disguiseEnabled = true,
    this.blurOnFocusLost = true,
    this.bossHotkey = 'Alt+H',
    this.pinned = false,
    this.appBgPreset = 0,
    this.appBgImage = '',
  });

  double get effectiveLineHeight => fontSize * lineSpacing;

  ReadConfig copyWith({
    double? fontSize,
    double? lineSpacing,
    String? fontFamily,
    int? themeIndex,
    bool? nightMode,
    PageMode? pageMode,
    double? brightnessMask,
    bool? disguiseEnabled,
    bool? blurOnFocusLost,
    String? bossHotkey,
    bool? pinned,
    int? appBgPreset,
    String? appBgImage,
  }) {
    return ReadConfig(
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      themeIndex: themeIndex ?? this.themeIndex,
      nightMode: nightMode ?? this.nightMode,
      pageMode: pageMode ?? this.pageMode,
      brightnessMask: brightnessMask ?? this.brightnessMask,
      disguiseEnabled: disguiseEnabled ?? this.disguiseEnabled,
      blurOnFocusLost: blurOnFocusLost ?? this.blurOnFocusLost,
      bossHotkey: bossHotkey ?? this.bossHotkey,
      pinned: pinned ?? this.pinned,
      appBgPreset: appBgPreset ?? this.appBgPreset,
      appBgImage: appBgImage ?? this.appBgImage,
    );
  }

  Map<String, Object?> toMap() => {
        'fontSize': fontSize,
        'lineSpacing': lineSpacing,
        'fontFamily': fontFamily,
        'themeIndex': themeIndex,
        'nightMode': nightMode,
        'pageMode': pageMode.index,
        'brightnessMask': brightnessMask,
        'disguiseEnabled': disguiseEnabled,
        'blurOnFocusLost': blurOnFocusLost,
        'bossHotkey': bossHotkey,
        'pinned': pinned,
        'appBgPreset': appBgPreset,
        'appBgImage': appBgImage,
      };

  static ReadConfig fromMap(Map<String, Object?> map) => ReadConfig(
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 19,
        lineSpacing: (map['lineSpacing'] as num?)?.toDouble() ?? 1.6,
        fontFamily: (map['fontFamily'] as String?) ?? '',
        themeIndex: (map['themeIndex'] as num?)?.toInt() ?? 1,
        nightMode: (map['nightMode'] as bool?) ?? false,
        pageMode: PageMode.values[(map['pageMode'] as num?)?.toInt() ?? 0],
        brightnessMask: (map['brightnessMask'] as num?)?.toDouble() ?? 0,
        disguiseEnabled: (map['disguiseEnabled'] as bool?) ?? true,
        blurOnFocusLost: (map['blurOnFocusLost'] as bool?) ?? true,
        bossHotkey: (map['bossHotkey'] as String?) ?? 'Alt+H',
        pinned: (map['pinned'] as bool?) ?? false,
        appBgPreset: (map['appBgPreset'] as num?)?.toInt() ?? 0,
        appBgImage: (map['appBgImage'] as String?) ?? '',
      );

  String toJson() => jsonEncode(toMap());

  static ReadConfig fromJson(String json) =>
      fromMap(Map<String, Object?>.from(jsonDecode(json) as Map));
}
