import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/foreground_monitor.dart';
import '../widgets/permission_guide_cards.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToStats;

  const HomePage({super.key, this.onNavigateToStats});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ForegroundMonitor _monitor = ForegroundMonitor();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入搜索关键词')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('选择要搜索的平台', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAppOption('抖音', () {
              Navigator.pop(context);
              _openApp(
                'snssdk1128://search?keyword=',
                'com.ss.android.ugc.aweme',
                query,
              );
            }),
            const SizedBox(height: 12),
            _buildAppOption('小红书', () {
              Navigator.pop(context);
              _openApp(
                'xhsdiscover://search?keyword=',
                'com.xingin.xhs',
                query,
              );
            }),
            const SizedBox(height: 12),
            _buildAppOption('B站', () {
              Navigator.pop(context);
              _openApp('bilibili://search?keyword=', 'tv.danmaku.bili', query);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAppOption(String name, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _openApp(String scheme, String packageName, String query) async {
    final encoded = Uri.encodeComponent(query);
    final uri = Uri.parse('$scheme$encoded');

    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}

    final webUrl = _getWebUrl(packageName, query);
    if (webUrl != null) {
      await launchUrl(Uri.parse(webUrl));
    }
  }

  String? _getWebUrl(String packageName, String query) {
    final encoded = Uri.encodeComponent(query);
    switch (packageName) {
      case 'com.ss.android.ugc.aweme':
        return 'https://www.douyin.com/search/$encoded';
      case 'com.xingin.xhs':
        return 'https://www.xiaohongshu.com/search_result?keyword=$encoded';
      case 'tv.danmaku.bili':
        return 'https://search.bilibili.com/all?keyword=$encoded';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text(
                '🧠 MindSieve',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              // 权限引导卡片：未授予「使用情况访问」权限时显示，授权后自动隐藏
              const PermissionGuideCards(),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    hintText: '搜索... 输入关键词，选择App跳转',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 20,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 28,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white54,
                      ),
                      onPressed: _onSearchSubmitted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),
                  ),
                  onSubmitted: (_) => _onSearchSubmitted(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildChip('闪念笔记'),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => widget.onNavigateToStats?.call(),
                    child: _buildChip('统计复盘'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              // 自动监控状态：实时显示最近记录 / 授权提示
              ValueListenableBuilder<String>(
                valueListenable: _monitor.status,
                builder: (context, status, _) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
