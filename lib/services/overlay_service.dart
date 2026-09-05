import 'package:flutter/material.dart';

/// 悬浮窗内容配置
class OverlayConfig {
  final String appName;
  final String todayUsage;
  final VoidCallback onContinue;
  final VoidCallback onTimer;
  final VoidCallback onExit;

  OverlayConfig({
    required this.appName,
    required this.todayUsage,
    required this.onContinue,
    required this.onTimer,
    required this.onExit,
  });
}

/// 注意力哨兵悬浮窗服务
///
/// 不使用 OverlayEntry（静态持有 entry + Overlay.of(context) 的方式，
/// 在页面销毁或热重载后会触发 '_dependents.isEmpty' 等框架断言），
/// 改为全局 ValueNotifier + 常驻悬浮层（OverlayHost）：
/// 显示/隐藏只改通知器状态，完全不依赖任何页面的 BuildContext。
class OverlayService {
  static final ValueNotifier<OverlayConfig?> _config =
      ValueNotifier<OverlayConfig?>(null);

  /// 显示悬浮窗
  static void showOverlay({
    required String appName,
    required String todayUsage,
    required VoidCallback onContinue,
    required VoidCallback onTimer,
    required VoidCallback onExit,
  }) {
    _config.value = OverlayConfig(
      appName: appName,
      todayUsage: todayUsage,
      onContinue: onContinue,
      onTimer: onTimer,
      onExit: onExit,
    );
  }

  /// 移除悬浮窗
  static void dismiss() {
    _config.value = null;
  }

  /// 当前是否正在显示悬浮窗（用于避免重复弹出）
  static bool get isShowing => _config.value != null;
}

/// 常驻悬浮层：挂在 MaterialApp.builder 中，位于所有页面之上。
/// 由 MaterialApp 持有，与各页面生命周期完全解耦，永不销毁。
class OverlayHost extends StatelessWidget {
  final Widget? child;

  const OverlayHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OverlayConfig?>(
      valueListenable: OverlayService._config,
      // 把应用内容（Navigator）作为 child 传入，
      // 这样悬浮窗状态变化时不会重建整个应用
      child: child,
      builder: (context, config, page) {
        return Stack(
          children: [
            if (page != null) page,
            // 半透明遮罩：突出悬浮窗并阻止误触下层页面
            if (config != null)
              const Positioned.fill(
                child: ModalBarrier(dismissible: false, color: Colors.black54),
              ),
            if (config != null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '🧘 注意力的哨声',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '你正在打开 " ${config.appName} "',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '今日已使用: ${config.todayUsage}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildButton('继续', Colors.green, config.onContinue),
                            _buildButton(
                              '⏱ 5分钟',
                              Colors.orange,
                              config.onTimer,
                            ),
                            _buildButton('退出', Colors.red, config.onExit),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 构建按钮
  static Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}
