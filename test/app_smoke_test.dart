import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:we_reader/core/storage/local_store.dart';
import 'package:we_reader/features/reader/reader_page.dart';
import 'package:we_reader/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('书架 → 打开内置指南 → 阅读器分页渲染', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();

    await tester.pumpWidget(WeReaderApp(store: store));
    await tester.pumpAndSettle();

    // 首次启动书架应有内置《使用指南》。
    expect(find.text('微读使用指南'), findsOneWidget);

    // 打开阅读器,等待内容加载与分页完成。
    await tester.tap(find.text('微读使用指南'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.byType(ReaderPage), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    // 首章标题渲染在第一页。
    expect(find.text('欢迎使用微读'), findsWidgets);
  });
}
