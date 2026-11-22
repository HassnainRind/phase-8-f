// Ports of the website's mini-games: Petal pairs, Little mosaic, Petalhaven rhythm,
// Noughts & crosses, Lantern lights and Number trail.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_core.dart';
import 'games2.dart';
import 'games3.dart';
import 'game_shell.dart';
import 'theme.dart';
import 'widgets.dart';

const implementedGames = {'memory', 'slider', 'sequence', 'crosses', 'lights', 'trail', 'words', 'mines', 'maze', 'snake'};

Future<void> openGame(BuildContext context, List<dynamic> g) {
  final id = g[0] as String, title = g[1] as String, emblem = g[3] as String, theme = g[4] as String;
  GameBuilder b;
  double? maxBoard;
  double minSide = 220, hOff = 300;
  double? fixedW;
  const noScroll = true; // every game fits on one screen
  double chrome = 150, aspect = 1.0; // chrome = stage height used by everything except the board
  switch (id) {
    case 'memory':
      b = (h) => MemoryGame(h);
      break;
    case 'slider':
      b = (h) => SliderGame(h);
      break;
    case 'sequence':
      b = (h) => SequenceGame(h);
      maxBoard = 330;
      chrome = 175;
      break;
    case 'crosses':
      b = (h) => CrossesGame(h);
      break;
    case 'lights':
      b = (h) => LightsGame(h);
      maxBoard = 340;
      chrome = 165;
      break;
    case 'words':
      b = (h) => WordsGame(h);
      maxBoard = 390;
      chrome = 0;
      aspect = 10; // the word board is not square: width comes from maxBoard
      break;
    case 'mines':
      b = (h) => MinesGame(h);
      chrome = 175;
      break;
    case 'maze':
      b = (h) => MazeGame(h);
      chrome = 330;
      break;
    case 'snake':
      b = (h) => SnakeGame(h);
      chrome = 180;
      aspect = 17 / 18;
      break;
    default:
      b = (h) => TrailGame(h);
  }
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => GamePage(id: id, title: title, emblem: emblem, themeName: theme, builder: b, cap: maxBoard, fixedWidth: fixedW, boardMin: minSide, heightOffset: hOff, noScroll: noScroll, chrome: chrome, aspect: aspect),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: easeCurve),
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: easeCurve)), child: child)),
  ));
}

double cellFont(BuildContext c, {double lo = 18, double hi = 30, double vw = 5}) => (MediaQuery.of(c).size.width * vw / 100).clamp(lo, hi).toDouble();
double boardGap(BuildContext c, [double normal = 9]) => MediaQuery.of(c).size.width <= 350 ? 7 : normal;

Widget grid(int columns, double gap, List<Widget> kids) => GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
      children: kids,
    );

// ============================================================== Petal pairs
class MemoryGame extends StatefulWidget {
  final GameHost host;
  const MemoryGame(this.host, {super.key});
  @override
  State<MemoryGame> createState() => _MemoryState();
}

class _MemoryState extends State<MemoryGame> {
  GameHost get h => widget.host;
  late final int count, maxMoves, cols;
  late final List<String> values;
  late final List<bool> shown, done;
  int? first;
  bool busy = false;
  int matches = 0, moves = 0;
  static const glyphs = ['✿', '☾', '✧', '♡', '☂', '❀', '☀', '♧', '♫', '◇', '☁', '✹', '❁', '☽', '♢', '✺', '❄', '★'];

  @override
  void initState() {
    super.initState();
    count = math.min(18, 10 + ((h.level - 1) / 2).floor());
    final icons = shuffle(glyphs).take(count).toList();
    values = shuffle([...icons, ...icons]);
    maxMoves = (count * (2.4 - math.min(h.level, 16) * .03)).ceil();
    cols = count <= 10 ? 5 : 6;
    shown = List.filled(values.length, false);
    done = List.filled(values.length, false);
    h.initial(status: 'Find $count pairs in $maxMoves moves.', progress: 0);
  }

