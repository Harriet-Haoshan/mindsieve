import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../database/app_dao.dart';
import 'usage_service.dart';

/// 前台应用自动监控器 —— 时间统计的核心
///
/// 工作原理（事件回放，非轮询当前前台）：
/// 1. 每 2 秒调用原生 UsageStatsManager.queryEvents，拉取
///    [lastEventTs, now] 内系统记录的「App 进入前台 / 退到后台」事件；
/// 2. 用状态机把事件还原成一段段前台使用区间（RESUMED ~ PAUSED）；
/// 3. 区间的 App 在 controlled_apps 表中且 enabled=1 时，
///    把 (start_time, duration) 写入 usage_logs。
///
/// 为什么用事件回放而不是「查询当前前台 App + 计时器累加」：
/// - MindSieve 退到后台后 Dart 定时器会被系统暂停，轮询会停摆；
/// - 事件日志由系统内核持续记录，MindSieve 回到前台后一次性补录
///   期间所有被监控 App 的使用时长，数据零丢失。
///
/// 单例：跨页面存活，由 main.dart 的 MainPage 启动。
class ForegroundMonitor {
  ForegroundMonitor._internal();
  static final ForegroundMonitor _instance = ForegroundMonitor._internal();
  factory ForegroundMonitor() => _instance;

  static const MethodChannel _channel = MethodChannel('mindsieve/usage');
  // UsageEvents 事件类型（与原生端约定）：1=进入前台 2=退到后台
  static const int _eventForeground = 1;
  static const int _eventBackground = 2;
  static const String _metaLastEventTs = 'last_event_ts';

  final AppDao _dao = AppDao();
  final UsageService _usageService = UsageService();

  Timer? _timer;
  bool _running = false;
  int? _lastEventTs; // 已处理的最后事件时间戳（毫秒），持久化在 meta 表

  // 当前「打开」的前台 App（按事件流状态机推演）
  String? _openPackage;
  int? _openStartMs;

  /// 使用情况访问权限状态，页面监听它显示授权引导横幅
  final ValueNotifier<bool> hasPermission = ValueNotifier(false);

  /// 监控状态文案，主页直接展示（授权状态 / 最近记录 / 异常信息）
  final ValueNotifier<String> status = ValueNotifier('监控未启动');

  /// 一段被监控 App 的使用区间完成结算时触发（包名, 显示名, 秒）
  /// main.dart 用它做 Agent 提醒（回到 MindSieve 时弹出复盘悬浮窗）
  void Function(String packageName, String appName, int seconds)?
  onSessionCompleted;

  /// 确保监控已启动（可安全重复调用）：
  /// 无权限时只更新状态，用户授权后由生命周期回调再次触发
  Future<void> ensureStarted() async {
    if (_running) {
      hasPermission.value = await checkPermission();
      if (!hasPermission.value) {
        status.value = '需要「使用情况访问」权限才能自动记录';
      }
      return;
    }
    hasPermission.value = await checkPermission();
    if (!hasPermission.value) {
      status.value = '需要「使用情况访问」权限才能自动记录';
      return;
    }

    // 恢复上次同步游标：首次运行从「现在」开始采集，避免导入历史
    if (_lastEventTs == null) {
      final saved = await _dao.getMeta(_metaLastEventTs);
      _lastEventTs =
          int.tryParse(saved ?? '') ?? DateTime.now().millisecondsSinceEpoch;
    }

    _running = true;
    status.value = '自动监控已开启 · 等待记录...';
    await syncEvents(); // 启动即补录离线期间的使用
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => syncEvents());
  }

  /// 拉取并回放事件流。任何异常都不允许中断定时器
  Future<void> syncEvents() async {
    if (!_running) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final events =
          await _channel.invokeListMethod<Map<dynamic, dynamic>>(
            'queryUsageEvents',
            {'start': _lastEventTs, 'end': now},
          ) ??
          const [];

      for (final event in events) {
        final pkg = event['packageName'] as String?;
        final type = (event['eventType'] as num?)?.toInt();
        final ts = (event['timestamp'] as num?)?.toInt();
        if (pkg == null || type == null || ts == null) continue;
        await _processEvent(pkg, type, ts);
        if (_lastEventTs == null || ts > _lastEventTs!) {
          _lastEventTs = ts;
        }
      }
      // 每次同步后持久化游标：进程被杀后重启也能从断点继续补录
      await _dao.setMeta(_metaLastEventTs, '$_lastEventTs');
      hasPermission.value = true;
    } on PlatformException catch (e) {
      debugPrint('ForegroundMonitor: 事件同步失败 ${e.message}');
      // 权限可能在设置中被撤销
      hasPermission.value = await checkPermission();
      if (!hasPermission.value) {
        status.value = '「使用情况访问」权限已被关闭，请重新授权';
        _running = false;
        _timer?.cancel();
      }
    } on MissingPluginException {
      // 原生通道未就绪（热重载初期），下个周期重试
    }
  }

  /// 事件状态机：还原前台使用区间并结算
  Future<void> _processEvent(String pkg, int type, int ts) async {
    if (type == _eventForeground) {
      if (pkg == _openPackage) return; // 同一 App 重复 RESUMED，忽略
      // 切换到新 App：结算上一段
      await _settleOpenSession(endMs: ts);
      _openPackage = pkg;
      _openStartMs = ts;
    } else if (type == _eventBackground) {
      if (pkg != _openPackage) return; // 事件乱序（先 RESUMED 后 PAUSED），已结算过
      await _settleOpenSession(endMs: ts);
    }
  }

  /// 结算当前打开的区间：被监控且启用的 App 才写入 usage_logs
  Future<void> _settleOpenSession({required int endMs}) async {
    final pkg = _openPackage;
    final startMs = _openStartMs;
    _openPackage = null;
    _openStartMs = null;
    if (pkg == null || startMs == null) return;

    final seconds = (endMs - startMs) ~/ 1000;
    if (seconds < 1) return; // 过滤瞬时切换产生的碎片区间

    final app = await _dao.getControlledApp(pkg);
    if (app == null) return; // 不在监控列表中或已被关闭

    final appName = app['app_name'] as String? ?? pkg;
    final nickname = app['nickname'] as String?;
    final displayName =
        (nickname != null && nickname.isNotEmpty) ? nickname : appName;

    await _usageService.recordUsage(pkg, appName, startMs, seconds);
    status.value = '已记录 $displayName 使用 ${_format(seconds)}';
    onSessionCompleted?.call(pkg, displayName, seconds);
  }

  /// 检查「使用情况访问」权限
  Future<bool> checkPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 跳转系统「使用情况访问」授权页
  Future<void> openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
    } on PlatformException catch (e) {
      debugPrint('ForegroundMonitor: 打开授权页失败 ${e.message}');
    }
  }

  String _format(int seconds) {
    if (seconds < 60) return '$seconds秒';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '$hours小时$minutes分钟' : '$minutes分钟';
  }
}
