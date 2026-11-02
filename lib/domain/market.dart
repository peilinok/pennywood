import 'model.dart';
import 'money.dart';

// Version-one teaching market. Calendar hashing keeps a day's movement stable across restarts.
// This is an upward-drift model with shocks, never an index quote or a return promise.
class TeachingMarket {
  static int dailyBps(String product, String date, {int scenario = 0}) {
    var hash = product == 'lowVol' ? 2166136261 : 374761393;
    for (final unit in '$date:$scenario'.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xffffffff;
      hash ^= hash >> 13;
    }
    if (product == 'lowVol') return 4 + hash % 81 - 40;
    return 24 + hash % 501 - 250 - (hash % 61 == 0 ? 800 : 0);
  }

  static List<int> curve(
    String product,
    String start,
    int days, {
    int scenario = 0,
    bool bounded = true,
  }) {
    final p = Product.all[product]!;
    final values = <int>[10000];
    for (var day = 1; day <= days; day++) {
      final change = dailyBps(product, Day.add(start, day), scenario: scenario);
      var next = Money.rounded(values.last, 10000 + change, 1, 10000);
      if (bounded) {
        next = next.clamp(10000 - p.lossCapBps, 10000 + p.gainCapBps);
      }
      values.add(next);
    }
    return values;
  }

  static int profit(Position p, String today) {
    final elapsed = Day.difference(p.start, today).clamp(0, p.days);
    final value = curve(p.product, p.start, elapsed).last;
    final amount = Money.rounded(p.principal, value, 1, 10000);
    return amount - p.principal;
  }

  static int reserve(String product, int principal) =>
      Money.rounded(principal, Product.all[product]!.gainCapBps, 1, 10000);
}
