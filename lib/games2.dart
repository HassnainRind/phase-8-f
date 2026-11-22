// Letter garden (words) and Minesweeper (mines) ports.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_core.dart';
import 'game_shell.dart';
import 'games.dart';
import 'theme.dart';
import 'widgets.dart';

// ============================================================== Letter garden
const wordModes = ['Bloom', 'Breeze', 'Thorns', 'Twilight', 'Sprint', 'Wildflower'];
String selectedWordMode = 'Bloom';

class WordData {
  static List<List<String>>? words;
  static Map<String, String>? clues;
  static Future<void> load() async {
    if (words != null) return;
    final j = jsonDecode(await rootBundle.loadString('assets/data/words.json')) as Map<String, dynamic>;
    words = (j['words'] as List).map((e) => [e[0] as String, e[1] as String]).toList();
    clues = Map<String, String>.from(j['clues'] as Map);
  }
}

class _Pick {
  final String word, cat, key;
  final int v, count;
  final bool recycled;
  _Pick(this.word, this.cat, this.key, this.v, this.count, this.recycled);
}

const _uniqueKey = 'rainlight_unique_games_v3';

Future<_Pick> pickGardenWord(String mode, int level, int seed) async {
  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic> store = {};
  try {
    store = Map<String, dynamic>.from(jsonDecode(prefs.getString(_uniqueKey) ?? '{}') as Map);
  } catch (_) {}
  final mem = Map<String, dynamic>.from((store['words'] as Map?) ?? {'seen': [], 'used': {}});
  var seen = Set<String>.from((mem['seen'] as List?) ?? []);
  var used = Map<String, int>.from(((mem['used'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
  final all = WordData.words!;
  final desired = math.min(10, 4 + ((level - 1) / 3).floor());
  final minLen = math.max(4, desired - 1), maxLen = math.min(10, desired + 1);
  List<_Pick> gather(Iterable<List<String>> src, {bool zero = false}) {
    final out = <_Pick>[];
    for (final w in src) {
      for (var v = 0; v < 3; v++) {
        final key = '${w[0]}|$mode|$v';
        if (!seen.contains(key)) out.add(_Pick(w[0], w[1], key, v, zero ? 0 : (used[w[0]] ?? 0), false));
      }
    }
    return out;
  }

  var candidates = gather(all.where((w) => w[0].length >= minLen && w[0].length <= maxLen));
  if (candidates.isEmpty) candidates = gather(all);
  var recycled = false;
  if (candidates.isEmpty) {
    seen = {};
    used = {};
    recycled = true;
    candidates = gather(all, zero: true);
  }
  var never = candidates.where((x) => x.count == 0).toList();
  if (never.isEmpty) never = gather(all.where((w) => !used.containsKey(w[0]) || used[w[0]] == 0));
  final source = never.isNotEmpty ? never : candidates;
  final least = source.map((x) => x.count).reduce(math.min);
  final fresh = source.where((x) => x.count == least).toList();
  final p = fresh[seed % fresh.length];
  seen.add(p.key);
  used[p.word] = (used[p.word] ?? 0) + 1;
  store['words'] = {'seen': seen.toList(), 'used': used};
  try {
    await prefs.setString(_uniqueKey, jsonEncode(store));
  } catch (_) {}
  return _Pick(p.word, p.cat, p.key, p.v, p.count, recycled);
}

class WordsGame extends StatefulWidget {
  final GameHost host;
  const WordsGame(this.host, {super.key});
  @override
  State<WordsGame> createState() => _WordsState();
}

/// Letter garden: one scrambled word, a clue that is always visible, empty boxes to fill, and three buttons.
class _WordsState extends State<WordsGame> {
  GameHost get h => widget.host;
  bool ready = false, wrongShown = false;
  late String word, cat, clue;
  late List<String> letters;
  late List<int> order; // display order of the letter tiles
  late List<int?> slots; // which tile sits in each answer box
  int hintsLeft = 3;
  static const idle = 'Tap the letters in order to spell the word.';

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await WordData.load();
    final p = await pickGardenWord('Bloom', h.level, rng.nextInt(1 << 30));
    if (!mounted || h.disposed) return;
    word = p.word;
    cat = p.cat;
    clue = WordData.clues![word] ?? 'A ${word.length}-letter word from the ${cat.toLowerCase()} collection';
    final r = math.Random(rng.nextInt(1 << 30));
    letters = shuffle(word.split(''), r);
    if (letters.join() == word) letters = letters.reversed.toList();
    order = List<int>.generate(letters.length, (i) => i);
    slots = List<int?>.filled(word.length, null);
    h.setStatus(p.recycled ? 'You have played every word. A fresh series has begun.' : idle);
    setState(() => ready = true);
    sync();
  }

  Set<int> get used => slots.whereType<int>().toSet();

  void sync() => h.setProgress(slots.whereType<int>().length, word.length);

  void place(int i) {
    if (h.completed || used.contains(i)) return;
    final s = slots.indexOf(null);
    if (s < 0) return;
    tickHaptic();
    setState(() {
      slots[s] = i;
      wrongShown = false;
    });
    sync();
    if (!slots.contains(null)) check();
  }

  void check() {
    final guess = slots.map((i) => letters[i!]).join();
    if (guess == word) {
      h.complete('“${word.toLowerCase()}” · A new word has bloomed.');
    } else {
      softHaptic();
      setState(() => wrongShown = true);
      h.setStatus('Not quite. Tap a letter in the boxes to take it back out.');
    }
  }

  void remove(int s) {
    if (h.completed || slots[s] == null) return;
    setState(() {
      slots[s] = null;
      wrongShown = false;
    });
    sync();
    h.setStatus(idle);
  }

  void clearAll() {
    if (h.completed) return;
    setState(() {
      for (var k = 0; k < slots.length; k++) {
        slots[k] = null;
      }
      wrongShown = false;
    });
    sync();
    h.setStatus(idle);
  }

  void shuffleTiles() {
    if (h.completed) return;
    setState(() => order = shuffle(order));
  }

  void hint() {
    if (h.completed || hintsLeft == 0) return;
    var p = 0;
    while (p < slots.length && slots[p] != null && letters[slots[p]!] == word[p]) {
      p++;
    }
    if (p >= word.length) return;
    setState(() {
      for (var k = p; k < slots.length; k++) {
        slots[k] = null;
      }
      final u = used;
      final idx = [for (var i = 0; i < letters.length; i++) if (!u.contains(i) && letters[i] == word[p]) i];
      slots[p] = idx.first;
      hintsLeft--;
      wrongShown = false;
    });
    sync();
    if (!slots.contains(null)) {
      check();
    } else {
      h.setStatus('Hint: letter ${p + 1} is ${word[p]}.');
    }
  }

  Widget button(String label, VoidCallback onTap, {bool enabled = true}) {
    final th = h.th;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: Pressable(
          scale: .96,
          onTap: enabled ? onTap : null,
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .9), border: Border.all(color: th.edge, width: 1.5), borderRadius: BorderRadius.circular(23)),
            child: Center(child: Text(label, maxLines: 1, style: ts(13, FontWeight.w800, th.dark))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const SizedBox(height: 200);
    final th = h.th;
    return LayoutBuilder(builder: (context, bc) {
      final w = bc.maxWidth.isFinite ? bc.maxWidth : 340.0;
      final n = word.length;
      final slotW = math.min(48.0, (w - 6.0 * (n - 1)) / n);
      final perRow = math.min(letters.length, 6);
      final tile = math.min(58.0, (w - 10.0 * (perRow - 1)) / perRow);
      final u = used;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .85), border: Border.all(color: th.edge, width: 1.5), borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Row(children: [
              Text('CLUE', style: ts(10, FontWeight.w800, th.accent, ls: 1.4)),
              const Spacer(),
              Text('$cat · $n letters', style: ts(11, FontWeight.w700, th.dark)),
            ]),
            const SizedBox(height: 6),
            Text(clue, textAlign: TextAlign.center, style: ts(16, FontWeight.w800, th.dark, height: 1.3)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var s = 0; s < n; s++) ...[
            if (s > 0) const SizedBox(width: 6),
            Pressable(
              scale: .95,
              onTap: slots[s] == null ? null : () => remove(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: slotW,
                height: math.max(44.0, slotW * 1.15),
                decoration: BoxDecoration(
                  color: slots[s] == null ? const Color.fromRGBO(255, 255, 255, .55) : (wrongShown ? const Color(0xFFF5BFB9) : th.soft),
                  border: Border.all(color: wrongShown && slots[s] != null ? const Color(0xFFD2695F) : (slots[s] == null ? th.edge : th.accent), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(slots[s] == null ? '' : letters[slots[s]!], style: ts(slotW * .55, FontWeight.w800, th.dark, height: 1))),
              ),
            ),
          ]
        ]),
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final i in order)
            Opacity(
              opacity: u.contains(i) ? .2 : 1,
              child: Pressable(
                scale: .92,
                onTap: u.contains(i) ? null : () => place(i),
                child: Container(
                  width: tile,
                  height: tile,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(begin: const Alignment(-.5, -1), end: const Alignment(.5, 1), colors: [Colors.white, th.soft]),
                    border: Border.all(color: th.edge, width: 2),
                    boxShadow: [BoxShadow(color: th.edge, offset: const Offset(0, 3))],
                  ),
                  child: Center(child: Text(letters[i], style: ts(tile * .5, FontWeight.w800, th.dark, height: 1))),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          button('Shuffle', shuffleTiles, enabled: !h.completed),
          const SizedBox(width: 10),
          button('Clear', clearAll, enabled: !h.completed && u.isNotEmpty),
          const SizedBox(width: 10),
          button('Hint ($hintsLeft)', hint, enabled: !h.completed && hintsLeft > 0),
        ]),
      ]);
    });
  }
}

