import 'package:flutter/material.dart';
import '../../database/app_dao.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AppDao _dao = AppDao();
  List<Map<String, dynamic>> _apps = [];
  bool _isLoading = true;

  // 对话框输入控制器由 State 统一持有，避免在对话框退出动画期间
  // 提前 dispose（曾触发 framework 的 _dependents.isEmpty 断言）
  TextEditingController? _nicknameController;
  TextEditingController? _addNameController;
  TextEditingController? _addPackageController;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _nicknameController?.dispose();
    _addNameController?.dispose();
    _addPackageController?.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    final apps = await _dao.getControlledApps();
    // 查询期间页面可能已被销毁（快速切换 Tab 时），不再 setState
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _isLoading = false;
    });
  }

  /// 增删改后静默刷新列表（不切 loading 骨架，避免对话框退出动画期间
  /// body 子树剧烈更换导致的 Element deactivate 顺序异常）
  Future<void> _refreshApps() async {
    final apps = await _dao.getControlledApps();
    if (!mounted) return;
    setState(() => _apps = apps);
  }

  Future<void> _addApp(String packageName, String appName) async {
    // 预捕获 messenger：数据库操作后页面 context 仍可能处于重建中
    final messenger = ScaffoldMessenger.of(context);
    await _dao.addControlledApp(packageName, appName);
    await _refreshApps();
    messenger.showSnackBar(SnackBar(content: Text('已添加 $appName')));
  }

  Future<void> _removeApp(String packageName, String appName) async {
    final messenger = ScaffoldMessenger.of(context);
    await _dao.removeControlledApp(packageName);
    await _refreshApps();
    messenger.showSnackBar(SnackBar(content: Text('已移除 $appName')));
  }

  Future<void> _toggleApp(String packageName) async {
    await _dao.toggleControlledApp(packageName);
    await _refreshApps();
  }

  /// 弹窗修改 App 昵称（留空保存则清除昵称，回退显示系统名称）
  Future<void> _editNickname(Map<String, dynamic> app) async {
    final appName = app['app_name'] as String? ?? '未知';
    // 预捕获 messenger：对话框关闭后 context 不再可靠
    final messenger = ScaffoldMessenger.of(context);

    _nicknameController?.dispose();
    _nicknameController = TextEditingController(
      text: app['nickname'] as String? ?? '',
    );
    final controller = _nicknameController!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '修改「$appName」的昵称',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '输入自定义昵称，留空则使用默认名称',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('保存', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final nickname = controller.text.trim();
    await _dao.setNickname(
      app['package_name'] as String,
      nickname.isEmpty ? null : nickname,
    );
    await _refreshApps();
    messenger.showSnackBar(
      SnackBar(
        content: Text(nickname.isEmpty ? '已恢复默认名称' : '昵称已更新为「$nickname」'),
      ),
    );
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
                  _buildSectionTitle('已控制的 App'),
                  if (_apps.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '还没有添加 App\n点击下方「添加」开始',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  else
                    ..._apps.map((app) => _buildAppTile(app)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddAppDialog,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('添加 App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
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
                          '点击 App 名称可修改昵称，统计图表会同步显示\n'
                          '关闭开关后，该 App 不再被监测',
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

  Widget _buildAppTile(Map<String, dynamic> app) {
    final enabled = app['enabled'] == 1;
    final appName = app['app_name'] as String? ?? '未知';
    final nickname = app['nickname'] as String?;
    final hasNickname = nickname != null && nickname.isNotEmpty;
    // 显示名：昵称优先；头像首字也取显示名
    final displayName = hasNickname ? nickname : appName;

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
                displayName.substring(0, 1),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 点击名称区域 → 修改昵称
          Expanded(
            child: GestureDetector(
              onTap: () => _editNickname(app),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.white38,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 13,
                        color: enabled ? Colors.white38 : Colors.white24,
                      ),
                    ],
                  ),
                  if (hasNickname)
                    Text(
                      appName,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => _toggleApp(app['package_name']),
            activeColor: Colors.blue,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 18),
            onPressed: () => _removeApp(app['package_name'], appName),
          ),
        ],
      ),
    );
  }

  // 弹出「添加 App」对话框，手动输入名称和包名
  Future<void> _showAddAppDialog() async {
    // 预捕获 messenger：对话框关闭后 context 不再可靠
    final messenger = ScaffoldMessenger.of(context);

    _addNameController?.dispose();
    _addPackageController?.dispose();
    _addNameController = TextEditingController();
    _addPackageController = TextEditingController();
    final nameController = _addNameController!;
    final packageController = _addPackageController!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '添加 App',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'App 名称，如：抖音',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white12),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: packageController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '包名，如：com.ss.android.ugc.aweme',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white12),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('添加', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final appName = nameController.text.trim();
    final packageName = packageController.text.trim();

    // 验证输入不为空
    if (appName.isEmpty || packageName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('App 名称和包名不能为空')),
      );
      return;
    }
    // 避免重复添加同一个包名
    if (_apps.any((a) => a['package_name'] == packageName)) {
      messenger.showSnackBar(SnackBar(content: Text('$appName 已在列表中')));
      return;
    }

    await _addApp(packageName, appName);
  }
}
