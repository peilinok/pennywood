import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'family_release_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'A fresh process retains gift receipt, original payments, debt, and restored credentials',
    (tester) async {
      final svc = await startFamilyRelease();
      final s = await svc.db.load('real', 'first');
      expect(s.wallet, 0);
      expect(s.laborTotal, 3200);
      expect(s.withdrawn, 3200);
      expect(s.debt, 4848);
      expect(s.wishes.single.receivedOn, '2026-11-01');
      expect(s.wishes.single.receivedCost, 8000);
      expect(s.mainWish, isNull);
      expect(s.ledger.where((l) => l.kind == 'income').length, 1);
      expect(s.ledger.where((l) => l.kind == 'withdraw').length, 2);
      expect(s.requests.length, 2);
      expect(
        s.requests.every(
          (r) => r.wishId == s.wishes.single.id && r.usedForGift,
        ),
        isTrue,
      );
      expect(s.loans.single.wishId, s.wishes.single.id);
      expect(s.loans.single.usedForGift, isTrue);
      expect(s.ledger.where((l) => l.kind == 'loan-funded').length, 1);
      expect((await svc.db.load('real', 'second')).assets, 0);
      final parent = await svc.auth.unlock('real', 'first', '719385');
      svc.auth.check(parent, parent: true);
      await svc.restore('real');
      expect(
        (await svc.db.load('real', 'first')).ledger.length,
        s.ledger.length,
      );
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
