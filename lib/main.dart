/// 应用入口：初始化存储、Riverpod 容器与 PC 摸鱼服务。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'data/database.dart';
import 'logic/providers.dart';
import 'services/boss_mode_service.dart';
import 'ui/disguise/excel_disguise.dart';
import 'ui/disguise/word_disguise.dart';
import 'ui/home/bookshelf_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/stats/stats_page.dart';
import 'ui/sync/sync_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final db = await AppDatabase.instance();
  final container = ProviderContainer(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
    ],
  );

  runApp(UncontrolledProviderScope(
    container: container,
    child: const NovelReadApp(),
  ));

  // Windows：初始化窗口 / 托盘 / 老板键
  if (BossModeService.supported) {
    await BossModeService.instance.init(container);
  }
}

class NovelReadApp extends StatelessWidget {
  const NovelReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B7C99),
        useMaterial3: true,
        fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
      ),
      home: const _HomePage(),
      routes: {
        '/disguise/excel': (_) => const ExcelDisguisePage(),
        '/disguise/word': (_) => const WordDisguisePage(),
      },
    );
  }
}

class _HomePage extends ConsumerStatefulWidget {
  const _HomePage();

  @override
  ConsumerState<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<_HomePage> {
  int _tab = 0;

  ThemeData _themeFor(bool dark) {
    return ThemeData(
      colorSchemeSeed: const Color(0xFF5B7C99),
      brightness: dark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = ref.watch(appBackdropProvider);

    return Theme(
      data: _themeFor(backdrop.dark),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // body 延伸到底部导航栏后面，让背景图/背景色透过透明的导航栏显示
        extendBody: true,
        body: Stack(
          children: [
            // 软件背景：自定义图片（叠遮罩保证文字可读）或预设纯色
            if (backdrop.imagePath != null) ...[
              Positioned.fill(
                child: Image.file(
                  File(backdrop.imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      ColoredBox(color: backdrop.color),
                ),
              ),
              const Positioned.fill(
                child: ColoredBox(color: Color(0x4D000000)),
              ),
            ] else
              Positioned.fill(child: ColoredBox(color: backdrop.color)),
            IndexedStack(
              index: _tab,
              children: const [
                BookshelfPage(),
                SyncPage(),
                StatsPage(),
                SettingsPage(),
              ],
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: _tab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: '书架',
            ),
            NavigationDestination(
              icon: Icon(Icons.sync_outlined),
              selectedIcon: Icon(Icons.sync),
              label: '同步',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: '统计',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
          onDestinationSelected: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}
