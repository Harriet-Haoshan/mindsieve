import 'package:flutter/material.dart';
import '../../database/app_dao.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppDao _dao = AppDao();

  /// 各预设 App 的开关状态：packageName -> enabled
  final Map<String, bool> _enabledMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _dao.getControlledApps();
    // 查询期间页面可能已被销毁（快速切换 Tab 时），不再 setState
    if (!mounted) return;
    setState(() {
      _enabledMap
        ..clear()
        ..addEntries(
          apps.map(
            (a) => MapEntry(a['package_name'] as String, a['enabled'] == 1),
          ),
        );
      _isLoading = false;
    });
  }

  /// 开关切换：先乐观更新 UI 保证跟手，再持久化到数据库
  Future<void> _setEnabled(String packageName, bool enabled) async {
    setState(() => _enabledMap[packageName] = enabled);
    await _dao.setAppEnabled(packageName, enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('监控列表'),
                  ...AppDao.presetApps.map(_buildAppTile),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '提示',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '打开 App 时会自动记录使用时长，无需手动检测\n'
                          '首次使用请在主页授予「使用情况访问」权限\n'
                          '打开开关表示监控该 App，关闭开关后该 App 不再被监测',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAppTile(({String packageName, String appName}) app) {
    final enabled = _enabledMap[app.packageName] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? Colors.blue.withOpacity(0.3) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                app.appName.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              app.appName,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) => _setEnabled(app.packageName, v),
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}
