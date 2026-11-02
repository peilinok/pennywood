import 'dart:io';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:pennywood/data/database.dart';
import '../fixtures/schema5_family.dart';

// The schema is frozen before the experience migration; production migrations never create this class.
class Schema5Database extends PennyDatabase {
  Schema5Database(super.executor);
  @override
  int get schemaVersion => 5;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      for (final sql in [
        ...PennyDatabase.schema,
        ...PennyDatabase.wishboardSchema,
        ...PennyDatabase.familySchema,
        ...PennyDatabase.wishFinanceSchema,
      ]) {
        await customStatement(sql);
      }
    },
  );
}

Future<void> createSchema5Fixture(File file) async {
  final old = Schema5Database(NativeDatabase(file));
  try {
    await old.transaction(() async {
      for (final entry in schema5Fixture.entries) {
        for (final row in entry.value) {
          await old.customStatement(
            'INSERT INTO ${entry.key} (${row.keys.join(',')}) VALUES (${row.keys.map((_) => '?').join(',')})',
            row.values.toList(),
          );
        }
      }
      // A second independent account adds a live fixed promise and a conflicting future family template.
      await old.customStatement(
        "UPDATE children SET wallet=15000,labor_total=20000,budget=1000,rate_bps=300 WHERE id='second'",
      );
      await old.customStatement(
        "INSERT INTO positions VALUES('real','second','old-position','sprout',5000,300,90,'2026-11-01','2027-01-30',37,'cash','active',1)",
      );
      await old.customStatement(
        "INSERT INTO ledger VALUES('real','second','old-income','2026-11-01','income','现实劳动',20000,'old-task','legacy-source','parent')",
      );
      await old.customStatement(
        "INSERT INTO operations VALUES('real','second','legacy-source','[\"pay\",[\"old-task\"]]','old-task','2026-11-01')",
      );
      await old.customStatement(
        "UPDATE quick_tasks SET amount=300,enabled=1 WHERE child_id='second' AND id='dishes'",
      );
    });
  } finally {
    await old.close();
  }
}
