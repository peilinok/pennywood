import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'app/screens.dart';
import 'app/paper_theme.dart';
import 'data/auth.dart';
import 'data/database.dart';
import 'data/service.dart';
import 'domain/money.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final db = PennyDatabase.file(File('${directory.path}/pennywood.sqlite'));
  runApp(
    PennywoodApp(TownService(db, Auth(KeychainCredentials()), LocalClock())),
  );
}

class PennywoodApp extends StatelessWidget {
  const PennywoodApp(this.service, {super.key});
  final TownService service;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: paperThemeMode,
    builder: (context, mode, _) => MaterialApp(
      title: '栗子小镇 · Pennywood',
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: paperTheme(Brightness.light),
      darkTheme: paperTheme(Brightness.dark),
      themeMode: mode,
      home: FamilyEntry(service),
    ),
  );
}
