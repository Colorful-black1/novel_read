/// Windows 摸鱼模式服务。
///
/// 职责：
/// - 全局老板键（默认 Alt+H，可在首页自定义）：正常界面 → 伪装皮肤 → 隐藏窗口 循环切换
/// - 系统托盘常驻，隐藏后可从托盘恢复
/// - 窗口失焦自动最小化（摸鱼保护）
/// - 窗口尺寸/位置持久化
/// - 窗口钉住置顶（钉住时老板键失效）
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

/// 窗口失焦状态
final windowBlurredProvider = StateProvider<bool>((ref) => false);

/// 摸鱼模式当前状态
enum BossState { normal, disguised, hidden }

final bossStateProvider = StateProvider<BossState>((ref) => BossState.normal);

/// 全局导航键（用于老板键切换伪装页面）
final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

/// 窗口尺寸/位置的持久化 key
const _kWinX = 'win_x', _kWinY = 'win_y', _kWinW = 'win_w', _kWinH = 'win_h';

/// 解析 'Alt+Ctrl+H' 形式的快捷键描述为 HotKey。
/// 需要至少一个修饰键 + 一个主键，不合法返回 null。
HotKey? parseHotkey(String text) {
  final parts =
      text.split('+').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.length < 2) return null;
  final modifiers = <HotKeyModifier>[];
  LogicalKeyboardKey? key;
  for (final p in parts) {
    switch (p.toLowerCase()) {
      case 'alt':
        modifiers.add(HotKeyModifier.alt);
      case 'ctrl' || 'control':
        modifiers.add(HotKeyModifier.control);
      case 'shift':
        modifiers.add(HotKeyModifier.shift);
      case 'meta' || 'win' || 'cmd':
        modifiers.add(HotKeyModifier.meta);
      default:
        key = _mainKey(p);
    }
  }
  if (modifiers.isEmpty || key == null) return null;
  return HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
}

/// 主键映射：字母 a-z / 数字 0-9 / F1-F12。
/// Flutter 的这些键 keyId 在各自区段内连续递增，可用基准键 + 偏移构造。
LogicalKeyboardKey? _mainKey(String p) {
  final t = p.toLowerCase();
  if (t.length == 1) {
    final code = t.codeUnitAt(0);
    if (code >= 97 && code <= 122) {
      return LogicalKeyboardKey(LogicalKeyboardKey.keyA.keyId + (code - 97));
    }
    if (code >= 48 && code <= 57) {
      return LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + (code - 48));
    }
  }
  if (t.startsWith('f')) {
    final n = int.tryParse(t.substring(1));
    if (n != null && n >= 1 && n <= 24) {
      return LogicalKeyboardKey(LogicalKeyboardKey.f1.keyId + (n - 1));
    }
  }
  return null;
}

class BossModeService with WindowListener, TrayListener {
  BossModeService._();

  static final BossModeService instance = BossModeService._();

  ProviderContainer? _container;
  bool _initialized = false;
  HotKey? _registeredHotKey;

  static bool get supported => Platform.isWindows;