  void tap(int i) {
    if (h.completed || busy || done[i] || i == first) return;
    setState(() => shown[i] = true);
    if (first == null) {
      first = i;
      return;
    }
    moves++;
    final a = first!;
    if (values[a] == values[i]) {
      setState(() => done[a] = done[i] = true);
      first = null;
      matches++;
      h.setProgress(matches, count);
      h.setStatus('$matches / $count pairs · ${maxMoves - moves} moves left');
      if (matches == count) h.complete('Every petal found · $moves moves');
    } else {
      busy = true;
      if (moves >= maxMoves) {
        h.later(() => h.fail('Out of moves · $matches of $count pairs found.'), 500);
        return;
      }
      h.setStatus('Moves left · ${maxMoves - moves}');
      h.later(() {
        if (!mounted) return;
        setState(() => shown[a] = shown[i] = false);
        first = null;
        busy = false;
      }, math.max(300, 700 - h.level * 25));
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width <= 350;
    return grid(cols, narrow ? 5 : 9, [
      for (var i = 0; i < values.length; i++)
        GameCell(
          th: h.th,
          index: i,
          text: shown[i] || done[i] ? values[i] : '✦',
          revealed: shown[i] && !done[i],
          matched: done[i],
          flip: true,
          restFg: h.th.accent,
          font: narrow ? 20 : cellFont(context),
          onTap: () => tap(i),
        ),
    ]);
  }
}

// ============================================================== Little mosaic
class SliderGame extends StatefulWidget {
  final GameHost host;
  const SliderGame(this.host, {super.key});
  @override
  State<SliderGame> createState() => _SliderState();
}

class _SliderState extends State<SliderGame> {
  GameHost get h => widget.host;
  late final int size;
  late List<int> board;
  int moves = 0;
  final Map<int, int> nope = {};

  @override
  void initState() {
    super.initState();
    size = math.min(6, 5 + ((h.level - 1) / 8).floor());
    board = slidingBoard(size, 150 + math.min(h.level, 40) * 12);
    h.initial(status: 'Order 1–${size * size - 1}. Leave the empty space last.', progress: _placed() / (size * size - 1));
  }

  int _placed() {
    var n = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != 0 && board[i] == i + 1) n++;
    }
    return n;
  }

  void tap(int v) {
    if (h.completed) return;
    final i = board.indexOf(v);
    final next = slide(board, i);
    if (next == null) {
      setState(() => nope[v] = (nope[v] ?? 0) + 1);
      h.setStatus('Choose a tile beside the empty space.');
      return;
    }
    setState(() {
      board = next;
      moves++;
    });
    h.setStatus('$moves moves · $size × $size mosaic');
    h.setProgress(_placed(), size * size - 1);
    if (solved(board)) h.complete('Everything in place · $moves moves');
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(color: h.th.soft, borderRadius: BorderRadius.circular(28)),
        child: LayoutBuilder(builder: (_, c) {
          final pitch = c.maxWidth / size;
          return Stack(children: [
            for (var v = 1; v < size * size; v++)
              AnimatedPositioned(
                key: ValueKey(v),
                duration: const Duration(milliseconds: 240),
                curve: easeCurve,
                left: (board.indexOf(v) % size) * pitch + 5,
                top: (board.indexOf(v) ~/ size) * pitch + 5,
                width: pitch - 10,
                height: pitch - 10,
                child: GameCell(th: h.th, index: v, text: '$v', shake: nope[v] ?? 0, shakeAmp: 3, font: cellFont(context), onTap: () => tap(v)),
              ),
          ]);
        }),
      ),
    );
  }
}

// ============================================================== Petalhaven rhythm
class SequenceGame extends StatefulWidget {
  final GameHost host;
  const SequenceGame(this.host, {super.key});
  @override
  State<SequenceGame> createState() => _SequenceState();
}

