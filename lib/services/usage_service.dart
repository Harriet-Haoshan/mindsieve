import '../database/app_dao.dart';

/// 使用记录服务 - 委托 AppDao 统一管理数据库
/// 单例：跨页面共享同一数据库访问入口
///
/// 计时逻辑说明：真正的计时由 ForegroundMonitor 完成——
/// 通过 UsageStatsManager 事件流回放得到每段前台使用区间，
/// 本服务只负责把已完成的区间写入数据库（start_time + duration）。
class UsageService {
  UsageService._internal();
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;

  final AppDao _dao = AppDao();

  /// 记录一段已完成的前台使用区间（秒），时长累加到当日总时长
  Future<void> recordUsage(
    String packageName,
    String appName,
    int startMs,
    int durationInSeconds,
  ) async {
    await _dao.insertUsageLog(packageName, appName, startMs, durationInSeconds);
  }

  /// 获取今天某个 App 的使用时长（秒）
  Future<int> getTodayUsage(String packageName) async {
    return await _dao.getTodayUsage(packageName);
  }

  /// 获取今天总使用时长（秒）
  Future<int> getTodayTotalUsage() async {
    return await _dao.getTodayTotalUsage();
  }

  // ========== 测试专用方法 ==========
  // 注意：以下方法仅用于开发和测试阶段，正式发布前需要删除

  /// 测试用：清空所有使用记录
  Future<void> clearAllUsage() async {
    await _dao.clearAllUsage();
  }

  /// 测试用：写入一条模拟使用记录
  Future<void> addMockUsage(
    String packageName,
    String appName,
    int durationInSeconds,
  ) async {
    await _dao.addMockUsage(packageName, appName, durationInSeconds);
  }
}
