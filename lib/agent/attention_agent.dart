import '../services/usage_service.dart';

class AttentionAgent {
  final UsageService _usageService = UsageService();

  /// Agent 的核心决策方法
  /// 返回：(是否弹窗, 提醒文案)
  Future<(bool, String)> shouldIntervene(String packageName, String appName) async {
    // 1️⃣ 获取数据（Agent 的"记忆"）
    final todayUsage = await _usageService.getTodayUsage(packageName);
    final totalUsage = await _usageService.getTodayTotalUsage();

    // 2️⃣ 根据规则做决策（Agent 的"思考"）

    // 规则1：这个 App 今天用了超过 1 小时 → 严厉提醒
    if (todayUsage > 3600) {
      return (
        true,
        '⚠️ 你今天在 $appName 上已经花了 ${_formatDuration(todayUsage)}，眼睛需要休息了！'
      );
    }

    // 规则2：这个 App 今天用了超过 30 分钟 → 温和提醒
    if (todayUsage > 1800) {
      return (
        true,
        '🧐 你今天在 $appName 上已经用了 ${_formatDuration(todayUsage)}，注意控制时间哦'
      );
    }

    // 规则3：今天总使用时间超过 3 小时 → 全局提醒
    if (totalUsage > 10800) {
      return (
        true,
        '🌅 你今天已经看了 ${_formatDuration(totalUsage)} 手机，该放下手机休息一下了'
      );
    }

    // 默认：不弹窗
    return (false, '');
  }

  /// 把秒数格式化成 "X小时X分钟"
  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
  }
}