class _SequenceState extends State<SequenceGame> with WidgetsBindingObserver {
  GameHost get h => widget.host;
  late final int length, pc, speed;
  late final List<int> pattern;
  final Set<int> lit = {};
  int input = 0;
  bool waiting = false, showing = false, padsOn = false;
  late final ToolSpec repeat = ToolSpec('Play sequence', play);
  static const glyphs = ['✿', '♡', '☾', '✧', '☂', '❀', '☀', '♫', '◇'];
  static const rest = [
    [null, null],
    [Color(0xFFF4DCE9), Color(0xFFA4517E)],
    [Color(0xFFDCE9F6), Color(0xFF527BA4)],
    [Color(0xFFEFE5C9), Color(0xFF917039)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    length = math.min(24, 4 + ((h.level - 1) * .9).floor());
    pc = h.level < 4 ? 4 : (h.level < 8 ? 6 : 9);
    speed = math.max(240, 640 - h.level * 22);
    pattern = List.generate(length, (_) => rng.nextInt(pc));
    h.initial(status: 'Watch, remember, then play it back.', progress: 0, tools: [repeat]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) {
      h.cancelTimers();
      waiting = false;
      showing = false;
      repeat.enabled = !h.completed;
      setState(() {
        lit.clear();
        padsOn = false;
      });
      if (!h.completed) h.setStatus('Paused. Replay when you are ready.');
      h.changed();
    }
  }

  void play() {
    if (showing || h.completed) return;
    h.cancelTimers();
    waiting = false;
    showing = true;
    input = 0;
    h.setProgress(0, length);
    repeat.enabled = false;
    h.setStatus('Watch the lights · $length notes');
    setState(() => padsOn = false);
    for (var i = 0; i < pattern.length; i++) {
      final v = pattern[i];
      h.later(() {
        GameSound.note(v);
        setState(() => lit.add(v));
      }, 200 + i * speed);
      h.later(() => setState(() => lit.remove(v)), (200 + i * speed + speed * .62).round());
    }
    h.later(() {
      showing = false;
      waiting = true;
      repeat.enabled = true;
      repeat.label = 'Replay sequence';
      setState(() => padsOn = true);
      h.setStatus('Your turn · repeat the $length notes');
    }, length * speed + 220);
  }

  void pad(int i) {
    if (!waiting || h.completed) return;
    setState(() => lit.add(i));
    h.later(() => setState(() => lit.remove(i)), 170);
    if (i != pattern[input]) {
      waiting = false;
      h.fail('Wrong note · you reached $input of $length.');
      return;
    }
    GameSound.note(i);
    input++;
    h.setProgress(input, length);
    if (input == length) {
      waiting = false;
      setState(() => padsOn = false);
      repeat.enabled = false;
      h.complete('A perfect little rhythm.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return grid(pc == 9 ? 3 : 2, 16, [
      for (var i = 0; i < pc; i++)
        GameCell(
          th: h.th,
          index: i,
          text: glyphs[i],
          lit: lit.contains(i),
          restBg: i >= 1 && i <= 3 ? rest[i][0] : null,
          restFg: i >= 1 && i <= 3 ? rest[i][1] : null,
          radius: 32,
          font: 44,
          onTap: padsOn ? () => pad(i) : null,
        ),
    ]);
  }
}

// ============================================================== Noughts & crosses (k in a row)
class CrossesGame extends StatefulWidget {
  final GameHost host;
  const CrossesGame(this.host, {super.key});
  @override
  State<CrossesGame> createState() => _CrossesState();
}

class _CrossesState extends State<CrossesGame> {
  GameHost get h => widget.host;
  late final int size, k, n;
  late final List<String> board;
  final List<List<int>> wins = [];
  bool busy = false, ended = false;

  @override
  void initState() {
    super.initState();
    size = math.min(7, 5 + ((h.level - 1) / 6).floor());
    k = size >= 7 ? 5 : 4;
    n = size * size;
    board = List.filled(n, '');
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        for (final d in const [[0, 1], [1, 0], [1, 1], [1, -1]]) {
          final line = <int>[];
          for (var i = 0; i < k; i++) {
            final y = r + d[0] * i, x = c + d[1] * i;
            if (y < 0 || y >= size || x < 0 || x >= size) break;
            line.add(y * size + x);
          }
          if (line.length == k) wins.add(line);
        }
      }
    }
    final opens = h.level % 2 == 0;
    h.initial(status: opens ? 'The app opens this round.' : 'Get $k in a row on a $size×$size board. You are ×.', progress: 0);
    if (opens) ai();
  }

  bool won(String m) => wins.any((l) => l.every((i) => board[i] == m));

  void put(int i, String m) {
    setState(() => board[i] = m);
    h.setProgress(board.where((e) => e.isNotEmpty).length, n);
  }

  bool finish() {
    if (won('X')) {
      ended = true;
      h.complete('Your $k in a row! Beautiful.');
      return true;
    }
    if (won('O')) {
      ended = true;
      h.fail('The app made $k in a row.');
      return true;
    }
    if (board.every((e) => e.isNotEmpty)) {
      ended = true;
      h.complete('Board full: a draw. On to the next round.');
      return true;
    }
    return false;
  }

  int pick() {
    final e = <int>[for (var i = 0; i < n; i++) if (board[i].isEmpty) i];
    for (final m in const ['O', 'X']) {
      for (final i in e) {
        board[i] = m;
        final w = won(m);
        board[i] = '';
        if (w) return i;
      }
    }
    if (rng.nextDouble() < math.max(0, .3 - h.level * .04)) return e[rng.nextInt(e.length)];
    var best = -1;
    double bs = -1;
    for (final i in e) {
      double s = rng.nextDouble();
      for (final l in wins) {
        if (!l.contains(i)) continue;
        final o = l.where((j) => board[j] == 'O').length, x = l.where((j) => board[j] == 'X').length;
        if (o > 0 && x > 0) continue;
        s += (1 + (o > 0 ? math.pow(9, o) : 0) + (x > 0 ? math.pow(7, x) : 0)).toDouble();
      }
      if (s > bs) {
        bs = s;
        best = i;
      }
    }
    return best;
  }

  void ai() {
    busy = true;
    h.later(() {
      final i = pick();
      if (i >= 0) put(i, 'O');
      busy = false;
      if (!finish()) h.setStatus('Your turn · $k in a row wins.');
    }, 400);
  }

  void tap(int i) {
    if (busy || ended || h.completed || board[i].isNotEmpty) return;
    put(i, 'X');
    if (!finish()) {
      h.setStatus('Thinking…');
      ai();
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = cellFont(context, lo: 16, hi: 26);
    return grid(size, boardGap(context), [
      for (var i = 0; i < n; i++)
        GameCell(
          th: h.th,
          index: i,
          text: board[i] == 'X' ? '×' : board[i] == 'O' ? '○' : '',
          revealed: board[i] == 'X',
          opponent: board[i] == 'O',
          font: f,
          onTap: board[i].isEmpty ? () => tap(i) : null,
        ),
    ]);
  }
}

