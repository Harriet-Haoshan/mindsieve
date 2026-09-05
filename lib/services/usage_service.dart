import '../database/app_dao.dart';

/// 使用记录服务 - 委托 AppDao 统一管理数据库
class UsageService {
  final AppDao _dao = AppDao();

  /// 记录打开 App
  Future<void> logAppOpen(String packageName, String appName) async {
    await _dao.logAppOpen(packageName, appName);
  }

  /// 更新使用时长
  Future<void> updateDuration(int logId, int durationInSeconds) async {
    await _dao.updateDuration(logId, durationInSeconds);
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
