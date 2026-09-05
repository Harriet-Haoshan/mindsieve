import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class UsagePieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double height;

  const UsagePieChart({
    super.key,
    required this.data,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: const Text(
          '暂无数据\n点击「检测」开始记录',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 60,
          sections: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final percentage = item['percentage'] as double;
            final color = colors[index % colors.length];

            return PieChartSectionData(
              color: color,
              value: percentage,
              title: percentage > 5
                  ? '${percentage.toStringAsFixed(0)}%'
                  : '',
              radius: 50,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
