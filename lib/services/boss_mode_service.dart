/// Windows 摸鱼模式服务。
///
/// 职责：
/// - 全局老板键（默认 Alt+Q）：正常界面 → 伪装皮肤 → 隐藏窗口 循环切换
/// - 系统托盘常驻，隐藏后可从托盘恢复
/// - 窗口失焦监听（供阅读内容自动模糊）
///
/// 仅在 Windows 平台启用，其他平台为空操作。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/constants.dart';
import '../logic/providers.dart';

/// 窗口失焦状态（阅读层据此自动模糊）
final windowBlurredProvider = StateProvider<bool>((ref) => false);

/// 摸鱼模式当前状态
enum BossState { normal, disguised, hidden }

final bossStateProvider = StateProvider<BossState>((ref) => BossState.normal);

/// 全局导航键（用于老板键切换伪装页面）
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

class BossModeService with WindowListener, TrayListener {
  BossModeService._();

  static final BossModeService instance = BossModeService._();

  ProviderContainer? _container;
  bool _initialized = false;

  static bool get supported => Platform.isWindows;

  /// 初始化窗口 / 托盘 / 全局热键。[ref] 用于更新全局状态。
  Future<void> init(ProviderContainer container) async {
    _container = container;
    if (!supported || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1200, 820),
      minimumSize: Size(500, 400),
      title: appName,
      center: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    windowManager.addListener(this);
    trayManager.addListener(this);

    // 托盘不可用时不阻塞主流程，老板键仍可隐藏/恢复窗口
    try {
      await trayManager.setIcon('assets/tray_icon.ico');
      await trayManager.setToolTip(appName);
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'tray_show', label: '显示$appName'),
        MenuItem(key: 'tray_exit', label: '退出'),
      ]));
    } catch (e) {
      debugPrint('托盘初始化失败（不影响其他功能）: $e');
    }

    // 全局老板键 Alt+Q
    try {
      await hotKeyManager.register(
        HotKey(
          key: LogicalKeyboardKey.keyQ,
          modifiers: [HotKeyModifier.alt],
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) => toggleBossKey(),
      );
    } catch (e) {
      debugPrint('全局热键注册失败（可能与其它软件冲突）: $e');
    }
  }

  /// 老板键：normal → disguised → hidden → normal
  Future<void> toggleBossKey() async {
    final container = _container;
    if (container == null) return;
    final state = container.read(bossStateProvider);
    final navigator = appNavigatorKey.currentState;
    switch (state) {
      case BossState.normal:
        final useDisguise =
            container.read(readConfigProvider).disguiseEnabled;
        if (useDisguise) {
          await windowManager.setTitle('Book1 - Excel');
          navigator?.pushNamed('/disguise');
          container.read(bossStateProvider.notifier).state = BossState.disguised;
        } else {
          await windowManager.hide();
          container.read(bossStateProvider.notifier).state = BossState.hidden;
        }
      case BossState.disguised:
        await windowManager.hide();
        container.read(bossStateProvider.notifier).state = BossState.hidden;
      case BossState.hidden:
        await windowManager.show();
        await windowManager.focus();
        container.read(bossStateProvider.notifier).state = BossState.normal;
    }
  }

  /// 退出伪装皮肤（伪装页 Esc 触发）
  Future<void> exitDisguise() async {
    final container = _container;
    if (container == null) return;
    if (container.read(bossStateProvider) != BossState.disguised) return;
    await windowManager.setTitle(appName);
    container.read(bossStateProvider.notifier).state = BossState.normal;
    appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  Future<void> exitApp() async {
    if (!supported) return;
    await hotKeyManager.unregisterAll();
    await windowManager.destroy();
    exit(0);
  }

  // ---------------- WindowListener ----------------

  @override
  void onWindowFocus() {
    _container?.read(windowBlurredProvider.notifier).state = false;
  }

  @override
  void onWindowBlur() {
    _container?.read(windowBlurredProvider.notifier).state = true;
  }

  // ---------------- TrayListener ----------------

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'tray_show':
        _showWindow();
      case 'tray_exit':
        exitApp();
    }
  }

  void _showWindow() {
    windowManager.show();
    windowManager.focus();
    _container?.read(bossStateProvider.notifier).state = BossState.normal;
  }
}
