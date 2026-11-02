import 'dart:math' as math;

class Point2 {
  const Point2(this.x, this.y);
  final double x, y;
  double distance(Point2 b) =>
      math.sqrt((x - b.x) * (x - b.x) + (y - b.y) * (y - b.y));
}

// Coordinates are already projected; do not project again. Collision-sample every grid A* edge.
class TownMap {
  TownMap(Map<String, dynamic> json) {
    walkable = poly(json['walkablePolygon'] as List);
    obstacles = [
      for (final p in json['buildingObstacles'] as List) poly(p as List),
    ];
    trunks = [
      for (final t in json['treeTrunkObstacles'] as List)
        (
          Point2((t['x'] as num).toDouble(), (t['y'] as num).toDouble()),
          (t['radius'] as num).toDouble(),
        ),
    ];
  }
  late final List<Point2> walkable;
  late final List<List<Point2>> obstacles;
  late final List<(Point2, double)> trunks;
  static List<Point2> poly(List p) => [
    for (final v in p)
      Point2((v[0] as num).toDouble(), (v[1] as num).toDouble()),
  ];
  bool inside(Point2 p, List<Point2> polygon) {
    var hit = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i], b = polygon[j];
      if ((a.y > p.y) != (b.y > p.y) &&
          p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        hit = !hit;
      }
    }
    return hit;
  }

  bool canWalk(Point2 p) =>
      inside(p, walkable) &&
      !obstacles.any((o) => inside(p, o)) &&
      !trunks.any((t) => p.distance(t.$1) < t.$2 + 3);
  bool segment(Point2 a, Point2 b) {
    final n = (a.distance(b) / 2).ceil().clamp(1, 1000);
    for (var i = 0; i <= n; i++) {
      if (!canWalk(
        Point2(a.x + (b.x - a.x) * i / n, a.y + (b.y - a.y) * i / n),
      )) {
        return false;
      }
    }
    return true;
  }

  Point2? nearest(Point2 p) {
    final candidates = <Point2>[];
    for (var dx = -7; dx <= 7; dx++) {
      for (var dy = -7; dy <= 7; dy++) {
        final n = Point2(
          (p.x / 10).round() * 10.0 + dx * 10,
          (p.y / 10).round() * 10.0 + dy * 10,
        );
        if (canWalk(n) && (!canWalk(p) || segment(p, n))) candidates.add(n);
      }
    }
    candidates.sort((a, b) => a.distance(p).compareTo(b.distance(p)));
    return candidates.firstOrNull;
  }

  List<Point2> route(Point2 source, Point2 target) {
    final start = nearest(source), end = nearest(target);
    if (start == null || end == null) return [];
    String key(Point2 p) => '${p.x.toInt()},${p.y.toInt()}';
    final nodes = <String, Point2>{key(start): start},
        costs = <String, double>{key(start): 0},
        previous = <String, String>{},
        open = <String>[key(start)],
        closed = <String>{};
    while (open.isNotEmpty) {
      open.sort(
        (a, b) => (costs[a]! + nodes[a]!.distance(end)).compareTo(
          costs[b]! + nodes[b]!.distance(end),
        ),
      );
      final current = open.removeAt(0);
      if (!closed.add(current)) continue;
      if (current == key(end)) {
        final path = <Point2>[end];
        var id = current;
        while (previous.containsKey(id)) {
          id = previous[id]!;
          path.insert(0, nodes[id]!);
        }
        if (canWalk(target) && segment(end, target)) path.add(target);
        return path;
      }
      final p = nodes[current]!;
      for (final d in const [
        (10, 0),
        (-10, 0),
        (0, 10),
        (0, -10),
        (10, 10),
        (-10, 10),
        (10, -10),
        (-10, -10),
      ]) {
        final n = Point2(p.x + d.$1, p.y + d.$2);
        if (!segment(p, n)) continue;
        final id = key(n), cost = costs[current]! + p.distance(n);
        if (cost >= (costs[id] ?? double.infinity)) continue;
        nodes[id] = n;
        costs[id] = cost;
        previous[id] = current;
        open.add(id);
      }
    }
    return [];
  }
}
