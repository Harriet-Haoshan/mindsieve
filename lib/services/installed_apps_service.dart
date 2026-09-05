import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// 已安装应用信息（添加 App 选择器用）
class InstalledApp {
  final String packageName;
  final String appName;

  /// 应用图标 PNG 字节流（原生侧渲染后 Base64 传回），可能为 null
  final Uint8List? icon;

  InstalledApp({
    required this.packageName,
    required this.appName,
    this.icon,
  });
}

/// 已安装应用查询服务：复用 mindsieve/usage 原生通道
class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel('mindsieve/usage');

  /// 获取手机中已安装的第三方应用（系统应用已在原生侧过滤）
  Future<List<InstalledApp>> getInstalledApps() async {
    final raw =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>(
          'getInstalledApps',
        ) ??
        const [];

    return raw.map((e) {
      final iconBase64 = e['icon'] as String?;
      return InstalledApp(
        packageName: e['packageName'] as String,
        appName: e['appName'] as String,
        icon: (iconBase64 != null && iconBase64.isNotEmpty)
            ? base64Decode(iconBase64)
            : null,
      );
    }).toList();
  }
}
