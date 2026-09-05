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

  String get formattedTotalDuration {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }
}