// ============================================================== Minesweeper (thorns)
class MinesGame extends StatefulWidget {
  final GameHost host;
  const MinesGame(this.host, {super.key});
  @override
  State<MinesGame> createState() => _MinesState();
}

class _MinesState extends State<MinesGame> {
  GameHost get h => widget.host;
  int n = 8, total = 64, count = 10;
  Set<int> mine = {}, open = {}, flags = {};
  bool started = false, over = false, flagMode = false, built = false;
  late ToolSpec toggle;
  Timer? holdTimer;
  bool held = false;
  static const numColors = {
    1: Color(0xFF2563EB),
    2: Color(0xFF15803D),
    3: Color(0xFFDC2626),
    4: Color(0xFF7E22CE),
    5: Color(0xFFB45309),
    6: Color(0xFFB45309)
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (built) return;
    built = true;
    final mq = MediaQuery.of(context);
    final cap = (mq.size.width < 380 || mq.size.height < 640) ? 9 : (mq.size.width < 430 ? 10 : 12);
    n = math.min(cap, 8 + ((h.level - 1) / 2).floor());
    total = n * n;
    count = math.min((total * .26).floor(), (total * (.15 + math.min(h.level, 15) * .008)).round());
    toggle = ToolSpec('⚑ Flag mode: off', () {
      flagMode = !flagMode;
      toggle.label = '⚑ Flag mode: ${flagMode ? 'on' : 'off'}';
      toggle.on = flagMode;
      h.changed();
    });
    h.initial(status: 'Find the $count thorns. Tap to reveal · hold to flag.', progress: 0, tools: [toggle]);
  }

