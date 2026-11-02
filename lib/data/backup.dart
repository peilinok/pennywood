import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import '../domain/money.dart';
import 'auth.dart';
import 'database.dart';

// Explicit backup/recovery only; daily operations still use per-command TownService transactions.
// Archives contain normalized table rows and idempotency IDs, never Keychain credentials.
class VerifiedBackup {
  VerifiedBackup._(this._rows, this.exportedOn, this._password);
  final Map<String, List<Map<String, dynamic>>> _rows;
  final String exportedOn, _password;
  Map<String, dynamic> get _family => _rows['families']!.single;
  String get family => _family['id'] as String;
  String get identity => _family['global_id'] as String;
  bool get demo => _family['demo'] == 1;
  List<String> get children =>
      _rows['children']!.map((r) => r['name'] as String).toList();
  int get entries => _rows['ledger']!.length;
}

class FamilyBackup {
  FamilyBackup(this.db, this.auth);
  final PennyDatabase db;
  final Auth auth;
  static const _tables = [
    'families',
    'children',
    'tasks',
    'wishes',
    'quick_tasks',
    'positions',
    'withdrawals',
    'loans',
    'installments',
    'repayments',
    'ledger',
    'operations',
    'scenes',
    'visits',
    'wish_withdrawals',
    'wish_loans',
  ];
  static const _limit = 20 * 1024 * 1024;
  static const _header = 'Pennywood-encrypted-backup:1:schema5';
  static const _legacyHeader = 'Pennywood-encrypted-backup:1:schema4';
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  static final _cipher = AesGcm.with256bits();

