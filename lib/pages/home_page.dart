import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../agent/attention_agent.dart';
import '../services/overlay_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToStats;

  const HomePage({super.key, this.onNavigateToStats});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UsageService _usageService = UsageService();
  final AttentionAgent _agent = AttentionAgent();
  String _status = '等待检测...';
  final TextEditingController _searchController = TextEditingController();

  Future<void> _checkForegroundApp() async {
    setState(() {
      _status = '检测中...';
    });

    final mockPackageName = 'com.ss.android.ugc.aweme';
    final mockAppName = '抖音';

    await _usageService.logAppOpen(mockPackageName, mockAppName);
    await _usageService.addMockUsage(mockPackageName, mockAppName, 60);

    final (shouldShow, message) = await _agent.shouldIntervene(
      mockPackageName,
      mockAppName,
    );

    if (!mounted) return;

    setState(() {
      _status = '当前: 抖音 (⚠️ 黑洞App)';
    });

    if (shouldShow) {
      final todayUsage = await _usageService.getTodayUsage(mockPackageName);
      final usageStr = _formatDuration(todayUsage);

      OverlayService.showOverlay(
        context,
        appName: mockAppName,
        todayUsage: usageStr,
        onContinue: () {
          OverlayService.dismiss();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('继续使用')));
        },
        onTimer: () {
          OverlayService.dismiss();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('5分钟后将再次提醒你！')));
          Future.delayed(const Duration(minutes: 5), () {
            OverlayService.showOverlay(
              context,
              appName: '抖音',
              todayUsage: '5分钟前你选择了继续使用',
              onContinue: () {
                OverlayService.dismiss();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('继续使用')));
              },
              onTimer: () {
                OverlayService.dismiss();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('再给你5分钟！')));
              },
              onExit: () {
                OverlayService.dismiss();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已退出，回到桌面')));
              },
            );
          });
        },
        onExit: () {
          OverlayService.dismiss();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已退出，回到桌面')));
        },
      );
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    return '$minutes分钟';
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🧠 MindSieve',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 40),
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
                    child: _buildChip('今日报告'),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _checkForegroundApp,
                    child: _buildChip('检测'),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
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
