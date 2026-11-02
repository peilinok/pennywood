// Settle in integer cents; use BigInt products and round positive amounts half up.
class RuleViolation implements Exception {
  const RuleViolation(this.message);
  final String message;
  @override
  String toString() => message;
}

void require(bool condition, String message) {
  if (!condition) throw RuleViolation(message);
}

class Money {
  // Cap accounts at CNY 1 billion to avoid SQLite integer overflow.
  static const maxCents = 100000000000;
  static int parse(String input) {
    final text = input.trim();
    require(RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text), '金额请填写数字，最多两位小数');
    final parts = text.split('.');
    final value =
        BigInt.parse(parts[0]) * BigInt.from(100) +
        BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    require(value <= BigInt.from(maxCents), '金额超过账户范围');
    return value.toInt();
  }

  static String format(int value) =>
      '${value < 0 ? '-' : ''}${value.abs() ~/ 100}.${(value.abs() % 100).toString().padLeft(2, '0')}';
  static int rounded(int cents, int bps, int multiplier, int denominator) {
    require(
      cents >= 0 && bps >= 0 && multiplier >= 0 && denominator > 0,
      '金额或利率无效',
    );
    // parse/check cap real accounts; hypothetical growth projections may exceed that cap.
    final d = BigInt.from(denominator);
    return ((BigInt.from(cents) * BigInt.from(bps) * BigInt.from(multiplier) +
                d ~/ BigInt.two) ~/
            d)
        .toInt();
  }

  static int interest(int cents, int bps, int days) =>
      rounded(cents, bps, days, 3650000);
  static int monthly(int cents, int bps) => rounded(cents, bps, 1, 120000);
}

class Day {
  static DateTime parse(String value) {
    require(
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value),
      '日期格式应为 YYYY-MM-DD',
    );
    final d = DateTime.tryParse('${value}T00:00:00Z');
    require(d != null && label(d) == value, '日期不存在');
    return d!;
  }

  static String label(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static bool valid(String d) {
    try {
      parse(d);
      return true;
    } on RuleViolation {
      return false;
    }
  }

  static String add(String date, int days) =>
      label(parse(date).add(Duration(days: days)));
  static int difference(String start, String end) =>
      parse(end).difference(parse(start)).inDays;
  // Anchor each month to the original first due date so February clamping does not lose March 31.
  static String month(String first, int offset) {
    final d = parse(first);
    final m = DateTime.utc(d.year, d.month + offset, 1);
    final last = DateTime.utc(m.year, m.month + 1, 0).day;
    return label(DateTime.utc(m.year, m.month, d.day > last ? last : d.day));
  }
}

abstract interface class Clock {
  String get today;
}

class LocalClock implements Clock {
  @override
  String get today => Day.label(DateTime.now());
}

class FixedClock implements Clock {
  FixedClock(this.today);
  @override
  String today;
  void advance(int days) => today = Day.add(today, days);
}
