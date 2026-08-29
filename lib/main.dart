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
import 'ui/home/bookshelf_page.dart';
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
        '/disguise': (_) => const ExcelDisguisePage(),
      },
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          BookshelfPage(),
          SyncPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
        ],
        onDestinationSelected: (i) => setState(() => _tab = i),
      ),
    );
  }
}
