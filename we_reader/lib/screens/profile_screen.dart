import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// 「我」页：本地阅读统计 + 设置入口占位。
///
/// 未来云同步方案：登录后将 shared_preferences 中的进度 / 标注 / 统计
/// 上传服务端，按条目 updatedAt「最新时间戳获胜」做双向合并。
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes 分钟';
    return '${(minutes / 60).toStringAsFixed(1)} 小时';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('我')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户信息占位（MVP 无登录体系）。
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person, size: 32, color: primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '本地读者',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '未登录 · 数据保存在本机',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 阅读统计。
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _StatItem(
                  value: _formatDuration(appState.totalReadingSeconds),
                  label: '总阅读时长',
                ),
                _StatItem(
                  value: _formatDuration(appState.todayReadingSeconds),
                  label: '今日阅读',
                ),
                _StatItem(value: '${appState.readingDays}', label: '阅读天数'),
                _StatItem(value: '${appState.noteCount}', label: '笔记'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 设置入口（占位）。
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _stubTile(context, Icons.cloud_outlined, '云同步',
                    '登录后自动同步进度与笔记（开发中）'),
                _stubTile(context, Icons.card_membership_outlined, '会员卡',
                    '畅读全场书籍（开发中）'),
                _stubTile(
                    context, Icons.settings_outlined, '设置', '通用设置（开发中）'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '微读 MVP · 数据仅存于本机',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stubTile(
      BuildContext context, IconData icon, String title, String message) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
