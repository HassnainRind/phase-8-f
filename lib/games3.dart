// Meadow maze and Petal snake (canvas games with joystick / arrow steering).
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_core.dart';
import 'game_shell.dart';
import 'theme.dart';
import 'widgets.dart';

const mazeModes = ['Meadow', 'Hedges', 'Lantern', 'Labyrinth'];
const snakeModes = ['Calm', 'Hedges', 'Sprint', 'Wild'];
String selectedMazeMode = 'Meadow';
String selectedSnakeMode = 'Calm';

void drawGlyph(Canvas c, String t, Offset center, double size, Color color) {
  final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// ".mini-variants" bar: mode pills + challenge stepper + "New layout"
Widget variantBar(GameHost h, List<String> modes, String current, void Function(String) pick, String newLabel, {bool compact = false, bool showNew = true}) {
  final th = h.th;
  Widget pill(String m) => Pressable(
        scale: .97,
        onTap: () {
          if (m == current) return;
          pick(m);
          h.reopen?.call(h.level);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 29),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
              color: m == current ? th.soft : Colors.white,
              border: Border.all(color: m == current ? th.accent : th.edge, width: 1.5),
              borderRadius: BorderRadius.circular(999),
              boxShadow: m == current ? [BoxShadow(color: th.accent, blurRadius: 12, offset: const Offset(0, 3), spreadRadius: -9)] : null),
          child: Text(m, style: ts(11, FontWeight.w700, th.dark)),
        ),
      );
  // Challenge -/+ stepper removed (snake + maze): just mode pills and "New layout".
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 450),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Wrap(alignment: WrapAlignment.center, spacing: 5, runSpacing: 5, children: [for (final m in modes) pill(m)]),
      if (showNew) ...[
        const SizedBox(height: 4),
        Pressable(
          scale: .97,
          onTap: () => h.reopen?.call(h.level),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            child: Text(newLabel, style: ts(11, FontWeight.w700, th.accent).copyWith(decoration: TextDecoration.underline)),
          ),
        ),
      ],
    ]),
  );
}

// ================================================================ joystick (".maze-joystick")
class Joystick extends StatefulWidget {
  final GameTheme th;
  final void Function(int) onMove;
  final VoidCallback onStop;
  const Joystick({super.key, required this.th, required this.onMove, required this.onStop});
  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  static const double sz = 100, thumbSz = 43;
  Offset thumb = Offset.zero;
  int held = -1;
  Timer? timer;
  bool engaged = false;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void stop() {
    timer?.cancel();
    timer = null;
    held = -1;
    widget.onStop();
    if (mounted) setState(() {
          thumb = Offset.zero;
          engaged = false;
        });
  }

  void aim(Offset local) {
    final dx = local.dx - sz / 2, dy = local.dy - sz / 2;
    final dist = math.sqrt(dx * dx + dy * dy), radius = sz * .28;
    final k = math.min(radius, dist) / (dist == 0 ? 1 : dist);
    setState(() {
      thumb = Offset(dx * k, dy * k);
      engaged = true;
    });
    if (dist < sz * .12) {
      held = -1;
      timer?.cancel();
      timer = null;
      return;
    }
    final d = dx.abs() > dy.abs() ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0);
    if (d == held) return;
    held = d;
    timer?.cancel();
    widget.onMove(d);
    timer = Timer.periodic(const Duration(milliseconds: 155), (_) {
      if (held == d) widget.onMove(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    Color mix(double a) => Color.lerp(Colors.white, th.accent, a)!;
    Widget arrow(String t, {double? l, double? r, double? tp, double? b}) =>
        Positioned(left: l, right: r, top: tp, bottom: b, child: Opacity(opacity: .42, child: Text(t, style: ts(15, FontWeight.w800, th.dark, height: 1))));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Listener(
        onPointerDown: (e) => aim(e.localPosition),
        onPointerMove: (e) => aim(e.localPosition),
        onPointerUp: (_) => stop(),
        onPointerCancel: (_) => stop(),
        child: Container(
          width: sz,
          height: sz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: engaged ? th.accent : mix(.35), width: 2),
            gradient: RadialGradient(center: const Alignment(-.36, -.5), radius: 1.0, colors: [Colors.white, th.soft, const Color(0xFFEBE7F0)], stops: const [0, .65, 1]),
            boxShadow: const [BoxShadow(color: Color(0x337E6890), blurRadius: 19, offset: Offset(0, 8), spreadRadius: -13)],
          ),
          child: Stack(children: [
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(17), child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: mix(.21)))))),
            arrow('↑', l: sz / 2 - 6, tp: 9),
            arrow('→', r: 9, tp: sz / 2 - 9),
            arrow('↓', l: sz / 2 - 6, b: 9),
            arrow('←', l: 9, tp: sz / 2 - 9),
            Positioned(
              left: sz / 2 - thumbSz / 2 - 2 + thumb.dx,
              top: sz / 2 - thumbSz / 2 - 2 + thumb.dy,
              child: Container(
                width: thumbSz,
                height: thumbSz,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(Colors.white, th.accent, .75)!, th.accent]),
                  border: Border.all(color: const Color(0xCBFFFFFF), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x4525173D), blurRadius: 15, offset: Offset(0, 5))],
                ),
                child: Center(child: Container(width: 17, height: 17, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x70FFFFFF)))),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 5),
      Opacity(opacity: .65, child: Text('Drag to guide · Release to stop', style: ts(10, FontWeight.w700, th.dark))),
    ]);
  }
}

