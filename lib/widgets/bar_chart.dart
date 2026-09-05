import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/app_stats.dart';

class HourlyBarChart extends StatelessWidget {
  final List<HourlyStats> data;
  final double height;

  const HourlyBarChart({super.key, required this.data, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: const Text('暂无时段数据', style: TextStyle(color: Colors.white54)),
      );
    }

    final maxDuration = data.fold<int>(
      0,
      (max, e) => e.duration > max ? e.duration : max,
    );

    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxDuration > 0 ? maxDuration * 1.2 : 10,
          barGroups: data.map((item) {
            return BarChartGroupData(
              x: item.hour,
              barRods: [
                BarChartRodData(
                  toY: item.duration.toDouble(),
                  color: Colors.blue,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${value.toInt()}时',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 600 == 0) {
                    return Text(
                      '${(value / 60).toInt()}m',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: Colors.white12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
