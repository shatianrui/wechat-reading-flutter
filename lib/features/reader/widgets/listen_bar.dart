import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/reader_settings.dart';
import '../tts_controller.dart';

/// 听书控制条:播放/暂停、上一句/下一句、语速、退出。
/// 常驻于听书模式底部,不随工具栏隐藏。
class ListenBar extends StatelessWidget {
  const ListenBar({
    super.key,
    required this.tts,
    required this.theme,
    required this.onRateChanged,
    required this.onExit,
  });

  final TtsController tts;
  final ReaderTheme theme;
  final ValueChanged<double> onRateChanged;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF4C8AF0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.5 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 语速。
          GestureDetector(
            onTap: () => _showRateMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${(tts.rate * 2).toStringAsFixed(1)}x',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.text),
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(CupertinoIcons.backward_end,
                size: 18, color: theme.text),
            tooltip: '上一句',
            onPressed: () => tts.skipSentence(-1),
          ),
          GestureDetector(
            onTap: tts.toggle,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Icon(
                tts.playing
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          IconButton(
            icon:
                Icon(CupertinoIcons.forward_end, size: 18, color: theme.text),
            tooltip: '下一句',
            onPressed: () => tts.skipSentence(1),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(CupertinoIcons.xmark_circle,
                size: 22, color: theme.secondaryText),
            tooltip: '退出听书',
            onPressed: onExit,
          ),
        ],
      ),
    );
  }

  void _showRateMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('朗读语速',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.text)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  for (final display in const [0.6, 0.8, 1.0, 1.2, 1.5, 2.0])
                    _RateChip(
                      display: display,
                      selected: ((tts.rate * 2) - display).abs() < 0.05,
                      theme: theme,
                      onTap: () {
                        onRateChanged(display / 2);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({
    required this.display,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final double display;
  final bool selected;
  final ReaderTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4C8AF0).withValues(alpha: 0.15)
              : theme.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${display}x',
          style: TextStyle(
            fontSize: 13,
            color: selected ? const Color(0xFF4C8AF0) : theme.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
