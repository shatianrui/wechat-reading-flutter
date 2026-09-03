import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/library_controller.dart';
import '../../core/theme/app_theme.dart';

/// 个人中心:账号占位、阅读统计、会员占位。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final stats = library.stats;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('我')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // 账号 stub:v2 接入真实登录(微信/Apple ID)。
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(CupertinoIcons.person_fill,
                    color: scheme.primary, size: 28),
              ),
              title: const Text('书友',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: const Text('本地模式 · 点击登录(即将上线)',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
              onTap: () => _toast(context, '账号系统开发中,当前数据保存在本机'),
            ),
          ),
          const SizedBox(height: 14),
          // 阅读统计。
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('阅读统计',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatItem(
                          label: '今日阅读',
                          value: formatDuration(stats.todaySeconds)),
                      _StatItem(
                          label: '累计阅读',
                          value: formatDuration(stats.totalSeconds)),
                      _StatItem(
                          label: '听书时长',
                          value: formatDuration(stats.listenSeconds)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _StatItem(label: '书架藏书', value: '${library.books.length}本'),
                      _StatItem(
                          label: '笔记划线',
                          value: '${library.annotations.length}条'),
                      _StatItem(
                          label: '读完书籍', value: '${stats.finishedBooks}本'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 会员占位。
          Card(
            color: const Color(0xFF2E3440),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(CupertinoIcons.rosette,
                  color: Color(0xFFE7C888), size: 30),
              title: const Text('无限卡会员',
                  style: TextStyle(
                      color: Color(0xFFE7C888),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              subtitle: Text('海量书库畅读特权 · 敬请期待',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12)),
              onTap: () => _toast(context, '会员体系规划中'),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _MenuTile(
                  icon: CupertinoIcons.cloud,
                  title: '云同步',
                  subtitle: '进度与笔记多端同步(规划中)',
                  onTap: () =>
                      _toast(context, '将采用最新时间戳优先策略合并多端数据'),
                ),
                const Divider(height: 1, indent: 52),
                _MenuTile(
                  icon: CupertinoIcons.info_circle,
                  title: '关于微读',
                  subtitle: 'MVP v0.1 · 本地阅读 + 系统 TTS',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: '微读',
                    applicationVersion: '0.1.0',
                    children: const [
                      Text('微信读书风格的开源阅读应用示例。\n支持导入 EPUB/TXT,本地阅读与听书。'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 22, color: scheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
      onTap: onTap,
    );
  }
}
