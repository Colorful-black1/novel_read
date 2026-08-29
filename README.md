# 静读 novel_read

无广告、纯本地的 TXT 小说阅读器，一套 Flutter 代码支持 **Windows PC** 与 **Android 手机**，
支持**局域网进度同步**（无需服务器与账号）与 PC 端**摸鱼伪装**。

## 功能总览

### 阅读
- 本地 TXT 导入（自动识别 UTF-8 / UTF-8 BOM / GBK / UTF-16 编码）
- 章节目录解析（第X章/节/卷/回），无章节书籍自动按 5 万字切分伪章节
- 翻页模式：上下滚动 / 左右翻页
- 阅读设置：字号、行间距、字体（宋体/黑体/楷体/微软雅黑）、5 种背景主题、夜间模式、亮度调节
- 阅读进度自动保存与恢复

### Windows 摸鱼
- **老板键 `Alt+Q`**：正常界面 → Excel 伪装皮肤 → 隐藏窗口，循环切换；再按恢复
- 伪装皮肤：界面与窗口标题（"Book1 - Excel"）一并伪装，阅读内容藏于"选中单元格"中，按 Esc 退出
- 失焦自动模糊：鼠标点开其他窗口时阅读内容自动高斯模糊
- 系统托盘常驻，窗口隐藏后可从托盘恢复（右键托盘可退出）
- 以上开关可在 阅读页 → 阅读设置 中调整

### 双端同步（局域网点对点，无云服务器）
1. PC 端打开「同步」页 → 开启服务，界面显示二维码与 6 位配对码（5 分钟有效、一次性）
2. 手机端「同步」页 → 扫码配对（或手动输入 IP/端口/配对码）
3. 任意一端点击同步：进度双向合并，冲突按"新时间戳覆盖旧时间戳"（LWW）处理，被覆盖方保留冲突快照
- 同一本书靠 `书名+文件大小+内容哈希` 识别，两端各自导入同一文件即可自动匹配
- 进度条目找不到对应书籍时会在下次导入相同 bookKey 的书时自动生效

## 技术栈

| 模块 | 选型 |
|---|---|
| 框架 | Flutter 3.x（Dart） |
| 状态管理 | flutter_riverpod |
| 存储 | sqflite（桌面端走 sqflite_common_ffi）+ shared_preferences |
| PC 摸鱼 | window_manager / tray_manager / hotkey_manager |
| 同步 | shelf（PC 内嵌 HTTP 服务）+ http + qr_flutter + mobile_scanner |
| 编码 | fast_gbk（GBK 解码）+ crypto（bookKey 哈希） |

## 构建指南

环境要求：
1. Flutter stable（本项目基于 3.47.2 开发，SDK 位于 `E:\Codeing\sdks\flutter`，建议加入 PATH）
2. Android：Android SDK（cmdline-tools 组件 + 已接受许可证）
3. Windows 桌面：VS Build Tools 2022（含"使用 C++ 的桌面开发"工作负载，已装于 `E:\Codeing\sdks\vs2022`）
   以及 **Windows 开发者模式**（已开启）

## 日常构建命令（本项目机器）

Flutter 未加入系统 PATH，先设置环境（或把 `E:\Codeing\sdks\flutter\bin` 加入系统 PATH 后省略此步）：

```bash
export PATH="/e/Codeing/sdks/flutter/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

构建（改动依赖后先跑 `flutter pub get`）：

```bash
# Android APK（release 版，体积小性能好）
flutter build apk
# 产物：build/app/outputs/flutter-apk/app-release.apk

# Windows exe（release 版）
flutter build windows
# 产物：build/windows/x64/runner/Release/novel_read.exe
# 注意：发布时需整个 Release 文件夹一起拷贝（exe + dll + data/），约 23MB

# 调试运行（连接手机 / Windows 桌面）
flutter run -d windows
flutter run                 # Android：需连接设备或启动模拟器

# 静态检查 + 单元测试
flutter analyze
flutter test
```

> 平台目录（`android/`、`windows/`）已生成并提交，正常情况下无需再执行 `flutter create`。
> 若换新机器克隆后报 "requires symlink support"，先开启 Windows 开发者模式
> （`start ms-settings:developers`，需管理员权限）再执行 `flutter create --platforms=windows .`。

## 项目结构

```
lib/
├── main.dart                  # 入口：初始化存储/Riverpod/PC 服务
├── core/                      # 常量、编码探测、章节解析、bookKey、分页引擎
├── data/
│   ├── database.dart          # SQLite 打开与建表
│   ├── model/models.dart      # Book/Chapter/Progress/SyncPair 实体
│   └── repository/            # 书库、进度（含 LWW 合并）、同步仓库
├── logic/                     # Riverpod providers、阅读设置、导入服务
├── services/boss_mode_service.dart  # PC 老板键/托盘/失焦监听
├── sync/                      # 同步协议、PC 服务端、手机客户端
└── ui/                        # 书架 / 阅读器 / 设置 / 同步 / Excel 伪装
```

## 已知限制与后续计划

- iOS 未支持（Windows 环境无法打包，代码层面随时可加）
- 同步目前为手动一键触发；自动同步（启动/退出时）为后续增强
- 全局老板键 Alt+Q 如与其他软件冲突，可在 hotkey_manager 注册处修改
- 跨外网同步（WebDAV 适配器）预留了扩展点，暂未实现
