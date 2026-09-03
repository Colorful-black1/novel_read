/// 阅读设置（字号 / 行距 / 字体 / 背景 / 翻页模式 / 夜间模式 / 亮度）。
///
/// 通过 SharedPreferences 持久化，并参与局域网同步。
library;

import 'dart:convert';

/// 翻页模式
///
/// 注意：枚举按 index 序列化，只能往后追加，不能调整已有顺序。
enum PageMode { scroll, horizontal, cover }

/// 书架排序模式
///
/// 注意：枚举按 index 序列化，只能往后追加，不能调整已有顺序。
enum BookshelfSort { manual, recentRead, addedTime, title }

/// 老板键伪装对象
///
/// 注意：枚举按 index 序列化，只能往后追加，不能调整已有顺序。
/// [none] 表示不伪装，老板键直接隐藏/恢复窗口。
enum DisguiseTarget { none, excel, word }

class ReadConfig {
  final double fontSize;
  final double lineSpacing; // 行距倍数
  final String fontFamily; // 系统字体名，空串表示默认
  final int themeIndex;
  final bool nightMode;
  final PageMode pageMode;
  final double brightnessMask; // 0~0.6 亮度遮罩透明度
  final DisguiseTarget disguiseTarget; // PC：老板键伪装对象（none=直接隐藏）
  final bool blurOnFocusLost; // PC：失焦自动最小化
  final String bossHotkey; // PC：老板键组合，如 'Alt+H'
  final bool pinned; // PC：窗口钉住置顶（置顶时老板键失效）
  final BookshelfSort bookshelfSort; // 书架排序模式

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
    this.disguiseTarget = DisguiseTarget.none,
    this.blurOnFocusLost = true,
    this.bossHotkey = 'Alt+H',
    this.pinned = false,
    this.appBgPreset = 0,
    this.appBgImage = '',
    this.bookshelfSort = BookshelfSort.manual,
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
    DisguiseTarget? disguiseTarget,
    bool? blurOnFocusLost,
    String? bossHotkey,
    bool? pinned,
    int? appBgPreset,
    String? appBgImage,
    BookshelfSort? bookshelfSort,
  }) {
    return ReadConfig(
      fontSize: fontSize ?? this.fontSize,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      fontFamily: fontFamily ?? this.fontFamily,
      themeIndex: themeIndex ?? this.themeIndex,
      nightMode: nightMode ?? this.nightMode,
      pageMode: pageMode ?? this.pageMode,
      brightnessMask: brightnessMask ?? this.brightnessMask,
      disguiseTarget: disguiseTarget ?? this.disguiseTarget,
      blurOnFocusLost: blurOnFocusLost ?? this.blurOnFocusLost,
      bossHotkey: bossHotkey ?? this.bossHotkey,
      pinned: pinned ?? this.pinned,
      appBgPreset: appBgPreset ?? this.appBgPreset,
      appBgImage: appBgImage ?? this.appBgImage,
      bookshelfSort: bookshelfSort ?? this.bookshelfSort,
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
         'disguiseTarget': disguiseTarget.index,
         'blurOnFocusLost': blurOnFocusLost,
         'bossHotkey': bossHotkey,
        'pinned': pinned,
        'appBgPreset': appBgPreset,
        'appBgImage': appBgImage,
        'bookshelfSort': bookshelfSort.index,
      };

  static ReadConfig fromMap(Map<String, Object?> map) => ReadConfig(
        fontSize: (map['fontSize'] as num?)?.toDouble() ?? 19,
        lineSpacing: (map['lineSpacing'] as num?)?.toDouble() ?? 1.6,
        fontFamily: (map['fontFamily'] as String?) ?? '',
        themeIndex: (map['themeIndex'] as num?)?.toInt() ?? 1,
        nightMode: (map['nightMode'] as bool?) ?? false,
        pageMode: PageMode.values[(map['pageMode'] as num?)?.toInt() ?? 0],
        brightnessMask: (map['brightnessMask'] as num?)?.toDouble() ?? 0,
        disguiseTarget: _parseDisguiseTarget(map),
        blurOnFocusLost: (map['blurOnFocusLost'] as bool?) ?? true,
        bossHotkey: (map['bossHotkey'] as String?) ?? 'Alt+H',
        pinned: (map['pinned'] as bool?) ?? false,
        appBgPreset: (map['appBgPreset'] as num?)?.toInt() ?? 0,
        appBgImage: (map['appBgImage'] as String?) ?? '',
        bookshelfSort: BookshelfSort
            .values[(map['bookshelfSort'] as num?)?.toInt() ?? 0],
      );

  /// 解析伪装对象；旧配置无 [disguiseTarget] 时按 [disguiseEnabled] 迁移
  /// （true→excel，false→none），保证老用户配置不丢失。
  static DisguiseTarget _parseDisguiseTarget(Map<String, Object?> map) {
    final idx = map['disguiseTarget'] as num?;
    if (idx != null) {
      return DisguiseTarget.values[idx.toInt().clamp(0, DisguiseTarget.values.length - 1)];
    }
    final oldEnabled = map['disguiseEnabled'] as bool?;
    return oldEnabled == true ? DisguiseTarget.excel : DisguiseTarget.none;
  }

  String toJson() => jsonEncode(toMap());

  static ReadConfig fromJson(String json) =>
      fromMap(Map<String, Object?>.from(jsonDecode(json) as Map));
}
