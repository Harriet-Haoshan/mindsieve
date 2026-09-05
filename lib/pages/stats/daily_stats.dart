import 'package:flutter/material.dart';

import '../../models/app_stats.dart';
import '../../services/ai_analysis_service.dart';
import '../../services/analytics_service.dart';
import '../../services/stats_service.dart';

/// 天视图：24 小时 × 各 App 的彩色堆叠色块图
class DailyStatsView extends StatefulWidget {
  const DailyStatsView({super.key});

  @override
  State<DailyStatsView> createState() => _DailyStatsViewState();
}

class _DailyStatsViewState extends State<DailyStatsView> {
  final StatsService _stats = StatsService();
  final AnalyticsService _analytics = AnalyticsService();
  final AiAnalysisService _aiService = AiAnalysisService();

  bool _isLoading = true;
  List<HourlyAppUsage> _data = [];
  DailySummary? _summary;

  // AI 分析状态
  bool _aiLoading = false;
  bool _aiFailed = false;
  bool _aiMissingKey = false;
  String? _aiResult;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _stats.getTodayHourlyAppUsage();
      final summary = await _analytics.getTodaySummary();
      if (!mounted) return;
      setState(() {
        _data = data;
        _summary = summary;
        _isLoading = false;
      });
      // 数据加载完成后触发 AI 分析
      _requestAiAnalysis();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 请求 AI 分析（失败时降级显示本地建议）
  Future<void> _requestAiAnalysis() async {
    final summary = _summary;
    // 没有使用数据时不调用 AI，避免浪费请求
    if (summary == null || summary.totalDuration == 0) return;

    setState(() {
      _aiLoading = true;
      _aiFailed = false;
      _aiMissingKey = false;
    });

    try {
      final result = await _aiService.analyzeTodayUsage(
        topApps: summary.topApps,
        hourly: const [],
        totalDuration: summary.totalDuration,
        totalOpens: summary.totalOpens,
      );
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        // API Key 未配置时单独提示，其他错误降级显示本地建议
        _aiMissingKey = e is AiConfigException;
        _aiFailed = e is! AiConfigException;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 20),
          _buildSectionTitle('24 小时使用分布'),
          DailyHourChart(
            data: _data,
            onHourTap: _showHourDetail,
          ),
          const SizedBox(height: 8),
          _buildLegend(),
          const SizedBox(height: 20),
          _buildAiSectionHeader(),
          _buildAiAnalysis(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ========== 今日汇总卡 ==========

  Widget _buildSummaryCard() {
    final total = _summary?.formattedTotalDuration ?? '0分钟';
    final opens = _summary?.totalOpens ?? 0;
    final topApp = _summary?.topApps.isNotEmpty == true
        ? _summary!.topApps.first.appName
        : '无';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.purple.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('今日总时长', total),
          _buildStatItem('打开次数', '$opens'),
          _buildStatItem('使用最多', topApp),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ========== 图例 ==========

  Widget _buildLegend() {
    final packages = <String>[];
    final names = <String, String>{};
    for (final u in _data) {
      if (!packages.contains(u.packageName)) {
        packages.add(u.packageName);
        names[u.packageName] = u.appName;
      }
    }
    if (packages.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: packages.map((pkg) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: appColorFor(pkg, packages),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              names[pkg] ?? pkg,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 点击某小时列：底部弹出该小时各 App 使用明细
  void _showHourDetail(int hour, List<HourlyAppUsage> apps) {
    final packages = apps.map((e) => e.packageName).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${hour.toString().padLeft(2, '0')}:00 - '
              '${(hour + 1).toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...apps.map((u) => ListTile(
                  dense: true,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: appColorFor(u.packageName, packages),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  title: Text(
                    u.appName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  trailing: Text(
                    formatDuration(u.duration),
                    style: const TextStyle(color: Colors.white54),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ========== 智能分析（沿用原今日报告的 AI 块） ==========

  Widget _buildAiSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Text(
            '智能分析',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '重新进行 AI 分析',
            onPressed: _aiLoading ? null : _requestAiAnalysis,
            icon: _aiLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
          ),
        ],
      ),
    );
  }

  /// 智能分析区：优先显示 AI 分析结果，失败时降级显示本地建议
  Widget _buildAiAnalysis() {
    // 没有使用数据时，不显示 AI 区
    if ((_summary?.totalDuration ?? 0) == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '暂无数据，自动监控会在你使用被监控 App 时记录',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // AI 分析中
    if (_aiLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'AI 正在分析你的使用数据...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // API Key 未配置 → 显示配置指引
    if (_aiMissingKey) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key, color: Colors.orange, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '请配置 API Key\n'
                '方式一：在项目根目录 .env 文件中填入 MODELSCOPE_API_KEY\n'
                '方式二：flutter run --dart-define=MODELSCOPE_API_KEY=sk-xxx',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI 调用失败 → 降级显示本地建议 + 重试按钮
    if (_aiFailed) {
      return Column(
        children: [
          _buildLocalSuggestions(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _requestAiAnalysis,
            icon: const Icon(Icons.refresh, size: 16, color: Colors.blue),
            label: const Text(
              '重试 AI 分析',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ],
      );
    }

    // AI 分析结果
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'AI 私人教练',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _aiResult ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 本地简单建议（AI 调用失败时的降级方案）
  Widget _buildLocalSuggestions() {
    final suggestions = _summary?.suggestions ?? [];
    if (suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '暂无建议，继续积累数据吧',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      children: suggestions.map((suggestion) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// App 固定配色：按出现顺序从调色板取色，保证各视图颜色一致
const _appPalette = [
  Colors.blueAccent,
  Colors.greenAccent,
  Colors.orange,
  Colors.purpleAccent,
  Colors.redAccent,
  Colors.tealAccent,
  Colors.pinkAccent,
  Colors.amber,
  Colors.cyanAccent,
  Colors.indigoAccent,
];

Color appColorFor(String packageName, List<String> packages) {
  final i = packages.indexOf(packageName);
  return i < 0 ? Colors.grey : _appPalette[i % _appPalette.length];
}

/// 24 小时堆叠色块图：每列一个小时，列内按 App 时长比例纵向堆叠
class DailyHourChart extends StatelessWidget {
  final List<HourlyAppUsage> data;

  /// 点击某小时列回调（弹出该小时明细）
  final void Function(int hour, List<HourlyAppUsage> apps)? onHourTap;

  const DailyHourChart({super.key, required this.data, this.onHourTap});

  static const double _chartHeight = 220;

  @override
  Widget build(BuildContext context) {
    // 按小时归集：0-23 每小时一个 App 列表
    final byHour = <int, List<HourlyAppUsage>>{
      for (var h = 0; h < 24; h++) h: [],
    };
    final packages = <String>[];
    for (final u in data) {
      byHour[u.hour]!.add(u);
      if (!packages.contains(u.packageName)) packages.add(u.packageName);
    }

    int maxHourTotal = 0;
    for (final list in byHour.values) {
      final total = list.fold<int>(0, (sum, e) => sum + e.duration);
      if (total > maxHourTotal) maxHourTotal = total;
    }

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var h = 0; h < 24; h++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: _buildHourColumn(
                        h,
                        byHour[h]!,
                        maxHourTotal,
                        packages,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 时间轴：每 3 小时标注一次，避免拥挤
          Row(
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Center(
                    child: Text(
                      h % 3 == 0 ? '${h.toString().padLeft(2, '0')}:00' : '',
                      style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildHourColumn(
    int hour,
    List<HourlyAppUsage> apps,
    int maxHourTotal,
    List<String> packages,
  ) {
    final total = apps.fold<int>(0, (sum, e) => sum + e.duration);
    // 列高度按该小时总时长占峰值小时的比例缩放
    final height = maxHourTotal == 0
        ? 0.0
        : _chartHeight * total / maxHourTotal;

    return GestureDetector(
      onTap: apps.isEmpty ? null : () => onHourTap?.call(hour, apps),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: apps
              .map(
                (u) => Expanded(
                  flex: u.duration,
                  child: _buildSegment(u, packages),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  /// 单个 App 色块：足够高时在块内标注 App 名称（昵称）
  Widget _buildSegment(HourlyAppUsage u, List<String> packages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel = constraints.maxHeight >= 18;
        return Container(
          color: appColorFor(u.packageName, packages),
          alignment: Alignment.center,
          child: showLabel
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      u.appName,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
