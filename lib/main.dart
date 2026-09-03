import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/state/library_controller.dart';
import 'core/state/reader_settings.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  final store = await LocalStore.open();
  runApp(WeReaderApp(store: store));
}

class WeReaderApp extends StatelessWidget {
  const WeReaderApp({super.key, required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => LibraryController(store)..load()),
        ChangeNotifierProvider(create: (_) => ReaderSettingsController(store)),
      ],
      child: MaterialApp(
        title: '微读',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
  }
}
