import 'package:flutter/material.dart';

import '../database/app_dao.dart';
import '../services/foreground_monitor.dart';

/// 主页权限状态汇总卡片
///
/// 列出 3 项关键权限：
/// 1. 使用情况访问（必须）—— 自动记录 App 使用时长
/// 2. 允许后台活动（必须）—— 息屏后继续记录；非华为默认允许，
///    华为因系统不提供查询 API，用户点击跳转设置后乐观标记为已开启
/// 3. 忽略电池优化（建议）—— 防止系统清理后台进程
///
/// 每项：未开启红色 ❌，已开启绿色 ✅，点击跳转到对应系统设置页。
/// 三项全部开启后，卡片自动隐藏（SizedBox.shrink）。
///
/// 状态刷新时机：initState、App 从后台恢复（resumed），以及两个
/// ValueNotifier 变化时自动重建。
class PermissionSummaryCard extends StatefulWidget {
  const PermissionSummaryCard({super.key});

  @override
  State<PermissionSummaryCard> createState() => _PermissionSummaryCardState();
}

class _PermissionSummaryCardState extends State<PermissionSummaryCard>
    with WidgetsBindingObserver {
  final ForegroundMonitor _monitor = ForegroundMonitor();
  final AppDao _dao = AppDao();

  bool _isHuawei = false;
  // 华为「允许后台活动」是否已由用户确认开启（持久化在 meta 表）
  bool _bgConfirmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _monitor.hasPermission.addListener(_onStateChanged);
    _monitor.ignoreBatteryOptimization.addListener(_onStateChanged);
    _refreshAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor.hasPermission.removeListener(_onStateChanged);
    _monitor.ignoreBatteryOptimization.removeListener(_onStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置页返回 App 时重新拉取所有权限状态
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshAll() async {
    _isHuawei = await _monitor.isHuaweiDevice();
    if (_isHuawei) {
      final saved = await _dao.getMeta('huawei_bg_confirmed');
      _bgConfirmed = saved == '1';
    }
    await _monitor.refreshPermissions();
    if (!mounted) return;
    setState(() {});
  }

  /// 「允许后台活动」是否已开启：
  /// - 非华为设备：系统无此独立开关，默认允许后台运行
  /// - 华为设备：读取用户确认标记（该开关系统无查询 API）
  bool get _bgAllowed => !_isHuawei || _bgConfirmed;

  Future<void> _openBackgroundSettings() async {
    await _monitor.openBatterySettings();
    if (_isHuawei && !_bgConfirmed) {
      // 华为后台活动开关无法自动检测，用户跳转到设置后乐观标记为已开启
      await _dao.setMeta('huawei_bg_confirmed', '1');
      if (!mounted) return;
      setState(() => _bgConfirmed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usageOn = _monitor.hasPermission.value;
    final bgOn = _bgAllowed;
    final batteryOn = _monitor.ignoreBatteryOptimization.value;

    // 三项全部开启 → 卡片自动消失
    if (usageOn && bgOn && batteryOn) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              const Text(
                '权限状态',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildItem(
            name: '使用情况访问',
            desc: '自动记录 App 使用时长（必须）',
            on: usageOn,
            icon: Icons.security,
            onTap: _monitor.openPermissionSettings,
          ),
          _buildItem(
            name: '允许后台活动',
            desc: _isHuawei ? '息屏后继续记录（必须）' : '已默认允许',
            on: bgOn,
            icon: Icons.battery_charging_full,
            onTap: _openBackgroundSettings,
          ),
          _buildItem(
            name: '忽略电池优化',
            desc: '防止系统清理后台进程（建议）',
            on: batteryOn,
            icon: Icons.battery_saver,
            onTap: _monitor.openIgnoreBatteryOptimizationSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String name,
    required String desc,
    required bool on,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: on ? Colors.green : Colors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: on ? Colors.white : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Text(
              on ? '✅ 已开启' : '❌ 未开启',
              style: TextStyle(
                color: on ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }
}
