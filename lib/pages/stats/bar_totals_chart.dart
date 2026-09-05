import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/app_stats.dart';

/// 周 / 月 / 年视图共用的「每日 / 每月总时长」柱状图
class BarTotalsChart extends StatelessWidget {
  /// 每个时间桶的时长（秒），顺序即横轴顺序
  final List<TimeBucketStats> data;

  /// 横轴标签步进（1=每个都显示；月视图 31 个桶建议传 5）
  final double labelInterval;

  /// 柱子宽度（桶越多越窄）
  final double rodWidth;

  const BarTotalsChart({
    super.key,
    required this.data,
    this.labelInterval = 1,
    this.rodWidth = 18,
  });

  @override
  Widget build(BuildContext context) {
    final maxSeconds = data.fold<int>(
      0,
      (max, e) => e.duration > max ? e.duration : max,
    );
    // 纵轴以「分钟」为单位，顶部留 20% 余量
    final maxMinutes = (maxSeconds / 60 * 1.2).clamp(10, double.infinity);

    if (maxSeconds == 0) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '暂无使用记录\n使用被监控的 App 后将自动记录',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, height: 1.6),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxMinutes.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 30,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 30,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.toInt()}分',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: labelInterval,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.grey[900]!,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final bucket = data[group.x.toInt()];
                return BarTooltipItem(
                  '${bucket.label}\n${formatDuration(bucket.duration)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final bucket = entry.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bucket.duration / 60,
                  width: rodWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
