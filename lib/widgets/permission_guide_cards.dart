import 'package:flutter/material.dart';

import '../services/foreground_monitor.dart';

/// 权限引导卡片组（主页 / 设置页共用）
///
/// 包含：
/// 1. 「使用情况访问」权限卡：未授权时橙色警告 + 「去开启」；
///    已授权时默认隐藏，[showGrantedState] 为 true 时显示绿色正常状态。
/// 2. 华为/鸿蒙「后台活动」引导卡：仅华为设备显示（该开关系统不提供
///    查询 API，无法自动检测是否已开启，用户可在本次运行中临时关闭）。
///
/// 权限状态来自 [ForegroundMonitor] 单例：App 启动与从系统设置返回
/// （resumed）时都会重新检查，卡片通过 ValueNotifier 自动刷新。
class PermissionGuideCards extends StatefulWidget {
  /// 已授权时是否显示绿色「正常」状态卡（设置页用 true，主页用 false 直接隐藏）
  final bool showGrantedState;

  const PermissionGuideCards({super.key, this.showGrantedState = false});

  @override
  State<PermissionGuideCards> createState() => _PermissionGuideCardsState();
}

class _PermissionGuideCardsState extends State<PermissionGuideCards> {
  final ForegroundMonitor _monitor = ForegroundMonitor();

  bool _isHuawei = false;
  // 后台活动引导卡本次运行内是否被关闭（无法检测真实状态，下次启动重新提示）
  bool _batteryCardDismissed = false;

  @override
  void initState() {
    super.initState();
    _detectHuawei();
  }

  Future<void> _detectHuawei() async {
    final isHuawei = await _monitor.isHuaweiDevice();
    if (!mounted) return;
    setState(() => _isHuawei = isHuawei);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _monitor.hasPermission,
          builder: (context, granted, _) {
            if (granted) {
              return widget.showGrantedState
                  ? _buildUsageGrantedCard()
                  : const SizedBox.shrink();
            }
            return _buildUsageWarningCard();
          },
        ),
        if (_isHuawei && !_batteryCardDismissed) _buildHuaweiBatteryCard(),
      ],
    );
  }

  /// 未获得「使用情况访问」权限：橙色警告卡
  Widget _buildUsageWarningCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '需要「使用情况访问」权限\n开启后才能自动记录 App 使用时长',
              style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5),
            ),
          ),
          TextButton(
            onPressed: _monitor.openPermissionSettings,
            child: const Text(
              '去开启',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// 已获得权限：绿色正常状态卡（设置页展示，给用户确认感）
  Widget _buildUsageGrantedCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '「使用情况访问」权限已开启\n正在自动记录 App 使用时长',
              style: TextStyle(color: Colors.green, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 华为/鸿蒙专属：后台活动引导卡
  Widget _buildHuaweiBatteryCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.battery_saver, color: Colors.blue, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '请允许 MindSieve 后台活动',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _batteryCardDismissed = true),
                child: const Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '华为/鸿蒙系统默认限制应用后台运行，息屏后可能无法记录使用时长。\n'
            '请在打开的页面中找到 MindSieve，将「应用启动管理」设为手动，'
            '并打开「允许后台活动」。',
            style: TextStyle(color: Colors.blue, fontSize: 12, height: 1.5),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _monitor.openBatterySettings,
              child: const Text(
                '去开启',
                style: TextStyle(color: Colors.blue, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
