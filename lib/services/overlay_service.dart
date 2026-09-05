import 'package:flutter/material.dart';

class OverlayService {
  static OverlayEntry? _overlayEntry;

  /// 显示悬浮窗
  static void showOverlay(
    BuildContext context, {
    required String appName,
    required String todayUsage,
    required VoidCallback onContinue,
    required VoidCallback onTimer,
    required VoidCallback onExit,
  }) {
    // 移除旧的悬浮窗
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
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
              border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
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
                  '你正在打开 " $appName "',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '今日已使用: $todayUsage',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildButton('继续', Colors.green, onContinue),
                    _buildButton('⏱ 5分钟', Colors.orange, onTimer),
                    _buildButton('退出', Colors.red, onExit),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // 插入悬浮窗
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 移除悬浮窗
  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// 构建按钮
  static Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }
}