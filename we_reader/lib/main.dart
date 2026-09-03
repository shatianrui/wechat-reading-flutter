import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_state.dart';
import 'providers/reader_settings.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(WeReaderApp(prefs: prefs));
}

/// 主色：微信读书风格的蓝。
const Color kBrandColor = Color(0xFF3B6EFF);

class WeReaderApp extends StatelessWidget {
  const WeReaderApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(prefs)),
        ChangeNotifierProvider(create: (_) => ReaderSettings(prefs)),
      ],
      child: MaterialApp(
        title: '微读',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kBrandColor,
            surface: const Color(0xFFF7F7F7),
          ),
          scaffoldBackgroundColor: const Color(0xFFF7F7F7),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F7F7),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
          ),
          // iOS 风格的页面切换动画（iOS 优先的交互体验）。
          pageTransitionsTheme: PageTransitionsTheme(
            builders: {
              TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
