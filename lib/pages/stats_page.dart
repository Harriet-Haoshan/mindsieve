import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/ai_analysis_service.dart';
import '../models/app_stats.dart';
import '../widgets/pie_chart.dart';
import '../widgets/bar_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final AnalyticsService _analytics = AnalyticsService();
  final AiAnalysisService _aiService = AiAnalysisService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _breakdown = [];
  List<HourlyStats> _hourly = [];
  DailySummary? _summary;

  // AI 分析状态
  bool _aiLoading = false; // AI 分析中
  bool _aiFailed = false; // AI 调用失败（降级显示本地建议）
  bool _aiMissingKey = false; // API Key 未配置
  String? _aiResult; // AI 返回的分析文本

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final breakdown = await _analytics.getTodayUsageBreakdown();
      final hourly = await _analytics.getTodayHourlyDistribution();
      final summary = await _analytics.getTodaySummary();
      if (!mounted) return;
      setState(() {
        _breakdown = breakdown;
        _hourly = hourly;
        _summary = summary;
        _isLoading = false;
      });
      // 数据加载完成后，触发 AI 分析
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
        hourly: _hourly,
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('今日专注报告', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('各 App 使用占比'),
                  UsagePieChart(data: _breakdown),
                  const SizedBox(height: 8),
                  _buildLegend(),
                  const SizedBox(height: 20),
                  _buildSectionTitle('24小时使用分布'),
                  HourlyBarChart(data: _hourly),
                  const SizedBox(height: 20),
                  _buildSectionHeader('智能分析'),
                  _buildAiAnalysis(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

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
          _buildStatItem('总时长', total),
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

  Widget _buildLegend() {
    if (_breakdown.isEmpty) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: _breakdown.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final app = item['app'];
        final percentage = item['percentage'] as double;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${app.appName} ${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// 带刷新按钮的区块标题（用于智能分析，可手动重新触发 AI）
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
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
          '暂无数据，点击主页「检测」开始记录',
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
