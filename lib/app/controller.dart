import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/auth.dart';
import '../data/service.dart';
import '../domain/model.dart';
import '../domain/money.dart';

class TownController extends ChangeNotifier {
  TownController(this.service, this.family, this.child);
  final TownService service;
  final String family;
  String child;
  late Access access;
  Access? parent;
  late ChildAccount account;
  late SceneState scene;
  bool busy = false, ready = false;
  bool get demo => family == 'demo';
  Future<void> load() async {
    await service.restore(family);
    access = service.auth.child(family, child);
    account = await service.account(access);
    scene = await service.db.loadScene(family, child);
    ready = true;
    notifyListeners();
  }

  Future<void> switchChild(String id) async {
    service.auth.lock();
    parent = null;
    child = id;
    await service.selectChild(family, id);
    await load();
  }

  Future<void> unlock(String pin) async {
    parent = await service.auth.unlock(family, child, pin);
    notifyListeners();
  }

  void lock() {
    service.auth.lock();
    parent = null;
    access = service.auth.child(family, child);
    notifyListeners();
  }

  Future<void> refresh() async {
    account = await service.account(access);
    notifyListeners();
  }

  Future<void> perform(
    String action,
    List<Object?> args, {
    String? operationId,
  }) async {
    require(!busy, '正在保存，请稍候');
    busy = true;
    notifyListeners();
    try {
      final a = parent ?? access;
      await service.execute(
        a,
        operationId ??
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
        action,
        args,
      );
      await refresh();
      if (scene.sound) await SystemSound.play(SystemSoundType.click);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> saveScene() => service.scene(access, scene);
  Future<void> resume() async {
    await service.restore(family);
    await refresh();
  }

  Future<void> advanceDemo(int days) async {
    require(demo && parent != null, '日期工具仅用于独立示例家庭并需家长解锁');
    final clock = service.clock;
    require(clock is FixedClock, '真实家庭不能加速时间');
    (clock as FixedClock).advance(days);
    await resume();
  }
}