// ================================================================ Meadow maze
class MazeGame extends StatefulWidget {
  final GameHost host;
  const MazeGame(this.host, {super.key});
  @override
  State<MazeGame> createState() => _MazeState();
}

class _MazeState extends State<MazeGame> with SingleTickerProviderStateMixin {
  GameHost get h => widget.host;
  late final String mode;
  late final int size, N, goal, view, R;
  late final List<List<bool>> cells;
  late final List<int> DR;
  late final Set<int> flowers;
  final Set<int> collected = {}, seen = {}, visited = {0};
  late final bool fog;
  int pos = 0, moves = 0;
  double mx = 0, my = 0;
  int? pendingMove;
  bool gliding = false;
  final ValueNotifier<int> repaint = ValueNotifier(0);
  late final AnimationController glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
  double fromX = 0, fromY = 0, toX = 0, toY = 0;
  bool built = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (built) return;
    built = true;
    mode = selectedMazeMode;
    final level = h.level;
    final random = math.Random(rng.nextInt(1 << 30));
    final w = MediaQuery.of(context).size.width;
    final cap = w < 400 ? 39 : 45;
    final bonus = mode == 'Labyrinth' ? 4 : (mode == 'Lantern' || mode == 'Hedges') ? 2 : 0;
    final int grow = math.min<int>(13, ((level - 1) / 2).floor());
    final int rawSize = 19 + 2 * grow + bonus;
    size = math.min<int>(cap, rawSize);
    N = size * size;
    goal = N - 1;
    cells = mazeCells(size, random);
    DR = [-size, 1, size, -1];
    final loopsRate = mode == 'Meadow' ? .085 : mode == 'Hedges' ? .035 : mode == 'Lantern' ? .014 : 0.0;
    final loops = (N * loopsRate).floor();
    for (var k = 0; k < loops; k++) {
      final i = random.nextInt(N), r = i ~/ size, c = i % size, d = random.nextInt(4);
      final rr = r + const [-1, 0, 1, 0][d], cc = c + const [0, 1, 0, -1][d];
      if (rr < 0 || rr >= size || cc < 0 || cc >= size) continue;
      cells[i][d] = false;
      cells[rr * size + cc][(d + 2) % 4] = false;
    }
    List<int> open(int i) => [for (var d = 0; d < 4; d++) if (!cells[i][d]) i + DR[d]];
    List<int> distances(int start) {
      final dist = List<int>.filled(N, -1);
      final q = <int>[start];
      dist[start] = 0;
      for (var hd = 0; hd < q.length; hd++) {
        for (final j in open(q[hd])) {
          if (dist[j] < 0) {
            dist[j] = dist[q[hd]] + 1;
            q.add(j);
          }
        }
      }
      return dist;
    }