  @override
  void dispose() {
    holdTimer?.cancel();
    super.dispose();
  }

  List<int> nb(int i) {
    final r = i ~/ n, c = i % n;
    final o = <int>[];
    for (var a = -1; a <= 1; a++) {
      for (var b = -1; b <= 1; b++) {
        if (a == 0 && b == 0) continue;
        final y = r + a, x = c + b;
        if (y >= 0 && y < n && x >= 0 && x < n) o.add(y * n + x);
      }
    }
    return o;
  }

  int around(int i) => nb(i).where(mine.contains).length;

  void flag(int i) {
    if (h.completed || over || open.contains(i)) return;
    setState(() => flags.contains(i) ? flags.remove(i) : flags.add(i));
    h.setStatus('Thorns left to mark · ${math.max(0, count - flags.length)}');
  }

  void tap(int i) {
    if (h.completed || over) return;
    if (flagMode) {
      flag(i);
      return;
    }
    if (flags.contains(i) || open.contains(i)) return;
    if (!started) {
      started = true;
      final bad = {i, ...nb(i)};
      mine = shuffle([for (var k = 0; k < total; k++) if (!bad.contains(k)) k]).take(count).toSet();
    }
    if (mine.contains(i)) {
      setState(() => over = true);
      h.fail('A thorn! You cleared ${open.length} cells.');
      return;
    }
    final q = [i];
    setState(() {
      while (q.isNotEmpty) {
        final k = q.removeLast();
        if (open.contains(k) || flags.contains(k)) continue;
        open.add(k);
        if (around(k) == 0) {
          for (final j in nb(k)) {
            if (!open.contains(j)) q.add(j);
          }
        }
      }
    });
    h.setProgress(open.length, total - count);
    if (open.length == total - count) {
      h.complete('Every thorn avoided · $count found');
    } else {
      h.setStatus('Safe so far · ${total - count - open.length} cells to go');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = (MediaQuery.of(context).size.width * .036).clamp(12.0, 20.0).toDouble();
    return grid(n, 3, [
      for (var i = 0; i < total; i++) cell(i, f),
    ]);
  }

  Widget cell(int i, double f) {
    final isOpen = open.contains(i), isFlag = flags.contains(i), boom = over && mine.contains(i);
    final k = isOpen ? around(i) : 0;
    final c = GameCell(
      th: h.th,
      index: i,
      text: boom ? '✹' : isOpen ? (k > 0 ? '$k' : '') : isFlag ? '⚑' : '',
      radius: 8,
      font: f,
      shadowY: 2,
      bgOverride: boom ? const Color(0xFFFCA5A5) : isOpen ? Colors.white : null,
      borderOverride: boom ? const Color(0xFFDC2626) : isOpen ? h.th.soft : null,
      fgOverride: boom ? const Color(0xFF7F1D1D) : isOpen ? (numColors[k] ?? h.th.dark) : isFlag ? const Color(0xFFDC2626) : null,
      noShadow: isOpen,
      shake: boom ? 1 : 0,
      onTap: () {
        if (held) {
          held = false;
          return;
        }
        tap(i);
      },
    );
    return Listener(
      onPointerDown: (_) {
        held = false;
        holdTimer?.cancel();
        holdTimer = Timer(const Duration(milliseconds: 420), () {
          held = true;
          flag(i);
          successHaptic();
        });
      },
      onPointerUp: (_) => holdTimer?.cancel(),
      onPointerCancel: (_) => holdTimer?.cancel(),
      child: c,
    );
  }
}
