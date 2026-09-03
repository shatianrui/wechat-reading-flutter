import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/state/reader_settings.dart';

/// 阅读设置面板:字号、行距、主题、翻页模式、字体。
Future<void> showReaderSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ReaderSettingsController>();
    final theme = settings.theme;
    final labelStyle = TextStyle(fontSize: 13, color: theme.secondaryText);

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 字号。
            Row(
              children: [
                SizedBox(width: 44, child: Text('字号', style: labelStyle)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StepButton(
                        label: 'A-',
                        theme: theme,
                        onTap: () => settings.fontSize = settings.fontSize - 1,
                      ),
                      Text(
                        settings.fontSize.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.text),
                      ),
                      _StepButton(
                        label: 'A+',
                        theme: theme,
                        onTap: () => settings.fontSize = settings.fontSize + 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 行距。
            Row(
              children: [
                SizedBox(width: 44, child: Text('行距', style: labelStyle)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final (label, value) in const [
                        ('紧凑', 1.6),
                        ('标准', 1.9),
                        ('宽松', 2.2),
                      ])
                        _ChoiceChip(
                          label: label,
                          selected:
                              (settings.lineHeight - value).abs() < 0.05,
                          theme: theme,
                          onTap: () => settings.lineHeight = value,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 主题。
            Row(
              children: [
                SizedBox(width: 44, child: Text('主题', style: labelStyle)),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final t in ReaderTheme.all)
                        GestureDetector(
                          onTap: () => settings.themeKind = t.kind,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: t.background,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: settings.theme.kind == t.kind ? 2 : 1,
                                    color: settings.theme.kind == t.kind
                                        ? const Color(0xFF4C8AF0)
                                        : theme.secondaryText
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text('文',
                                    style:
                                        TextStyle(color: t.text, fontSize: 15)),
                              ),
                              const SizedBox(height: 4),
                              Text(t.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: theme.secondaryText)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 翻页模式与字体。
            Row(
              children: [
                SizedBox(width: 44, child: Text('翻页', style: labelStyle)),
                Expanded(
                  child: Row(
                    children: [
                      _ChoiceChip(
                        label: '左右翻页',
                        selected: settings.pageMode == PageTurnMode.slide,
                        theme: theme,
                        onTap: () => settings.pageMode = PageTurnMode.slide,
                      ),
                      const SizedBox(width: 10),
                      _ChoiceChip(
                        label: '上下滚动',
                        selected: settings.pageMode == PageTurnMode.scroll,
                        theme: theme,
                        onTap: () => settings.pageMode = PageTurnMode.scroll,
                      ),
                      const Spacer(),
                      Text('衬线体', style: labelStyle),
                      const SizedBox(width: 6),
                      CupertinoSwitch(
                        value: settings.useSerif,
                        onChanged: (v) => settings.useSerif = v,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton(
      {required this.label, required this.theme, required this.onTap});

  final String label;
  final ReaderTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: theme.secondaryText.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.text)),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final String label;
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
              ? const Color(0xFF4C8AF0).withValues(alpha: 0.14)
              : theme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF4C8AF0)
                : theme.secondaryText.withValues(alpha: 0.25),
            width: selected ? 1.2 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? const Color(0xFF4C8AF0) : theme.text,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
