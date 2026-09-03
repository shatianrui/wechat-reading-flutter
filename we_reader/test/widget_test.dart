import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:we_reader/main.dart';

void main() {
  testWidgets('应用启动后显示底部三个 Tab', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(WeReaderApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('发现'), findsWidgets);
    expect(find.text('书架'), findsWidgets);
    expect(find.text('我'), findsWidgets);
  });
}
