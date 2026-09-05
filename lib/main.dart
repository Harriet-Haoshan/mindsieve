import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'agent/attention_agent.dart';
import 'models/app_stats.dart';
import 'pages/home_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/stats/stats_page.dart';
import 'services/foreground_monitor.dart';
import 'services/overlay_service.dart';
import 'services/usage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 加载 .env 配置（API Key 等）；文件缺失时不阻塞启动，AI 功能会提示配置
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('MindSieve: 未找到 .env 文件，AI 分析功能将提示配置 API Key');
  }
  runApp(const MindSieveApp());
}

class MindSieveApp extends StatelessWidget {
  const MindSieveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindSieve',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const MainPage(),
      // 常驻悬浮层：由 MaterialApp 持有，与页面生命周期解耦
      builder: (context, child) => OverlayHost(child: child),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  final ForegroundMonitor _monitor = ForegroundMonitor();
  final AttentionAgent _agent = AttentionAgent();
  final UsageService _usageService = UsageService();

  // 「5分钟后再次提醒」定时器
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onNavigateToStats: () => setState(() => _currentIndex = 1)),
      const StatsPage(),
      const SettingsPage(),
    ];

    WidgetsBinding.instance.addObserver(this);
    // 被监控 App 的一段使用完成结算时（事件回放补录），触发 Agent 提醒
    _monitor.onSessionCompleted = _onSessionCompleted;
    // 首帧后启动前台监控（无权限时仅更新状态，等待用户授权）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitor.ensureStarted();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderTimer?.cancel();
    _monitor.onSessionCompleted = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到 MindSieve：补录后台期间所有前台使用事件；
      // 用户从系统授权页返回时，也由此自动启动监控
      _monitor.ensureStarted();
    }
  }

  /// 一段被监控 App 的使用区间结算完成：
  /// 事件回放通常发生在用户刚切回 MindSieve 时，此时弹出注意力提醒
  Future<void> _onSessionCompleted(
    String packageName,
    String appName,
    int seconds,
  ) async {
    // 已有悬浮窗展示中，不重复弹出
    if (OverlayService.isShowing) return;

    final (shouldShow, _) = await _agent.shouldIntervene(packageName, appName);
    if (!shouldShow) return;
    final todayUsage = await _usageService.getTodayUsage(packageName);
    if (!mounted || OverlayService.isShowing) return;

    // MainPage 是根页面，messenger 始终有效
    final messenger = ScaffoldMessenger.of(context);

    OverlayService.showOverlay(
      appName: appName,
      todayUsage: formatDuration(todayUsage),
      onContinue: () {
        OverlayService.dismiss();
        messenger.showSnackBar(const SnackBar(content: Text('继续使用')));
      },
      onTimer: () {
        OverlayService.dismiss();
        messenger.showSnackBar(
          const SnackBar(content: Text('5分钟后将再次提醒你！')),
        );
        _reminderTimer?.cancel();
        _reminderTimer = Timer(const Duration(minutes: 5), () {
          if (OverlayService.isShowing) return;
          OverlayService.showOverlay(
            appName: appName,
            todayUsage: '5分钟前你选择了继续使用',
            onContinue: () {
              OverlayService.dismiss();
              messenger.showSnackBar(const SnackBar(content: Text('继续使用')));
            },
            onTimer: () {
              OverlayService.dismiss();
              messenger.showSnackBar(
                const SnackBar(content: Text('再给你5分钟！')),
              );
            },
            onExit: () {
              OverlayService.dismiss();
              messenger.showSnackBar(
                const SnackBar(content: Text('好的，已记录本次使用')),
              );
            },
          );
        });
      },
      onExit: () {
        OverlayService.dismiss();
        messenger.showSnackBar(
          const SnackBar(content: Text('好的，已记录本次使用')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '报告'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