// ============================================================== Lantern lights
class LightsGame extends StatefulWidget {
  final GameHost host;
  const LightsGame(this.host, {super.key});
  @override
  State<LightsGame> createState() => _LightsState();
}

class _LightsState extends State<LightsGame> {
  GameHost get h => widget.host;
  late final int size;
  late List<bool> board;
  late final Set<int> solution;
  int moves = 0;
  int? hint;

  @override
  void initState() {
    super.initState();
    size = math.min(7, 5 + ((h.level - 1) / 4).floor());
    final p = lightsPuzzle(size, 5 + math.min(h.level * 2, 30));
    board = p.board;
    solution = p.solution;
    h.initial(
      status: 'Turn every lantern off. A tap flips its neighbours too.',
      progress: board.where((v) => !v).length / board.length,
      tools: [
        ToolSpec('A little hint', () {
          if (h.completed || solution.isEmpty) return;
          setState(() => hint = solution.first);
          h.setStatus('Try the outlined lantern.');
        })
      ],
    );
  }

  void tap(int i) {
    if (h.completed) return;
    setState(() {
      board = toggleLights(board, i, size);
      solution.contains(i) ? solution.remove(i) : solution.add(i);
      moves++;
      hint = null;
    });
    h.setProgress(board.where((v) => !v).length, board.length);
    if (board.every((v) => !v)) h.complete('A peaceful night · $moves taps');
  }

  @override
  Widget build(BuildContext context) {
    return grid(size, boardGap(context, 9), [
      for (var i = 0; i < board.length; i++)
        GameCell(
          th: h.th,
          index: i,
          text: board[i] ? '☼' : '·',
          lit: board[i],
          hint: hint == i,
          litFg: const Color(0xFF705122),
          litGradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFE5A5), Color(0xFFDBB568)]),
          font: cellFont(context),
          onTap: () => tap(i),
        ),
    ]);
  }
}

// ============================================================== Number trail
class TrailGame extends StatefulWidget {
  final GameHost host;
  const TrailGame(this.host, {super.key});
  @override
  State<TrailGame> createState() => _TrailState();
}

class _TrailState extends State<TrailGame> {
  GameHost get h => widget.host;
  late final int size, n;
  late final List<int> numbers;
  final Set<int> doneSet = {};
  final Map<int, int> wrong = {}, hits = {};
  int next = 1, left = 0;
  bool locked = false;

  @override
  void initState() {
    super.initState();
    size = math.min(8, 5 + ((h.level - 1) / 3).floor());
    n = size * size;
    numbers = shuffle(List<int>.generate(n, (i) => i + 1));
    left = (n * 1.4 + 8).round();
    h.initial(status: 'Find 1 · ${left}s left', progress: 0);
    tick();
  }

  void upd() => h.setStatus('Find $next · ${left}s left');

  void tick() => h.later(() {
        if (h.completed) return;
        left--;
        if (left <= 0) {
          setState(() => locked = true);
          h.fail('Time is up · reached ${next - 1} of $n');
          return;
        }
        upd();
        tick();
      }, 1000);

  void tap(int v) {
    if (h.completed || doneSet.contains(v) || locked) return;
    if (v != next) {
      left = math.max(1, left - 3);
      setState(() => wrong[v] = (wrong[v] ?? 0) + 1);
      softHaptic();
      upd();
      return;
    }
    setState(() {
      doneSet.add(v);
      hits[v] = (hits[v] ?? 0) + 1;
    });
    next++;
    h.setProgress(next - 1, n);
    if (next > n) {
      h.complete('Done with ${left}s to spare.');
    } else {
      upd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = cellFont(context, lo: 16, hi: 25, vw: 4.8);
    return grid(size, 7, [
      for (var i = 0; i < numbers.length; i++)
        GameCell(
          th: h.th,
          index: i,
          text: '${numbers[i]}',
          matched: doneSet.contains(numbers[i]),
          fadeMatched: true,
          trailStyle: true,
          hit: hits[numbers[i]] ?? 0,
          miss: wrong[numbers[i]] ?? 0,
          font: f,
          onTap: locked || doneSet.contains(numbers[i]) ? null : () => tap(numbers[i]),
        ),
    ]);
  }
}
