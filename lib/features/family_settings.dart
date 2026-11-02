import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../app/controller.dart';
import '../app/screens.dart' show tell;
import '../data/auth.dart';
import '../data/backup.dart';
import '../data/service.dart';
import '../domain/money.dart';
import 'wish_home.dart' show ActionForm;

const _files = MethodChannel('pennywood/files');

Future<bool> restoreFamily(
  BuildContext context,
  TownService service, {
  TownController? controller,
}) async {
  final Uint8List? bytes;
  try {
    bytes = await _files.invokeMethod<Uint8List>('importBackup');
  } on PlatformException catch (e) {
    if (context.mounted) tell(context, e.message ?? '备份文件暂时无法打开');
    return false;
  }
  if (bytes == null || !context.mounted) return false;
  var restored = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ActionForm(
      title: controller == null ? '从加密备份恢复家庭' : '恢复这份家庭备份',
      labels: controller == null
          ? const ['备份密码', '本机家长口令', '再次输入本机口令']
          : const ['备份密码', '当前家长口令'],
      initial: controller == null ? const ['', '', ''] : const ['', ''],
      secretFields: controller == null ? const {0, 1, 2} : const {0, 1},
      submitLabel: '校验并恢复',
      note: controller == null
          ? '全新设备请设置本机口令；若本机曾建档且保留凭证，请输入原口令。备份密码负责解密，不会复制来源设备的家长凭证。已有家庭请从家长空间恢复。'
          : '恢复会回到备份时点，之后的本机记录不会合并。原账本先保存为加密副本（使用本次备份密码），成功后重新锁定。其他家庭不能覆盖当前家庭。',
      onSubmit: (v) async {
        final backups = FamilyBackup(service.db, service.auth);
        final verified = await backups.read(bytes!, v[0]);
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('核对后恢复家庭'),
            content: SingleChildScrollView(
              child: Text(
                '孩子：${verified.children.join('、')}\n备份时间：${verified.exportedOn}\n流水：${verified.entries} 笔\n类型：${verified.demo ? '独立示例家庭' : '真实家庭'}\n\n恢复会回到这个时点，不合并此后的本机记录。已有家庭会先保留加密副本。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const Key('confirm-backup-restore'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认恢复这份备份'),
              ),
            ],
          ),
        );
        require(confirmed == true, '已取消恢复，原账本未改变');
        String? path;
        if (controller != null) {
          require(
            verified.family == controller.family,
            '请选择当前家庭的备份，示例与真实家庭不能混用',
          );
          await controller.unlock(v[1]);
          path = await backups.restore(
            verified,
            access: controller.parent,
            preserveBefore: (before) async {
              final directory = await getApplicationSupportDirectory();
              final copies = Directory(
                '${directory.path}/recovery-copies/${controller.family}',
              );
              await copies.create(recursive: true);
              final file = File(
                '${copies.path}/恢复前-${DateTime.now().microsecondsSinceEpoch}.pennywood',
              );
              await file.writeAsBytes(before, flush: true);
              return file.path;
            },
          );
          controller.lock();
          await controller.load();
        } else {
          require(v[1] == v[2], '两次本机口令不一致');
          require(
            (await service.db.rows('SELECT id FROM families WHERE id=?', [
              verified.family,
            ])).isEmpty,
            '本机已有这类家庭，请进入其家长空间恢复，避免覆盖',
          );
          await backups.restore(verified, newPin: v[1]);
        }
        restored = true;
        if (context.mounted) {
          tell(
            context,
            path == null ? '家庭已恢复，请使用本机家长口令进入。' : '已恢复。恢复前副本保存在本机，可从家长空间再次导出。',
          );
        }
      },
    ),
  );
  return restored;
}

Future<void> recoverParent(BuildContext context, Auth auth, String family) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActionForm(
        title: '用家长恢复码重设口令',
        labels: const ['家长恢复码', '新家长数字口令', '再次输入新口令'],
        initial: const ['', '', ''],
        secretFields: const {0, 1, 2},
        submitLabel: '验证恢复码并重设',
        note: '恢复码需由家长预先生成并在 APP 外单独保管。没有恢复码时不会清空账本或移除家长锁。重设不会改变金额。',
        onSubmit: (v) async {
          require(v[1] == v[2], '两次新口令不一致');
          await auth.recover(family, v[0], v[1]);
          if (context.mounted) tell(context, '家长口令已重设，请重新解锁。');
        },
      ),
    );

class FamilySettings extends StatefulWidget {
  const FamilySettings(this.controller, {super.key});
  final TownController controller;
  @override
  State<FamilySettings> createState() => _FamilySettingsState();
}

