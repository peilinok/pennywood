import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pennywood/game/navigation.dart';

void main() {
  final json =
      jsonDecode(File('assets/scene-layout.json').readAsStringSync())
          as Map<String, dynamic>;
  final map = TownMap(json);
  test(
    'Every building entrance is reachable without crossing buildings or trunks',
    () {
      for (final p in (json['places'] as Map).values) {
        final e = p['entrance'];
        final route = map.route(
          const Point2(400, 380),
          Point2((e['x'] as num).toDouble(), (e['y'] as num).toDouble()),
        );
        expect(route, isNotEmpty);
        for (var i = 1; i < route.length; i++) {
          expect(map.segment(route[i - 1], route[i]), true);
        }
      }
    },
  );
  test('Indoor and out-of-map points are not walking destinations', () {
    expect(map.canWalk(const Point2(255, 330)), false);
    expect(map.canWalk(const Point2(0, 0)), false);
  });
}