  Future<Uint8List> export(Access access, String password) async {
    auth.check(access, parent: true);
    require(
      password.length >= 10 && password.length <= 256,
      '请使用 10–256 位备份密码，与家长口令分开保管',
    );
    final data = await db.transaction(() async {
      auth.check(access, parent: true);
      final data = <String, List<Map<String, dynamic>>>{};
      for (final table in _tables) {
        data[table] = await db.rows(
          'SELECT * FROM $table WHERE ${table == 'families' ? 'id' : 'family_id'}=? ORDER BY rowid',
          [access.family],
        );
      }
      return data;
    });
    final plain = utf8.encode(
      jsonEncode({
        'exportedOn': DateTime.now().toUtc().toIso8601String(),
        'tables': data,
      }),
    );
    require(plain.length <= _limit ~/ 2, '备份超过当前版本大小上限，原账本保留');
    final salt = List.generate(24, (_) => Random.secure().nextInt(256));
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(
      plain,
      secretKey: key,
      aad: utf8.encode(_header),
    );
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _header,
          'salt': base64Encode(salt),
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
          'ciphertext': base64Encode(box.cipherText),
        }),
      ),
    );
  }

  Future<VerifiedBackup> read(Uint8List bytes, String password) async {
    require(bytes.length <= _limit, '备份文件过大，原账本未改变');
    try {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final header = envelope['format'];
      require(header == _header || header == _legacyHeader, '不支持此备份版本，原账本未改变');
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      require(
        salt.length == 24 && nonce.length == 12 && mac.length == 16,
        '备份校验未通过',
      );
      final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final plain = await _cipher.decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: nonce,
          mac: Mac(mac),
        ),
        secretKey: key,
        aad: utf8.encode(header as String),
      );
      final payload = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final tables = payload['tables'] as Map<String, dynamic>;
      final expectedTables = header == _legacyHeader
          ? _tables.sublist(0, _tables.length - 2)
          : _tables;
      require(
        tables.length == expectedTables.length &&
            tables.keys.every(expectedTables.contains),
        '备份表不完整或含未知记录',
      );
      final rows = <String, List<Map<String, dynamic>>>{};
      for (final table in expectedTables) {
        rows[table] = List.unmodifiable(
          (tables[table] as List).map(
            (r) => Map<String, dynamic>.unmodifiable(r as Map<String, dynamic>),
          ),
        );
      }
      if (header == _legacyHeader) {
        // Decrypt legacy ciphertext with its original authenticated header, reconstruct relations before validation, and never rewrite the source file.
        for (final (table, column) in [
          ('wish_withdrawals', 'withdrawal_id'),
          ('wish_loans', 'loan_id'),
        ]) {
          rows[table] = [
            for (final wish in rows['wishes']!)
              if (wish[column] != null)
                {
                  'family_id': wish['family_id'],
                  'child_id': wish['child_id'],
                  'wish_id': wish['id'],
                  column: wish[column],
                  'received': 1,
                },
          ];
        }
      }
      final result = VerifiedBackup._(
        Map.unmodifiable(rows),
        payload['exportedOn'] as String,
        password,
      );
      DateTime.parse(result.exportedOn);
      await _validate(result);
      return result;
    } on RuleViolation {
      rethrow;
    } catch (_) {
      throw const RuleViolation('备份密码不正确或文件已损坏，原账本未改变');
    }
  }

  Future<void> _validate(VerifiedBackup backup) async {
    require(backup._rows['families']!.length == 1, '备份必须只包含一个家庭');
    require(backup.family == (backup.demo ? 'demo' : 'real'), '家庭类型与标识不一致');
    require(RegExp(r'^[a-f0-9]{32}$').hasMatch(backup.identity), '缺少稳定家庭标识');
    final children = backup._rows['children']!;
    require(
      children.length == 2 &&
          children.map((r) => r['id']).toSet().containsAll(['first', 'second']),
      '备份孩子档案不完整',
    );
    final temporary = PennyDatabase(NativeDatabase.memory());
    try {
      await temporary.transaction(() async {
        for (final table in _tables) {
          final columns = (await temporary.rows(
            'PRAGMA table_info($table)',
          )).map((r) => r['name']).toSet();
          for (final row in backup._rows[table]!) {
            require(
              row.keys.toSet().length == columns.length &&
                  row.keys.every(columns.contains),
              '备份字段与版本不符',
            );
            require(
              row.values.every(
                (v) => v == null || v is String || v is int || v is double,
              ),
              '备份含不支持的数据',
            );
            require(
              row[table == 'families' ? 'id' : 'family_id'] == backup.family,
              '备份包含另一个家庭的记录',
            );
          }
        }
        await _insert(temporary, backup);
        require(
          (await temporary.rows('PRAGMA foreign_key_check')).isEmpty,
          '备份记录关联不完整',
        );
        for (final child in children) {
          final s = await temporary.load(backup.family, child['id'] as String);
          Day.parse(s.date);
          s.check();
          int sum(String kind) => s.ledger
              .where((l) => l.kind == kind)
              .fold(0, (v, l) => v + l.amount);
          require(
            sum('income') == s.laborTotal &&
                sum('yield') == s.bonusEarned &&
                sum('withdraw') == s.withdrawn &&
                sum('repay') == s.repaidTotal,
            '备份流水与账户金额核对未通过',
          );
        }
      });
    } finally {
      await temporary.close();
    }
  }

  static Future<void> _insert(
    PennyDatabase target,
    VerifiedBackup backup,
  ) async {
    for (final table in _tables) {
      for (final row in backup._rows[table]!) {
        await target.customStatement(
          'INSERT INTO $table (${row.keys.join(',')}) VALUES (${row.keys.map((_) => '?').join(',')})',
          row.values.toList(),
        );
      }
    }
  }

  // Replacing a family requires renewed parent authority and a persisted encrypted snapshot first.
  // A new installation authenticates recovery with the backup password and sets a local passcode; source-device credentials are not copied.
  Future<String?> restore(
    VerifiedBackup backup, {
    Access? access,
    String? newPin,
    Future<String> Function(Uint8List)? preserveBefore,
  }) => db.transaction(() async {
    final existing = await db.rows('SELECT * FROM families WHERE id=?', [
      backup.family,
    ]);
    String? safetyPath;
    if (existing.isNotEmpty) {
      require(
        access != null && access.family == backup.family,
        '覆盖恢复需要本机家长重新解锁',
      );
      auth.check(access!, parent: true);
      require(
        existing.single['global_id'] == backup.identity,
        '这是另一个家庭的备份，不能覆盖或混入当前家庭',
      );
      require(preserveBefore != null, '请先保存恢复前副本');
      safetyPath = await preserveBefore!(
        await export(access, backup._password),
      );
      auth.check(access, parent: true);
      for (final table in _tables.reversed) {
        await db.customStatement(
          'DELETE FROM $table WHERE ${table == 'families' ? 'id' : 'family_id'}=?',
          [backup.family],
        );
      }
    } else {
      require(
        newPin != null && RegExp(r'^\d{6,12}$').hasMatch(newPin),
        '恢复到新设备时请设置 6–12 位本机家长口令',
      );
      if (await auth.credentials.read('pennywood.${backup.family}') == null) {
        await auth.create(backup.family, newPin!);
      } else {
        await auth.unlock(backup.family, 'first', newPin!);
      }
    }
    await _insert(db, backup);
    auth.lock();
    return safetyPath;
  });
}
