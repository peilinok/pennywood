import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../domain/model.dart';
import 'navigation.dart';

class TownGame extends FlameGame {
  TownGame(
    this.scene, {
    required this.onEnter,
    required this.onSave,
    this.onError,
  });
  final SceneState scene;
  final Future<void> Function(String) onEnter;
  final Future<void> Function() onSave;
  final void Function(Object)? onError;
  late TownMap map;
  final Map<String, ui.Image> art = {};
  final Map<String, Rect> bounds = {};
  Map<String, dynamic> places = {};
  List<Point2> path = [];
  String? destination;
  int journey = 0;
  bool assetsReady = false, facingLeft = false;
  bool reduceMotion = false;
  int settledYield = 0;
  bool secondChild = false;
  double phase = 0, scaleFactor = 1;
  Offset origin = Offset.zero;
  double gestureZoom = 1;

  @override
  Color backgroundColor() =>
      scene.evening ? const Color(0xFFE8DCCF) : const Color(0xFFEBF0D9);
  @override
  Future<void> onLoad() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/scene-layout.json'))
            as Map<String, dynamic>;
    map = TownMap(json);
    places = Map<String, dynamic>.from(json['places'] as Map);
    for (final name in [
      'ground',
      'house-savings',
      'house-wish',
      'house-tasks',
      'outdoor-tree-left',
      'outdoor-tree-middle',
      'outdoor-tree-right',
      'mailbox',
      'tree-annual',
      'player-reference',
    ]) {
      final source = await rootBundle.loadString('assets/svg/$name.svg');
      final match = RegExp(r'viewBox="([^"]+)"').firstMatch(source)!;
      final v = match
          .group(1)!
          .split(RegExp(r'\s+'))
          .map(double.parse)
          .toList();
      final rect = Rect.fromLTWH(v[0], v[1], v[2], v[3]);
      bounds[name] = rect;
      // Parse SVG at load time only; retain original artwork and rasterize at double resolution.
      final picture = await vg.loadPicture(SvgStringLoader(source), null);
      final recorder = ui.PictureRecorder();
      // Use a separate recorder to convert the SVG viewport into a high-density image.
      final rasterCanvas = Canvas(recorder);
      rasterCanvas.scale(2);
      rasterCanvas.drawPicture(picture.picture);
      final recording = recorder.endRecording();
      art[name] = await recording.toImage(
        (rect.width * 2).ceil(),
        (rect.height * 2).ceil(),
      );
      recording.dispose();
      picture.picture.dispose();
    }
    if (!map.canWalk(Point2(scene.x, scene.y))) {
      scene.x = 400;
      scene.y = 380;
    }
    assetsReady = true;
  }

  void transform() {
    final fit = math.min((size.x - 60) / 860, (size.y - 82) / 530);
    scaleFactor = fit * scene.zoom;
    origin = Offset(
      (size.x - 860 * scaleFactor) / 2 + scene.panX,
      42 + (size.y - 82 - 530 * scaleFactor) / 2 + scene.panY,
    );
  }

  Point2 screenToWorld(Offset screen) {
    transform();
    return Point2(
      (screen.dx - origin.dx) / scaleFactor,
      (screen.dy - origin.dy) / scaleFactor,
    );
  }

  Future<void> stop({bool save = true}) async {
    journey++;
    path = [];
    destination = null;
    if (save && assetsReady) await onSave();
  }

  void visit(String place) {
    if (!assetsReady) return;
    final p = places[place]['entrance'];
    walk(
      Point2((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
      place: place,
    );
  }

  void walk(Point2 point, {String? place}) {
    // Any new destination cancels the previous arrival callback, even if unreachable.
    journey++;
    path = [];
    destination = null;
    final route = map.route(Point2(scene.x, scene.y), point);
    if (route.isNotEmpty) {
      path = route;
      destination = place;
    }
  }

  void tap(Offset local) {
    if (!assetsReady) return;
    final p = screenToWorld(local);
    for (final name in ['savings', 'wish', 'tasks', 'growth']) {
      if (labelRect(name).contains(Offset(p.x, p.y))) {
        visit(name);
        return;
      }
    }
    for (final name in ['tasks', 'wish', 'savings', 'growth', 'journal']) {
      final place = places[name];
      if (place['sourceTranslation'] != null) {
        final t = place['sourceTranslation'] as List;
        final b = bounds['house-$name']!;
        if (b
            .shift(Offset((t[0] as num).toDouble(), (t[1] as num).toDouble()))
            .contains(Offset(p.x, p.y))) {
          visit(name);
          return;
        }
      } else {
        final e = place['entrance'];
        if (p.distance(
              Point2((e['x'] as num).toDouble(), (e['y'] as num).toDouble()),
            ) <
            35) {
          visit(name);
          return;
        }
      }
    }
    if (map.canWalk(p)) {
      walk(p);
    } else {
      journey++;
      path = [];
      destination = null;
    }
  }

  void startGesture() {
    gestureZoom = scene.zoom;
  }

  void gesture(double zoom, Offset delta) {
    scene.zoom = (gestureZoom * zoom).clamp(.75, 1.6);
    scene.panX = (scene.panX + delta.dx).clamp(-200, 200);
    scene.panY = (scene.panY + delta.dy).clamp(-120, 120);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!assetsReady) return;
    phase = reduceMotion ? 0 : phase + dt;
    var travel = 150 * math.min(dt, .05);
    while (path.isNotEmpty && travel > 0) {
      final next = path.first,
          current = Point2(scene.x, scene.y),
          distance = current.distance(next);
      if (distance < .1 || distance <= travel) {
        scene.x = next.x;
        scene.y = next.y;
        travel -= distance;
        path.removeAt(0);
      } else {
        facingLeft = next.x < scene.x;
        scene.x += (next.x - scene.x) * travel / distance;
        scene.y += (next.y - scene.y) * travel / distance;
        travel = 0;
      }
      if (path.isEmpty) {
        final arrived = destination;
        destination = null;
        finishJourney(arrived, journey);
      }
    }
  }

  Future<void> finishJourney(String? arrived, int arrivalJourney) async {
    final added =
        arrived != null && arrived != 'journal' && scene.visited.add(arrived);
    try {
      await onSave();
    } catch (e) {
      if (added) scene.visited.remove(arrived);
      onError?.call(e);
      return;
    }
    if (arrived != null && arrivalJourney == journey) {
      try {
        await onEnter(arrived);
      } catch (e) {
        onError?.call(e);
      }
    }
  }

  Rect labelRect(String name) {
    final label = places[name]['label'];
    return Rect.fromCenter(
      center: Offset(
        (label['x'] as num).toDouble(),
        (label['y'] as num).toDouble(),
      ),
      width: math.max(94, 74 / scaleFactor),
      height: math.max(29, 32 / scaleFactor),
    );
  }

  void sprite(Canvas canvas, String name, Rect target) {
    final image = art[name]!;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!assetsReady) return;
    transform();
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scaleFactor);
    sprite(canvas, 'ground', const Rect.fromLTWH(0, 0, 860, 530));
    if (path.isNotEmpty) {
      final line = Path()..moveTo(scene.x, scene.y);
      for (final p in path) {
        line.lineTo(p.x, p.y);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = const Color(0x99FFFAE5)
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    final layers = <(double, void Function())>[];
    for (final name in ['savings', 'wish', 'tasks']) {
      final p = places[name], t = p['sourceTranslation'] as List;
      final b = bounds['house-$name']!;
      layers.add((
        (p['sortDepth'] as num).toDouble(),
        () => sprite(
          canvas,
          'house-$name',
          b.shift(Offset((t[0] as num).toDouble(), (t[1] as num).toDouble())),
        ),
      ));
    }
    for (final (name, depth) in [
      ('outdoor-tree-left', 333.0),
      ('outdoor-tree-middle', 241.0),
      ('outdoor-tree-right', 334.0),
      ('mailbox', 425.0),
    ]) {
      layers.add((depth, () => sprite(canvas, name, bounds[name]!)));
    }
    final treeScale = settledYield >= 100
        ? 0.62
        : settledYield > 0
        ? 0.54
        : 0.42;
    layers.add((
      440,
      () => sprite(
        canvas,
        'tree-annual',
        Rect.fromLTWH(
          490 - 91 * treeScale,
          449 - 148 * treeScale,
          180 * treeScale,
          165 * treeScale,
        ),
      ),
    ));
    layers.add((
      scene.y,
      () {
        canvas.save();
        canvas.translate(scene.x, scene.y);
        canvas.drawOval(
          const Rect.fromLTWH(-14, -2, 28, 6),
          Paint()..color = const Color(0x55819C70),
        );
        if (facingLeft) canvas.scale(-1, 1);
        final bob = path.isEmpty
            ? math.sin(phase * 2) * .5
            : math.sin(phase * 18) * 2;
        sprite(
          canvas,
          'player-reference',
          Rect.fromLTWH(-24, -58 + bob, 48, 59.2),
        );
        if (secondChild) {
          final scarf = Path()
            ..moveTo(-8, -21 + bob)
            ..lineTo(8, -20 + bob)
            ..lineTo(7, -16 + bob)
            ..lineTo(-7, -17 + bob)
            ..lineTo(-12, -10 + bob)
            ..lineTo(-15, -12 + bob)
            ..close();
          canvas.drawPath(scarf, Paint()..color = const Color(0xFFB3A2C8));
        }
        canvas.restore();
      },
    ));
    layers.sort((a, b) => a.$1.compareTo(b.$1));
    for (final layer in layers) {
      layer.$2();
    }
    for (final name in ['savings', 'wish', 'tasks', 'growth']) {
      final p = places[name], label = p['label'];
      final center = Offset(
        (label['x'] as num).toDouble(),
        (label['y'] as num).toDouble(),
      );
      final rect = labelRect(name);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.shift(const Offset(0, 3)),
          const Radius.circular(9),
        ),
        Paint()..color = const Color(0xFFCCD0A7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(9)),
        Paint()..color = const Color(0xFFFFFAE7),
      );
      final text = TextPainter(
        text: TextSpan(
          text: p['name'] as String,
          style: TextStyle(
            color: Color(0xFF556D44),
            fontSize: math.max(14, 11 / scaleFactor),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
    if (scene.evening) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 860, 530),
        Paint()..color = const Color(0x287F566E),
      );
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    for (final image in art.values) {
      image.dispose();
    }
    super.onRemove();
  }
}