class _FamilySettingsState extends State<FamilySettings> {
  TownController get c => widget.controller;
  String? message;
  Future<void> exportBackup() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ActionForm(
      title: '导出加密家庭备份',
      labels: const ['当前家长口令', '备份密码（至少10位）', '再次输入备份密码'],
      initial: const ['', '', ''],
      secretFields: const {0, 1, 2},
      submitLabel: '加密并选择保存位置',
      note: '只导出当前家庭。口令和恢复码不放入备份；请将备份密码另行保管，遗失后无法解密。',
      onSubmit: (v) async {
        require(v[1] == v[2], '两次备份密码不一致');
        await c.unlock(v[0]);
        final bytes = await FamilyBackup(
          c.service.db,
          c.service.auth,
        ).export(c.parent!, v[1]);
        final saved = await _files.invokeMethod<bool>('exportBackup', {
          'bytes': bytes,
        });
        c.lock();
        if (mounted) {
          setState(
            () => message = saved == true
                ? '加密备份已保存到所选位置。备份密码请另行保管。'
                : '已取消导出，账本未改变。',
          );
        }
      },
    ),
  );

  Future<void> changePin() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ActionForm(
      title: '更改家长口令',
      labels: const ['当前家长口令', '新数字口令（6–12位）', '再次输入新口令'],
      initial: const ['', '', ''],
      secretFields: const {0, 1, 2},
      submitLabel: '保存新口令并锁定',
      onSubmit: (v) async {
        require(v[1] == v[2], '两次新口令不一致');
        await c.unlock(v[0]);
        await c.service.auth.changePin(c.parent!, v[0], v[1]);
        c.lock();
        if (mounted) setState(() => message = '口令已更改，请使用新口令重新进入家长空间。');
      },
    ),
  );

  Future<void> recoveryCode() async {
    String? code;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ActionForm(
        title: '生成家长恢复码',
        labels: const ['当前家长口令'],
        initial: const [''],
        secretFields: const {0},
        submitLabel: '验证并生成',
        note: '新码会替换旧码。持有码的人可以重设本机家长口令，请在 APP 外单独保管，不交给孩子。恢复码在重新生成前一直有效。',
        onSubmit: (v) async {
          await c.unlock(v[0]);
          code = await c.service.auth.issueRecovery(c.parent!);
        },
      ),
    );
    if (code != null && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _RecoveryCode(code!),
      );
    }
  }

  Future<void> safetyCopies() async {
    final directory = await getApplicationSupportDirectory();
    final copies = Directory('${directory.path}/recovery-copies/${c.family}');
    final files = await copies.exists()
        ? await copies
              .list()
              .where((f) => f is File && f.path.endsWith('.pennywood'))
              .cast<File>()
              .toList()
        : <File>[];
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复前副本'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('这些副本使用相应恢复操作时输入的备份密码。导出前需当前家长口令。'),
                if (files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('还没有覆盖恢复记录'),
                  ),
                for (final file in files.reversed)
                  TextButton(
                    onPressed: () => exportSafety(file),
                    child: Text(file.uri.pathSegments.last),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Future<void> exportSafety(File file) => showDialog<void>(
    context: context,
    builder: (_) => ActionForm(
      title: '导出恢复前副本',
      labels: const ['当前家长口令'],
      initial: const [''],
      secretFields: const {0},
      submitLabel: '解锁并导出',
      onSubmit: (v) async {
        await c.unlock(v[0]);
        await _files.invokeMethod<bool>('exportBackup', {
          'bytes': await file.readAsBytes(),
        });
        c.lock();
      },
    ),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('家庭数据与家长锁'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '数据先保存在本机。加密备份可存到“文件”或 iCloud Drive；它是手动备份，不会自动同步另一台设备。',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('export-backup'),
              onPressed: exportBackup,
              icon: const Icon(Icons.save_alt),
              label: const Text('导出加密备份'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('restore-backup'),
              onPressed: () async {
                final restored = await restoreFamily(
                  context,
                  c.service,
                  controller: c,
                );
                if (restored && mounted) {
                  setState(() => message = '家庭已恢复，家长空间已锁定。');
                }
              },
              icon: const Icon(Icons.restore),
              label: const Text('从备份恢复'),
            ),
            TextButton(
              onPressed: safetyCopies,
              child: const Text('查看与导出恢复前副本'),
            ),
            const Divider(height: 32),
            OutlinedButton(
              key: const Key('change-parent-pin'),
              onPressed: changePin,
              child: const Text('更改家长口令'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('issue-recovery'),
              onPressed: recoveryCode,
              child: const Text('生成或更换家长恢复码'),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(liveRegion: true, child: Text(message!)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('返回'),
      ),
    ],
  );
}

class _RecoveryCode extends StatefulWidget {
  const _RecoveryCode(this.code);
  final String code;
  @override
  State<_RecoveryCode> createState() => _RecoveryCodeState();
}

class _RecoveryCodeState extends State<_RecoveryCode>
    with WidgetsBindingObserver {
  bool hidden = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => hidden = true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('请在 APP 外保管恢复码'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hidden)
            SelectableText(
              widget.code,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            )
          else
            const Text('恢复码已隐藏。需要时请家长重新解锁并生成新码。'),
          const SizedBox(height: 16),
          const Text('本页关闭后无法再次查看这串码；重新生成会让旧码失效。备份不包含恢复码，换设备后请重新生成。'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('我已妥善保管'),
      ),
    ],
  );
}