  /// 初始化窗口 / 托盘 / 全局热键。[ref] 用于更新全局状态。
  Future<void> init(ProviderContainer container) async {
    _container = container;
    if (!supported || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();

    // 恢复上次窗口尺寸/位置（无记录则默认 1200x820 居中）
    final prefs = container.read(sharedPrefsProvider);
    final w = prefs.getDouble(_kWinW);
    final h = prefs.getDouble(_kWinH);
    final x = prefs.getDouble(_kWinX);
    final y = prefs.getDouble(_kWinY);
    final hasSavedBounds = w != null && h != null;
    final windowOptions = WindowOptions(
      size: hasSavedBounds ? Size(w, h) : const Size(1200, 820),
      minimumSize: const Size(500, 400),
      title: appName,
      center: !hasSavedBounds,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // 拦截关闭：onWindowClose 里保存窗口 bounds 后再销毁
      await windowManager.setPreventClose(true);
      if (hasSavedBounds && x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
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

    // 全局老板键（从阅读设置读取，默认 Alt+H）
    final hotkeyText = container.read(readConfigProvider).bossHotkey;
    await registerHotkey(hotkeyText);

    // 恢复钉住状态
    if (container.read(readConfigProvider).pinned) {
      await windowManager.setAlwaysOnTop(true);
    }
  }

  /// 注册全局老板键（替代已有注册；新键注册失败时保留旧键可用）
  Future<bool> registerHotkey(String hotkeyText) async {
    final hotKey = parseHotkey(hotkeyText);
    if (hotKey == null) return false;
    final old = _registeredHotKey;
    try {
      await hotKeyManager.register(hotKey, keyDownHandler: (_) => toggleBossKey());
    } catch (e) {
      debugPrint('全局热键注册失败（可能与其它软件冲突）: $e');
      return false;
    }
    if (old != null && old != hotKey) {
      try {
        await hotKeyManager.unregister(old);
      } catch (_) {}
    }
    _registeredHotKey = hotKey;
    return true;
  }

  /// 老板键：normal → disguised → hidden → normal
  ///
  /// 窗口钉住置顶时老板键失效（此时用户正在多软件切换，不希望误触发）。
  Future<void> toggleBossKey() async {
    final container = _container;
    if (container == null) return;
    if (container.read(readConfigProvider).pinned) return;
    final state = container.read(bossStateProvider);
    final navigator = appNavigatorKey.currentState;
    switch (state) {
      case BossState.normal:
        final useDisguise =
            container.read(readConfigProvider).disguiseEnabled;
        // 防止伪装页已在栈顶时重复压栈（画面无变化，且栈越叠越深）
        if (useDisguise && navigator != null && !_disguiseOnTop(navigator)) {
          await windowManager.setTitle('Book1 - Excel');
          navigator.pushNamed('/disguise');
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
        // 恢复时必须还原界面状态：隐藏前若在伪装页，退回正常界面并还原标题，
        // 否则页面停在 Excel 伪装而状态是 normal，下次老板键会重复压栈
        navigator?.popUntil((r) => r.isFirst);
        await windowManager.setTitle(appName);
    }
  }

  /// 伪装页是否在导航栈顶（只查看不弹出）
  bool _disguiseOnTop(NavigatorState navigator) {
    var onTop = false;
    navigator.popUntil((route) {
      onTop = route.settings.name == '/disguise';
      return true; // 立即停止，不实际弹出任何路由
    });
    return onTop;
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

  /// 设置钉住置顶（阅读菜单切换）
  Future<void> setPinned(bool pinned) async {
    if (!supported) return;
    await windowManager.setAlwaysOnTop(pinned);
  }

  Future<void> _saveWindowBounds() async {
    final container = _container;
    if (container == null) return;
    final prefs = container.read(sharedPrefsProvider);
    final size = await windowManager.getSize();
    final offset = await windowManager.getPosition();
    await prefs.setDouble(_kWinW, size.width);
    await prefs.setDouble(_kWinH, size.height);
    await prefs.setDouble(_kWinX, offset.dx);
    await prefs.setDouble(_kWinY, offset.dy);
  }

  Future<void> exitApp() async {
    if (!supported) return;
    await hotKeyManager.unregisterAll();
    await windowManager.destroy();
  }

  // ---------------- WindowListener ----------------

  @override
  void onWindowFocus() {
    _container?.read(windowBlurredProvider.notifier).state = false;
  }

  @override
  void onWindowBlur() {
    final container = _container;
    if (container == null) return;
    container.read(windowBlurredProvider.notifier).state = true;
    // 摸鱼保护：失焦直接最小化（点任务栏/托盘可恢复）。
    // 两种情况不最小化：
    // 1. 老板键主动隐藏窗口时也会触发失焦（否则隐藏窗口会以最小化形式
    //    重新出现在任务栏）；
    // 2. 窗口已钉住置顶——此时用户在多软件间切换，摸鱼功能整体失效。
    final cfg = container.read(readConfigProvider);
    if (cfg.blurOnFocusLost &&
        !cfg.pinned &&
        container.read(bossStateProvider) == BossState.normal) {
      windowManager.minimize();
    }
  }

  @override
  void onWindowClose() async {
    await _saveWindowBounds();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
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
    // 从隐藏/伪装状态唤起时还原正常界面与标题
    appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    windowManager.setTitle(appName);
  }
}
