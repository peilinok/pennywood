import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pennywood/data/auth.dart';
import 'package:pennywood/data/database.dart';
import 'package:pennywood/data/service.dart';
import 'package:pennywood/domain/money.dart';
import 'package:pennywood/main.dart';

class FamilyVerificationCredentials implements CredentialStore {
  final store = KeychainCredentials();
  static const prefix = 'family-release-verification.';
  @override
  Future<String?> read(String key) => store.read('$prefix$key');
  @override
  Future<void> write(String key, String value) =>
      store.write('$prefix$key', value);
}

Future<TownService> startFamilyRelease({bool reset = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationSupportDirectory();
  final file = File(
    '${directory.path}/pennywood-family-release-verification.sqlite',
  );
  final credentials = FamilyVerificationCredentials();
  if (reset) {
    if (await file.exists()) await file.delete();
    // Reset only the two explicitly named test credentials; never call deleteAll.
    for (final key in ['pennywood.real', 'pennywood.recovery.real']) {
      await credentials.store.storage.delete(
        key: '${FamilyVerificationCredentials.prefix}$key',
      );
    }
  }
  final svc = TownService(
    PennyDatabase.file(file),
    Auth(credentials),
    FixedClock('2026-11-01'),
  );
  runApp(PennywoodApp(svc));
  return svc;
}
