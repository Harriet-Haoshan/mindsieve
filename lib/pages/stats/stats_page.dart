import 'package:flutter/material.dart';

import 'daily_stats.dart';
import 'monthly_stats.dart';
import 'weekly_stats.dart';
import 'yearly_stats.dart';

/// 统计复盘主页面：天 / 周 / 月 / 年 四个视图切换
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('时间统计复盘', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: '天'),
              Tab(text: '周'),
              Tab(text: '月'),
              Tab(text: '年'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DailyStatsView(),
            WeeklyStatsView(),
            MonthlyStatsView(),
            YearlyStatsView(),
          ],
        ),
      ),
    );
  }
}