    final fromStart = distances(0), fromEnd = distances(goal);
    final tokenCount = mode == 'Meadow'
        ? (level >= 9 ? 1 : 0)
        : mode == 'Hedges'
            ? math.min(3, 1 + ((level - 1) / 11).floor())
            : mode == 'Lantern'
                ? math.min(4, 2 + ((level - 1) / 10).floor())
                : math.min(5, 2 + ((level - 1) / 7).floor());
    final cand = <int>[for (var i = 1; i < goal; i++) if (open(i).length == 1 && fromStart[i] > size / 2 && fromEnd[i] > size / 2) i];
    if (cand.length < tokenCount) {
      for (var i = 1; i < goal; i++) {
        if (open(i).length == 1 && !cand.contains(i)) cand.add(i);
      }
    }
    final targets = <int>[];
    while (targets.length < tokenCount && cand.isNotEmpty) {
      double best = -1e18;
      var which = 0;
      for (var k = 0; k < cand.length; k++) {
        final i = cand[k];
        final spread = targets.isNotEmpty
            ? targets.map((j) => ((i % size) - (j % size)).abs() + ((i ~/ size) - (j ~/ size)).abs()).reduce(math.min).toDouble()
            : size.toDouble();
        final rank = fromStart[i] + fromEnd[i] * .40 + spread * 2 + random.nextDouble() * size * .8;
        if (rank > best) {
          best = rank;
          which = k;
        }
      }
      targets.add(cand.removeAt(which));
    }
    flowers = targets.toSet();
    fog = mode == 'Lantern' || mode == 'Labyrinth' || (mode == 'Hedges' && level >= 8);
    R = fog ? (mode == 'Labyrinth' ? math.max(4, 6 - ((level - 1) / 12).floor()) : math.max(4, 7 - ((level - 1) / 12).floor())) : 0;
    view = fog ? math.min(15, size) : size;
    glide.addListener(() {
      final t = glide.value, sm = t * t * (3 - 2 * t);
      mx = fromX + (toX - fromX) * sm;
      my = fromY + (toY - fromY) * sm;
      repaint.value++;
    });
    glide.addStatusListener((s) {
      if (s == AnimationStatus.completed) arrived();
    });
    h.hideProgress = true;
    reveal();
    h.initial(
      variants: variantBar(h, mazeModes, mode, (m) => selectedMazeMode = m, 'New layout', compact: true),
      status: '$mode · $size × $size · ${flowers.length} flowers to collect. Use the joystick to explore.',
      extra: Padding(padding: const EdgeInsets.only(top: 3), child: Joystick(th: h.th, onMove: move, onStop: () => pendingMove = null)),
    );
  }

  @override
  void dispose() {
    glide.dispose();
    repaint.dispose();
    super.dispose();
  }

  void reveal() {
    if (!fog) return;
    final r = pos ~/ size, c = pos % size;
    for (var a = -R; a <= R; a++) {
      for (var b = -R; b <= R; b++) {
        final y = r + a, z = c + b;
        if (y >= 0 && y < size && z >= 0 && z < size && a * a + b * b <= R * R + 1) seen.add(y * size + z);
      }
    }
  }

  String message() => '$moves steps${flowers.isNotEmpty ? ' · ${collected.length} of ${flowers.length} flowers collected' : ''}${fog ? ' · limited visibility' : ''}';

  void move(int d) {
    if (h.completed || d < 0 || d > 3) return;
    if (gliding) {
      pendingMove = d;
      return;
    }
    if (cells[pos][d]) {
      h.setStatus('A hedge blocks that direction.');
      return;
    }
    pos += DR[d];
    moves++;
    visited.add(pos);
    if (flowers.contains(pos)) collected.add(pos);
    reveal();
    fromX = mx;
    fromY = my;
    toX = (pos % size).toDouble();
    toY = (pos ~/ size).toDouble();
    gliding = true;
    glide.forward(from: 0);
  }

  void arrived() {
    gliding = false;
    mx = toX;
    my = toY;
    repaint.value++;
    if (pos == goal && collected.length == flowers.length) {
      h.complete('Garden found · $moves steps · ${flowers.length} flowers');
      return;
    }
    if (pos == goal && collected.length < flowers.length) {
      h.setStatus('The garden gate is closed · ${flowers.length - collected.length} flowers remain');
    } else {
      h.setStatus(message());
    }
    final p = pendingMove;
    if (p != null) {
      pendingMove = null;
      move(p);
    }
  }

  Offset? swipeStart;

  @override
  Widget build(BuildContext context) {
    final th = h.th;
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: th.edge, width: 2), borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: Listener(
            onPointerDown: (e) => swipeStart = e.localPosition,
            onPointerMove: (e) {
              final s = swipeStart;
              if (s == null) return;
              final dx = e.localPosition.dx - s.dx, dy = e.localPosition.dy - s.dy;
              if (math.sqrt(dx * dx + dy * dy) > 22) {
                move(dx.abs() > dy.abs() ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0));
                swipeStart = e.localPosition;
              }
            },
            child: CustomPaint(painter: _MazePainter(this, repaint)),
          ),
        ),
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  final _MazeState s;
  _MazePainter(this.s, Listenable repaint) : super(repaint: repaint);
  static const double S = 20, P = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final th = s.h.th;
    final view = s.view, W = view * S + 2 * P;
    canvas.scale(size.width / W);
    canvas.drawRect(Rect.fromLTWH(0, 0, W, W), Paint()..color = Colors.white);
    final panX = s.fog ? (s.mx - (view - 1) / 2).clamp(0.0, (s.size - view).toDouble()).toDouble() : 0.0;
    final panY = s.fog ? (s.my - (view - 1) / 2).clamp(0.0, (s.size - view).toDouble()).toDouble() : 0.0;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(P, P, view * S, view * S));
    canvas.translate(-panX * S, -panY * S);
    double cx(int i) => P + (i % s.size) * S;
    double cy(int i) => P + (i ~/ s.size) * S;
    final r0 = math.max(0, panY.floor() - 1), r1 = math.min(s.size - 1, (panY + view).ceil() + 1);
    final c0 = math.max(0, panX.floor() - 1), c1 = math.min(s.size - 1, (panX + view).ceil() + 1);
    final fogPaint = Paint()..color = th.soft;
    final visitPaint = Paint()..color = th.accent.withAlpha(26);
    final wallPath = Path();
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final i = r * s.size + c;
        if (s.fog && !s.seen.contains(i)) {
          canvas.drawRect(Rect.fromLTWH(cx(i), cy(i), S, S), fogPaint);
          continue;
        }
        if (s.mode != 'Labyrinth' && s.visited.contains(i)) canvas.drawRect(Rect.fromLTWH(cx(i), cy(i), S, S), visitPaint);
        final px = cx(i), py = cy(i), w = s.cells[i];
        if (w[0]) {
          wallPath.moveTo(px, py);
          wallPath.lineTo(px + S, py);
        }
        if (w[1]) {
          wallPath.moveTo(px + S, py);
          wallPath.lineTo(px + S, py + S);
        }
        if (w[2]) {
          wallPath.moveTo(px, py + S);
          wallPath.lineTo(px + S, py + S);
        }
        if (w[3]) {
          wallPath.moveTo(px, py);
          wallPath.lineTo(px, py + S);
        }
      }
    }
    canvas.drawPath(wallPath, Paint()
      ..color = th.dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    for (final i in s.flowers) {
      if (s.collected.contains(i) || (s.fog && !s.seen.contains(i))) continue;
      final c = Offset(cx(i) + S / 2, cy(i) + S / 2);
      canvas.drawCircle(c, S * .44, Paint()..color = const Color(0xFFFFDEEB));
      drawGlyph(canvas, '✿', c, S * .84, const Color(0xFFC52D6A));
    }
    if (!s.fog || s.seen.contains(s.goal)) {
      final ready = s.collected.length == s.flowers.length;
      final c = Offset(cx(s.goal) + S / 2, cy(s.goal) + S / 2);
      canvas.drawCircle(c, S * .56, Paint()..color = ready ? const Color(0xFFF8C9DA) : const Color(0xFFDDE0E6));
      drawGlyph(canvas, ready ? '✿' : '◈', c + const Offset(0, 1), S, ready ? const Color(0xFFBF255D) : const Color(0xFF64748B));
    }
    final p = Offset(P + (s.mx + .5) * S, P + (s.my + .5) * S);
    canvas.drawCircle(p, S * .57, Paint()
      ..color = th.accent.withAlpha(51)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(p, S * .34, Paint()..color = th.accent);
    canvas.drawCircle(p + const Offset(-S * .10, -S * .12), S * .08, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}

// ================================================================ Petal snake
class SnakeGame extends StatefulWidget {
  final GameHost host;
  const SnakeGame(this.host, {super.key});
  @override
  State<SnakeGame> createState() => _SnakeState();
}

class _SnakeState extends State<SnakeGame> with WidgetsBindingObserver {
  GameHost get h => widget.host;
  static const cols = 17, rows = 18;
  late final String mode;
  late final int goal, base, layout;
  late final math.Random random;
  List<math.Point<int>> body = [for (var i = 0; i < 5; i++) math.Point(8 - i, 9)];
  math.Point<int> dir = const math.Point(1, 0);
  math.Point<int>? queued, food;
  bool running = false, dead = false;
  int eaten = 0;
  Timer? timer;
  final Stopwatch clock = Stopwatch()..start();
  int lastTick = 0;
  final Set<int> walls = {};
  final ValueNotifier<int> repaint = ValueNotifier(0);
  Offset? start;
  bool moved = false;

  int key(int a, int b) => b * cols + a;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mode = selectedSnakeMode;
    final level = h.level;
    layout = 1 + rng.nextInt(99999);
    random = math.Random(layout);
    goal = (mode == 'Calm' ? 8 : mode == 'Hedges' ? 10 : mode == 'Sprint' ? 12 : 15) + math.min(50, level * 2);
    base = math.max(mode == 'Sprint' ? 65 : 72, (mode == 'Calm' ? 154 : mode == 'Hedges' ? 143 : mode == 'Sprint' ? 103 : 121) - level * (mode == 'Calm' ? 4 : 6));
    final obstacleCount = mode == 'Calm' ? 0 : mode == 'Hedges' ? math.min(44, 7 + level * 3) : mode == 'Sprint' ? math.min(18, 3 + level) : math.min(64, 16 + level * 4);
    for (var attempts = 0; walls.length < obstacleCount && attempts < obstacleCount * 20; attempts++) {
      final x = random.nextInt(cols), y = random.nextInt(rows);
      if ((y - 9).abs() <= 2 && x >= 2 && x <= 12) continue;
      if ((x == 0 && y == 0) || (x == cols - 1 && y == rows - 1)) continue;
      walls.add(key(x, y));
    }
    food = freeCell();
    h.initial(status: '$mode · $goal petals · Layout $layout. Swipe or tap to steer.', progress: 0, extra: controls(), variants: variantBar(h, snakeModes, mode, (m) => selectedSnakeMode = m, 'New layout', compact: true, showNew: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    repaint.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed && running) {
      running = false;
      timer?.cancel();
      h.setStatus('Paused · tap a direction to continue.');
    }
  }

  math.Point<int>? freeCell() {
    final options = <math.Point<int>>[
      for (var y = 0; y < rows; y++)
        for (var a = 0; a < cols; a++)
          if (!walls.contains(key(a, y)) && !body.any((p) => p.x == a && p.y == y)) math.Point(a, y)
    ];
    return options.isEmpty ? null : options[random.nextInt(options.length)];
  }

  void over() {
    dead = true;
    running = false;
    timer?.cancel();
    strongHaptic();
    h.fail('Petals collected · $eaten of $goal. Try another round.');
  }

  void step() {
    if (queued != null) {
      dir = queued!;
      queued = null;
    }
    final hd = math.Point(body[0].x + dir.x, body[0].y + dir.y);
    final ate = food != null && hd.x == food!.x && hd.y == food!.y;
    final check = ate ? body : body.sublist(0, body.length - 1);
    if (hd.x < 0 || hd.y < 0 || hd.x >= cols || hd.y >= rows || walls.contains(key(hd.x, hd.y)) || check.any((s) => s.x == hd.x && s.y == hd.y)) {
      repaint.value++;
      over();
      return;
    }
    body.insert(0, hd);
    if (ate) {
      eaten++;
      h.setProgress(eaten, goal);
      tickHaptic();
      if (eaten >= goal) {
        running = false;
        timer?.cancel();
        repaint.value++;
        h.complete('Every petal collected · $goal petals');
        return;
      }
      food = freeCell();
      h.setStatus('Petals collected · $eaten of $goal');
    } else {
      body.removeLast();
    }
    repaint.value++;
  }

  void schedule(int ms) {
    timer?.cancel();
    if (running && !dead && !h.completed) timer = Timer(Duration(milliseconds: ms), advance);
  }

  void advance() {
    if (!running || dead || h.completed) return;
    step();
    lastTick = clock.elapsedMilliseconds;
    schedule(math.max(65, base - eaten * 2));
  }

  void turn(int d) {
    final v = const [math.Point(0, -1), math.Point(1, 0), math.Point(0, 1), math.Point(-1, 0)][d];
    if (dead || h.completed) return;
    final last = queued ?? dir;
    if (v.x == -last.x && v.y == -last.y) return;
    if (!running) {
      if (v.x != last.x || v.y != last.y) queued = v;
      running = true;
      h.setStatus('Petals collected · $eaten of $goal');
      advance();
      return;
    }
    if (queued != null || (v.x == dir.x && v.y == dir.y)) return;
    queued = v;
    schedule(math.max(0, 45 - (clock.elapsedMilliseconds - lastTick)));
  }

  Widget controls() {
    final th = h.th;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final e in const [('←', 3), ('↓', 2), ('↑', 0), ('→', 1)]) ...[
        if (e.$2 != 3) const SizedBox(width: 10),
        _PadButton(th: th, label: e.$1, onDown: () => turn(e.$2)),
      ]
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth.isFinite ? bc.maxWidth : 360.0;
      return Center(
      child: SizedBox(
        width: w,
        child: Container(
          decoration: BoxDecoration(
              color: const Color(0xFFFBFAFF),
              border: Border.all(color: const Color(0xFFC4C4ED), width: 2),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: h.th.dark, blurRadius: 35, offset: const Offset(0, 12), spreadRadius: -23)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 17 / 18,
              child: LayoutBuilder(
                builder: (context, c) => Listener(
                  onPointerDown: (e) {
                    start = e.localPosition;
                    moved = false;
                  },
                  onPointerMove: (e) {
                    final s = start;
                    if (s == null) return;
                    final dx = e.localPosition.dx - s.dx, dy = e.localPosition.dy - s.dy;
                    if (math.sqrt(dx * dx + dy * dy) < 16) return;
                    moved = true;
                    turn(dx.abs() > dy.abs() ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0));
                    start = e.localPosition;
                  },
                  onPointerUp: (e) {
                    if (start == null || moved) {
                      start = null;
                      return;
                    }
                    start = null;
                    final tx = e.localPosition.dx / c.maxWidth * cols, ty = e.localPosition.dy / c.maxHeight * rows;
                    final hd = body[0], dx = tx - (hd.x + .5), dy = ty - (hd.y + .5);
                    if (math.sqrt(dx * dx + dy * dy) > 1.6) turn(dx.abs() > dy.abs() ? (dx > 0 ? 1 : 3) : (dy > 0 ? 2 : 0));
                  },
                  child: CustomPaint(painter: _SnakePainter(this, repaint)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    });
  }
}

class _PadButton extends StatefulWidget {
  final GameTheme th;
  final String label;
  final VoidCallback onDown;
  const _PadButton({required this.th, required this.label, required this.onDown});
  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    return Listener(
      onPointerDown: (_) {
        tickHaptic();
        setState(() => down = true);
        widget.onDown();
      },
      onPointerUp: (_) => setState(() => down = false),
      onPointerCancel: (_) => setState(() => down = false),
      child: Transform.translate(
        offset: Offset(0, down ? 3 : 0),
        child: Transform.scale(
          scale: down ? .98 : 1,
          child: Container(
            width: 64,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(begin: const Alignment(-.5, -1), end: const Alignment(.5, 1), colors: [Colors.white, th.soft]),
              border: Border.all(color: th.edge, width: 2),
              boxShadow: down
                  ? [BoxShadow(color: th.edge, offset: const Offset(0, 1))]
                  : [BoxShadow(color: th.edge, offset: const Offset(0, 4)), BoxShadow(color: th.dark, blurRadius: 22, offset: const Offset(0, 11), spreadRadius: -17)],
            ),
            child: Center(child: Text(widget.label, style: ts(31, FontWeight.w800, th.dark, height: 1))),
          ),
        ),
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  final _SnakeState s;
  _SnakePainter(this.s, Listenable repaint) : super(repaint: repaint);
  static const double S = 30;

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 17, rows = 18;
    const w = cols * S, h = rows * S;
    canvas.scale(size.width / w);
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF9F8FF), Color(0xFFF2F1FD)]).createShader(const Rect.fromLTWH(0, 0, w, h)));
    final grid = Paint()
      ..color = const Color(0xFFECE9F6)
      ..strokeWidth = .65
      ..style = PaintingStyle.stroke;
    for (var a = 1; a < cols; a++) {
      canvas.drawLine(Offset(a * S, 0), Offset(a * S, h), grid);
    }
    for (var y = 1; y < rows; y++) {
      canvas.drawLine(Offset(0, y * S), Offset(w, y * S), grid);
    }
    final dot = Paint()..color = const Color(0xFFD6D2EF);
    for (var y = 2; y < rows; y += 4) {
      for (var a = 2; a < cols; a += 4) {
        canvas.drawCircle(Offset((a + .5) * S, (y + .5) * S), 1.7, dot);
      }
    }
    for (final k in s.walls) {
      final a = k % cols, b = k ~/ cols, px = a * S + 4, py = b * S + 4;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px, py, S - 8, S - 8), const Radius.circular(7)), Paint()..color = const Color(0xFFADA7C8));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(px + 4, py + 3, S - 16, 3), const Radius.circular(3)), Paint()..color = const Color(0x77FFFFFF));
    }
    final food = s.food;
    if (food != null) {
      final cx = (food.x + .5) * S, cy = (food.y + .5) * S;
      final petal = Paint()
        ..color = const Color(0xFFED6F9B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      final solid = Paint()..color = const Color(0xFFED6F9B);
      for (var q = 0; q < 5; q++) {
        final a = q * math.pi * 2 / 5 - math.pi / 2;
        canvas.save();
        canvas.translate(cx + math.cos(a) * 7, cy + math.sin(a) * 7);
        canvas.rotate(a);
        final r = Rect.fromCenter(center: Offset.zero, width: 11, height: 14.6);
        canvas.drawOval(r, petal..color = const Color(0x77E76C9A));
        canvas.drawOval(r, solid);
        canvas.restore();
      }
      canvas.drawCircle(Offset(cx, cy), 4.6, Paint()..color = const Color(0xFFFFE1A0));
      final leaf = Path()
        ..moveTo(cx + 6, cy - 9)
        ..quadraticBezierTo(cx + 10, cy - 14, cx + 15, cy - 10);
      canvas.drawPath(leaf, Paint()
        ..color = const Color(0xFF68A48A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
    Offset center(math.Point<int> p) => Offset((p.x + .5) * S, (p.y + .5) * S);
    final segs = s.body.reversed.toList();
    if (segs.length > 1) {
      final path = Path();
      for (var i = 0; i < segs.length; i++) {
        final c = center(segs[i]);
        i == 0 ? path.moveTo(c.dx, c.dy) : path.lineTo(c.dx, c.dy);
      }
      Paint line(double wdt) => Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = wdt;
      canvas.drawPath(path, line(S * .83)
        ..color = const Color(0xFF6379CE)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(
          path,
          line(S * .76)
            ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8096ED), Color(0xFF5C75D3), Color(0xFF3B54B2)], stops: [0, .6, 1])
                .createShader(const Rect.fromLTWH(0, 0, w, h)));
      canvas.drawPath(path, line(S * .17)..color = const Color(0x26FFFFFF));
    }
    canvas.drawCircle(center(s.body.last), S * .28, Paint()..color = const Color(0xFF94A4ED));
    final hc = center(s.body[0]);
    final headRect = Rect.fromCenter(center: hc, width: S * .94, height: S * .90);
    canvas.drawOval(headRect, Paint()
      ..color = const Color(0x7A3F52A9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawOval(headRect, Paint()..shader = ui.Gradient.linear(hc - const Offset(S * .4, S * .4), hc + const Offset(S * .4, S * .4), [const Color(0xFF7089ED), const Color(0xFF354AA1)]));
    final right = Offset(s.dir.x.toDouble(), s.dir.y.toDouble()), side = Offset(-s.dir.y.toDouble(), s.dir.x.toDouble());
    for (final sign in [-1.0, 1.0]) {
      final e = hc + right * (S * .14) + side * (S * .17 * sign);
      canvas.drawCircle(e, S * .111, Paint()..color = Colors.white);
      canvas.drawCircle(e + right * (S * .022), S * .054, Paint()..color = const Color(0xFF26346C));
    }
    canvas.drawCircle(hc + right * (S * .31), S * .045, Paint()..color = const Color(0xFFF2B2D4));
    canvas.drawOval(Rect.fromCenter(center: hc - side * (S * .21) - right * (S * .14), width: S * .18, height: S * .10), Paint()..color = const Color(0x44FFFFFF));
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
