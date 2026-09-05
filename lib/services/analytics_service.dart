import '../database/app_dao.dart';
import '../models/app_stats.dart';

class AnalyticsService {
  final AppDao _dao = AppDao();

  /// 今日各 App 使用占比
  /// 返回 List<{app: AppUsageStats, percentage: double}>
  Future<List<Map<String, dynamic>>> getTodayUsageBreakdown() async {
    final topApps = await _dao.getTodayTopApps();
    final total = topApps.fold<int>(0, (sum, e) => sum + e.totalDuration);
    if (total == 0) return [];

    return topApps.map((app) {
      final percentage = (app.totalDuration / total) * 100;
      return {
        'app': app,
        'percentage': double.parse(percentage.toStringAsFixed(1)),
      };
    }).toList();
  }

  /// 今日小时分布
  Future<List<HourlyStats>> getTodayHourlyDistribution() async {
    return await _dao.getTodayHourlyDistribution();
  }

  /// 今日汇总
  Future<DailySummary> getTodaySummary() async {
    final totalUsage = await _dao.getTodayTotalUsage();
    final topApps = await _dao.getTodayTopApps();
    final totalOpens = topApps.fold<int>(0, (sum, e) => sum + e.openCount);
    final suggestions = _generateSuggestions(totalUsage, topApps);

    return DailySummary(
      totalDuration: totalUsage,
      totalOpens: totalOpens,
      topApps: topApps,
      suggestions: suggestions,
    );
  }

  /// 根据数据生成智能建议
  List<String> _generateSuggestions(
    int totalUsage,
    List<AppUsageStats> topApps,
  ) {
    final suggestions = <String>[];

    if (totalUsage > 10800) {
      suggestions.add('今天总使用时长已超过 3 小时，建议放下手机休息一下');
    }

    if (topApps.isNotEmpty) {
      final top = topApps.first;
      if (top.totalDuration > 3600) {
        suggestions.add('${top.appName} 今天已使用超过 1 小时，注意控制时间');
      }
    }

    if (topApps.length >= 3) {
      suggestions.add('今天打开了 ${topApps.length} 个 App，尝试减少切换频率以保持专注');
    }

    return suggestions;
  }
}
