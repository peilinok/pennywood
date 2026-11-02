import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/main.dart';

// Use isolated acceptance files and credential namespaces; never clear production families.
class VerificationCredentials implements CredentialStore {
  final store = KeychainCredentials();
  @override
  Future<String?> read(String key) => store.read('wishboard-verification.$key');
  @override
  Future<void> write(String key, String value) =>
      store.write('wishboard-verification.$key', value);
}

Future<TownService> startWishboard({
  bool reset = false,
  bool demo = false,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final file = File(
    '${directory.path}/pennywood-wishboard-${demo ? 'finance' : 'acceptance'}.sqlite',
  );
  if (reset && await file.exists()) await file.delete();
  final service = TownService(
    PennyDatabase.file(file),
    Auth(VerificationCredentials()),
    FixedClock('2026-11-01'),
  );
  if (demo && reset) {
    await service.createFamily('demo', '719385', ['示例栗栗', '示例桃桃'], demo: true);
  }
  runApp(PennywoodApp(service));
  return service;
}
