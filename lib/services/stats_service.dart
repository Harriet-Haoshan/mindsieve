import '../database/app_dao.dart';
import '../models/app_stats.dart';

/// 统计复盘查询服务：为 天/周/月/年 四个视图提供聚合数据
class StatsService {
  final AppDao _dao = AppDao();

  /// 今日「小时 × App」使用分布（24 小时堆叠色块图）
  Future<List<HourlyAppUsage>> getTodayHourlyAppUsage() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return await _dao.getHourlyAppUsage(
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
  }

  /// 本周（周一起）7 天的总使用时长，横轴 周一～周日
  Future<List<TimeBucketStats>> getWeekDailyTotals() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final raw = await _dao.getDailyTotals(
      weekStart.millisecondsSinceEpoch,
      weekEnd.millisecondsSinceEpoch,
    );

    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      return TimeBucketStats(label: labels[i], duration: raw[key] ?? 0);
    });
  }

  /// 本月 1 日至月末每天的总使用时长
  Future<List<TimeBucketStats>> getMonthDailyTotals() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = monthEnd.difference(monthStart).inDays;

    final raw = await _dao.getDailyTotals(
      monthStart.millisecondsSinceEpoch,
      monthEnd.millisecondsSinceEpoch,
    );

    return List.generate(daysInMonth, (i) {
      final day = monthStart.add(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      return TimeBucketStats(label: '${day.day}', duration: raw[key] ?? 0);
    });
  }

  /// 今年 1～12 月的总使用时长
  Future<List<TimeBucketStats>> getYearMonthlyTotals() async {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);

    final raw = await _dao.getMonthlyTotals(
      yearStart.millisecondsSinceEpoch,
      yearEnd.millisecondsSinceEpoch,
    );

    const labels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];
    return List.generate(12, (i) {
      final key =
          '${now.year.toString().padLeft(4, '0')}-'
          '${(i + 1).toString().padLeft(2, '0')}';
      return TimeBucketStats(label: labels[i], duration: raw[key] ?? 0);
    });
  }
}
