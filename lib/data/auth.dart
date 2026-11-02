import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/money.dart';

abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class KeychainCredentials implements CredentialStore {
  final storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}

class Access {
  Access._(this.family, this.child, this.parent, this.generation);
  final String family, child;
  final bool parent;
  final int generation;
}

class Auth {
  Auth(this.credentials);
  final CredentialStore credentials;
  int _generation = 0;
  final Set<Access> _issued = {};
  int _failures = 0;
  DateTime? _lockedUntil;
  final _pbkdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );
  Future<void> create(String family, String pin) async {
    require(RegExp(r'^\d{6,12}$').hasMatch(pin), '请设置 6–12 位数字家长口令');
    require(await credentials.read('pennywood.$family') == null, '该家庭凭证已存在');
    await credentials.write('pennywood.$family', await _encode(pin));
  }

  Future<String> _encode(String secret) async {
    final salt = List.generate(24, (_) => Random.secure().nextInt(256));
    final key = await _pbkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
    return '${base64Encode(salt)}:${base64Encode(await key.extractBytes())}';
  }

  Future<void> changePin(Access a, String current, String next) async {
    check(a, parent: true);
    require(RegExp(r'^\d{6,12}$').hasMatch(next), '请设置 6–12 位数字家长口令');
    await _verify(await credentials.read('pennywood.${a.family}'), current);
    final encoded = await _encode(next);
    check(a, parent: true);
    await credentials.write('pennywood.${a.family}', encoded);
    lock();
  }

  Future<String> issueRecovery(Access a) async {
    check(a, parent: true);
    final code = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    final encoded = await _encode(code);
    check(a, parent: true);
    await credentials.write('pennywood.recovery.${a.family}', encoded);
    return List.generate(8, (i) => code.substring(i * 4, i * 4 + 4)).join('-');
  }

  Future<void> recover(String family, String code, String next) async {
    require(RegExp(r'^\d{6,12}$').hasMatch(next), '请设置 6–12 位数字家长口令');
    await _verify(
      await credentials.read('pennywood.recovery.$family'),
      code.replaceAll(RegExp(r'[\s-]'), '').toUpperCase(),
    );
    await credentials.write('pennywood.$family', await _encode(next));
    lock();
  }

  // Retry the same credential after failed setup only; never overwrite an existing credential.
  Access child(String family, String child) {
    final a = Access._(family, child, false, _generation);
    _issued.add(a);
    return a;
  }

  Future<Access> unlock(String family, String child, String pin) async {
    final generation = _generation;
    final stored = await credentials.read('pennywood.$family');
    await _verify(stored, pin);
    require(generation == _generation, '解锁期间已退出，请重新进入');
    final a = Access._(family, child, true, _generation);
    _issued.add(a);
    return a;
  }

  Future<void> _verify(String? stored, String secret) async {
    require(
      _lockedUntil == null || DateTime.now().isAfter(_lockedUntil!),
      '连续错误次数较多，请稍后重试',
    );
    require(stored != null, '未找到本机凭证或尚未设置恢复码，原存档保留');
    final parts = stored!.split(':');
    final key = await _pbkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: base64Decode(parts[0]),
    );
    final actual = await key.extractBytes(), expected = base64Decode(parts[1]);
    var different = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      different |= actual[i] ^ expected[i];
    }
    if (different != 0) {
      _failures++;
      if (_failures >= 5) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      throw const RuleViolation('口令或恢复码不正确');
    }
    _failures = 0;
    _lockedUntil = null;
  }

  void check(Access a, {bool parent = false}) {
    require(_issued.contains(a) && a.generation == _generation, '访问已锁定，请重新进入');
    require(!parent || a.parent, '这一步需要家长确认');
  }

  void lock() {
    _generation++;
    _issued.clear();
  }
}
