import 'package:flutter/material.dart';

import '../../models/app_stats.dart';
import '../../services/stats_service.dart';
import 'bar_totals_chart.dart';

/// 周视图：周一～周日每天总使用时长柱状图
class WeeklyStatsView extends StatefulWidget {
  const WeeklyStatsView({super.key});

  @override
  State<WeeklyStatsView> createState() => _WeeklyStatsViewState();
}

class _WeeklyStatsViewState extends State<WeeklyStatsView> {
  final StatsService _stats = StatsService();
  bool _isLoading = true;
  List<TimeBucketStats> _data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _stats.getWeekDailyTotals();
    if (!mounted) return;
    setState(() {
      _data = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _data.fold<int>(0, (sum, e) => sum + e.duration);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard('本周总时长', formatDuration(total)),
          const SizedBox(height: 20),
          const Text(
            '每日使用时长',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          BarTotalsChart(data: _data, labelInterval: 1, rodWidth: 22),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String label, String value) {
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
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}
