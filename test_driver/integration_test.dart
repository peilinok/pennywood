import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await Directory('evidence/screenshots').create(recursive: true);
      await File('evidence/screenshots/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
