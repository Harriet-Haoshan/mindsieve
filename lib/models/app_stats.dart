/// 单个 App 的使用统计
class AppUsageStats {
  final String packageName;
  final String appName;
  final int totalDuration; // 秒
  final int openCount;

  AppUsageStats({
    required this.packageName,
    required this.appName,
    required this.totalDuration,
    required this.openCount,
  });
}

/// 按小时统计
class HourlyStats {
  final int hour;
  final int duration; // 秒
  final int openCount;

  HourlyStats({
    required this.hour,
    required this.duration,
    required this.openCount,
  });
}

/// 某小时内单个 App 的使用时长（天视图 24 小时堆叠图用）
class HourlyAppUsage {
  final int hour;
  final String packageName;
  final String appName; // 昵称优先的显示名
  final int duration; // 秒

  HourlyAppUsage({
    required this.hour,
    required this.packageName,
    required this.appName,
    required this.duration,
  });
}

/// 单个时间桶（天/月/年视图通用）：label 为横轴文案，duration 单位秒
class TimeBucketStats {
  final String label;
  final int duration; // 秒

  TimeBucketStats({required this.label, required this.duration});
}

/// 秒数格式化：不足 1 分钟按秒显示，避免显示为「0分钟」
String formatDuration(int seconds) {
  if (seconds < 60) return '$seconds秒';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) {
    return '$hours小时$minutes分钟';
  }
  return '$minutes分钟';
}

/// 今日汇总
class DailySummary {
  final int totalDuration; // 秒
  final int totalOpens;
  final List<AppUsageStats> topApps;
  final List<String> suggestions;

  DailySummary({
    required this.totalDuration,
    required this.totalOpens,
    required this.topApps,
    required this.suggestions,
  });

  String get formattedTotalDuration => formatDuration(totalDuration);
}
