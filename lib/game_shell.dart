import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ themes ([data-theme=...])
class GameTheme {
  final Color accent, dark, soft, bg, glow, edge;
  const GameTheme(this.accent, this.dark, this.soft, this.bg, this.glow, this.edge);
}

const gameThemes = <String, GameTheme>{
  'violet': GameTheme(Color(0xFF7A5AD0), Color(0xFF3B2660), Color(0xFFECE4FB), Color(0xFFF8F4FF), Color(0xFFECE4FB), Color(0xFFD3C5F3)),
  'rose': GameTheme(Color(0xFFB0507A), Color(0xFF5A2A42), Color(0xFFF8E3EC), Color(0xFFFFF7FA), Color(0xFFF8E3EC), Color(0xFFECC3D4)),
  'sky': GameTheme(Color(0xFF3F78B0), Color(0xFF1F3F5E), Color(0xFFE1EEFA), Color(0xFFF5FAFF), Color(0xFFE1EEFA), Color(0xFFBFD8EE)),
  'peach': GameTheme(Color(0xFFC0704F), Color(0xFF6A3A28), Color(0xFFFBE8DC), Color(0xFFFFFAF6), Color(0xFFFBE8DC), Color(0xFFEFCDB8)),
  'sage': GameTheme(Color(0xFF5A8566), Color(0xFF2F4D38), Color(0xFFE3F1E4), Color(0xFFF7FBF5), Color(0xFFE3F1E4), Color(0xFFC3DCC6)),
  'gold': GameTheme(Color(0xFFA8802F), Color(0xFF5E4518), Color(0xFFF8EDCF), Color(0xFFFFFCF2), Color(0xFFF8EDCF), Color(0xFFE6D3A0)),
  'aqua': GameTheme(Color(0xFF3D8D92), Color(0xFF1F4F55), Color(0xFFDAF1EF), Color(0xFFF4FCFB), Color(0xFFDAF1EF), Color(0xFFB6E0DC)),
  'forest': GameTheme(Color(0xFF6B8F4E), Color(0xFF34502A), Color(0xFFE6F0D6), Color(0xFFF8FBF0), Color(0xFFE6F0D6), Color(0xFFCFE0B3)),
  'coral': GameTheme(Color(0xFFCC5F55), Color(0xFF6E2D28), Color(0xFFFBE0DC), Color(0xFFFFF8F6), Color(0xFFFBE0DC), Color(0xFFF0C3BD)),
  'night': GameTheme(Color(0xFF5668C8), Color(0xFF1F2860), Color(0xFFE0E5FA), Color(0xFFF5F6FF), Color(0xFFE0E5FA), Color(0xFFC1C9F0)),
};

const gameKey = 'rainlight.mini-games.v1';

Future<Map<String, dynamic>> loadRecords() async {
  try {
    final p = await SharedPreferences.getInstance();
    return Map<String, dynamic>.from(jsonDecode(p.getString(gameKey) ?? '{}') as Map);
  } catch (_) {
    return {};
  }
}

// ------------------------------------------------------------------ host: what each game talks to
class ToolSpec {
  String label;
  VoidCallback onTap;
  bool enabled, on;
  ToolSpec(this.label, this.onTap, {this.enabled = true, this.on = false});
}

class GameHost extends ChangeNotifier {
  final String id;
  final int level;
  final GameTheme th;
  String status = '';
  double progress = 0;
  bool completed = false, disposed = false;
  List<ToolSpec> tools = [];
  Widget? variants, extra;
  String? answer;
  bool hideProgress = false;
  void Function(String)? onComplete, onFail;
  void Function(int)? reopen;
  final Set<Timer> _timers = {};
  GameHost(this.id, this.level, this.th);

  void changed() {
    if (!disposed) notifyListeners();
  }

  void setStatus(String s) {
    status = s;
    changed();
  }

  void setProgress(num n, num total) {
    progress = (n / total).clamp(0.0, 1.0).toDouble();
    changed();
  }

  /// run after first frame (children build after the shell)
  void initial({String? status, double? progress, List<ToolSpec>? tools, Widget? variants, Widget? extra, String? answer}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (disposed) return;
      if (status != null) this.status = status;
      if (progress != null) this.progress = progress;
      if (tools != null) this.tools = tools;
      if (variants != null) this.variants = variants;
      if (extra != null) this.extra = extra;
      if (answer != null) this.answer = answer;
      notifyListeners();
    });
  }

  Timer later(VoidCallback fn, int ms) {
    late Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (!disposed) fn();
    });
    _timers.add(t);
    return t;
  }

  void cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void complete(String msg) {
    if (completed) return;
    completed = true;
    onComplete?.call(msg);
  }

  void fail(String msg) {
    if (completed) return;
    completed = true;
    onFail?.call(msg);
  }

  @override
  void dispose() {
    disposed = true;
    cancelTimers();
    super.dispose();
  }
}

// ------------------------------------------------------------------ one board cell (".mini-board button")
class GameCell extends StatefulWidget {
  final GameTheme th;
  final String text;
  final VoidCallback? onTap;
  final int index;
  final bool revealed, matched, opponent, lit, hint, flip, fadeMatched;
  final double radius, font, shadowY;
  final Color? restBg, restFg, bgOverride, borderOverride, fgOverride;
  final bool noShadow;
  final Gradient? litGradient;
  final Color? litFg;
  final int shake, hit, miss;
  final double shakeAmp;
  final bool trailStyle;
  const GameCell(
      {super.key,
      required this.th,
      required this.text,
      this.onTap,
      this.index = 0,
      this.revealed = false,
      this.matched = false,
      this.opponent = false,
      this.lit = false,
      this.hint = false,
      this.flip = false,
      this.fadeMatched = false,
      this.radius = 14,
      this.font = 26,
      this.shadowY = 3,
      this.restBg,
      this.restFg,
      this.bgOverride,
      this.borderOverride,
      this.fgOverride,
      this.noShadow = false,
      this.litGradient,
      this.litFg,
      this.shake = 0,
      this.hit = 0,
      this.miss = 0,
      this.shakeAmp = 4,
      this.trailStyle = false});
  @override
  State<GameCell> createState() => _GameCellState();
}

class _GameCellState extends State<GameCell> with TickerProviderStateMixin {
  late final AnimationController arrive = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController flipC = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: 1);
  late final AnimationController pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);
  late final AnimationController shakeC = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  late final AnimationController hitC = AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  late final AnimationController missC = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  bool down = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: math.min(widget.index, 36) * 16), () {
      if (mounted) arrive.forward();
    });
  }

  @override
  void didUpdateWidget(GameCell old) {
    super.didUpdateWidget(old);
    if (widget.flip && widget.revealed && !old.revealed) flipC.forward(from: 0);
    if (widget.matched && !old.matched) pop.forward(from: 0);
    if (widget.shake != old.shake) shakeC.forward(from: 0);
    if (widget.hit != old.hit) hitC.forward(from: 0);
    if (widget.miss != old.miss) missC.forward(from: 0);
  }

  @override
  void dispose() {
    arrive.dispose();
    flipC.dispose();
    pop.dispose();
    shakeC.dispose();
    hitC.dispose();
    missC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: Listenable.merge([hitC, missC]), builder: (c, _) => _content(c));

  Widget _content(BuildContext context) {
    final th = widget.th;
    Color bg = th.soft, border = th.edge, fg = widget.restFg ?? th.dark;
    Gradient? g;
    List<BoxShadow> shadows = [BoxShadow(color: th.edge, offset: Offset(0, widget.shadowY))];
    if (widget.lit) {
      border = th.dark;
      fg = widget.litFg ?? Colors.white;
      if (widget.litGradient != null) {
        g = widget.litGradient;
        shadows = const [BoxShadow(color: Color(0x40D8AE54), blurRadius: 20)];
      } else {
        bg = th.accent;
        shadows = [BoxShadow(color: th.edge, spreadRadius: 3)];
      }
    } else if (widget.revealed) {
      bg = th.accent;
      border = th.accent;
      fg = Colors.white;
      shadows = [BoxShadow(color: th.dark, offset: Offset(0, widget.shadowY))];
    } else if (widget.matched && widget.trailStyle) {
      border = th.soft;
      fg = th.dark.withAlpha(97);
      shadows = const [];
    } else if (widget.matched) {
      bg = Colors.white;
      border = th.accent;
      fg = th.accent;
      shadows = const [];
    } else if (widget.opponent) {
      fg = th.accent;
    } else if (widget.restBg != null) {
      bg = widget.restBg!;
    }
    if (widget.bgOverride != null) bg = widget.bgOverride!;
    if (widget.borderOverride != null) border = widget.borderOverride!;
    if (widget.fgOverride != null) fg = widget.fgOverride!;
    if (widget.noShadow) shadows = const [];
    var hitScale = 1.0, missDx = 0.0;
    if (hitC.value < 1) {
      final t = hitC.value, s = t < .45 ? 0.0 : (t - .45) / .55, u = math.min(1.0, t / .45);
      bg = Color.lerp(th.accent, th.soft, s)!;
      border = Color.lerp(th.accent, th.soft, s)!;
      fg = Color.lerp(Colors.white, th.dark.withAlpha(97), s)!;
      shadows = t < .45 ? [BoxShadow(color: th.accent.withAlpha((115 * (1 - u)).round()), spreadRadius: 7 * u)] : const [];
      hitScale = .97 + .03 * u;
    }
    if (missC.value < 1) {
      final t = missC.value, s = t < .2 ? t / .2 : 1 - (t - .2) / .8;
      bg = Color.lerp(th.soft, const Color(0xFFF5BFB9), s)!;
      border = Color.lerp(th.edge, const Color(0xFFD2695F), s)!;
      fg = Color.lerp(th.dark, const Color(0xFF7A2A24), s)!;
      missDx = t < .2 ? -3 * (t / .2) : t < .5 ? -3 + 6 * ((t - .2) / .3) : t < .8 ? 3 - 4 * ((t - .5) / .3) : -1 + (t - .8) / .2;
    }
    final scale = (down ? .92 : (widget.fadeMatched && widget.matched ? .9 : 1.0)) * hitScale;
    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: easeCurve,
      decoration: BoxDecoration(
        color: g == null ? bg : null,
        gradient: g,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border, width: 2),
        boxShadow: shadows,
      ),
      foregroundDecoration: widget.hint ? BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), border: Border.all(color: th.dark, width: 3)) : null,
      child: Center(child: Text(widget.text, style: ts(widget.font, FontWeight.w800, fg, height: 1.1))),
    );
    cell = Opacity(opacity: widget.fadeMatched && widget.matched ? .4 : 1, child: cell);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => down = true),
      onTapUp: (_) => setState(() => down = false),
      onTapCancel: () => setState(() => down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              tickHaptic();
              widget.onTap!();
            },
      child: AnimatedBuilder(
        animation: Listenable.merge([arrive, flipC, pop, shakeC, hitC, missC]),
        builder: (_, child) {
          final a = easeCurve.transform(arrive.value);
          final popScale = 1 + .09 * math.sin(math.pi * Curves.easeInOut.transform(pop.value));
          final sh = (shakeC.value < 1 ? math.sin(shakeC.value * math.pi * 2) * -widget.shakeAmp : 0.0) + missDx;
          Widget w = Transform.translate(offset: Offset(sh, (1 - a) * 7), child: Opacity(opacity: a, child: child));
          w = Transform.scale(scale: popScale, child: w);
          if (flipC.value < 1) {
            w = Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 1 / 420)
                  ..rotateY((1 - Curves.easeOut.transform(flipC.value)) * math.pi / 2),
                child: w);
          }
          return w;
        },
        child: AnimatedScale(scale: scale, duration: const Duration(milliseconds: 350), curve: springCurve, child: cell),
      ),
    );
  }
}

// ------------------------------------------------------------------ the full-screen game page (".mini-shell")
typedef GameBuilder = Widget Function(GameHost host);

class GamePage extends StatefulWidget {
  final String id, title, emblem, themeName;
  final GameBuilder builder;
  final double? cap; // optional board max-width cap (css px)
  final double? fixedWidth;
  final double boardMin, heightOffset; // width: min(100%, 440, max(boardMin, screenH - heightOffset))
  /// Single-screen mode: no scrolling, board is sized from the space that is actually left.
  final bool noScroll;
  final double chrome; // height used by everything in the stage except the board (noScroll only)
  final double aspect; // board width / height (noScroll only)
  const GamePage(
      {super.key,
      required this.id,
      required this.title,
      required this.emblem,
      required this.themeName,
      required this.builder,
      this.cap,
      this.fixedWidth,
      this.boardMin = 220,
      this.heightOffset = 300,
      this.noScroll = false,
      this.chrome = 170,
      this.aspect = 1.0});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  int level = 1, boardKey = 0;
  late GameHost host = _newHost();
  Map<String, dynamic> records = {};
  String recordText = '';
  String? nextLabel;
  VoidCallback? onNext;
  int sparkKey = 0;
  late final AnimationController shakeBoard = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  GameTheme get th => gameThemes[widget.themeName] ?? gameThemes['violet']!;

  GameHost _newHost() {
    final h = GameHost(widget.id, level, th);
    h.onComplete = _complete;
    h.onFail = _fail;
    h.reopen = (lv) {
      if (mounted) setState(() => _reset(lv));
    };
    return h;
  }

  @override
  void initState() {
    super.initState();
    loadRecords().then((r) {
      if (mounted) setState(() {
            records = r;
            recordText = _baseRecord();
          });
    });
  }

  String _baseRecord() {
    final r = records[widget.id];
    final wins = (r is Map ? r['wins'] : 0) as int? ?? 0;
    final best = r is Map ? r['best'] : null;
    return '$wins ${wins == 1 ? 'round' : 'rounds'} completed${best != null ? ' · best level $best' : ''}';
  }

  void _reset(int newLevel) {
    host.dispose();
    level = newLevel;
    host = _newHost();
    boardKey++;
    nextLabel = null;
    onNext = null;
    recordText = _baseRecord();
  }

  Future<void> _complete(String msg) async {
    final r = Map<String, dynamic>.from((records[widget.id] as Map?) ?? {'wins': 0, 'best': null, 'level': 1});
    r['wins'] = ((r['wins'] as int?) ?? 0) + 1;
    final prevBest = (r['best'] as int?) ?? 0;
    final nb = level > prevBest;
    r['best'] = math.max(prevBest, level);
    records[widget.id] = r;
    try {
      (await SharedPreferences.getInstance()).setString(gameKey, jsonEncode(records));
    } catch (_) {}
    host.status = msg;
    host.progress = 1;
    successHaptic();
    GameSound.play('win');
    setState(() {
      recordText = 'Level $level complete${nb ? ' · new best!' : ' · best level ${r['best']}'}';
      nextLabel = 'Next level →';
      onNext = () => setState(() => _reset(level + 1));
      sparkKey++;
    });
    host.changed();
  }

  void _fail(String msg) {
    strongHaptic();
    GameSound.play('lose');
    host.status = msg;
    shakeBoard.forward(from: 0);
    setState(() {
      nextLabel = 'Try again ↻';
      onNext = () => setState(() => _reset(level));
    });
    host.changed();
  }

  @override
  void dispose() {
    host.dispose();
    shakeBoard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final short = mq.size.height <= 650, narrow = mq.size.width <= 350;
    final hPad = narrow ? 16.0 : 24.0;
    var bw = math.min(440.0, math.max(widget.boardMin, mq.size.height - widget.heightOffset));
    if (widget.cap != null) bw = math.min(bw, widget.cap!);
    if (widget.fixedWidth != null) bw = widget.fixedWidth!;
    return Scaffold(
      backgroundColor: th.bg,
      body: Stack(children: [
        Positioned.fill(
          child: Opacity(
            opacity: .5,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(-1, -.7), radius: 1.1, colors: [th.glow, th.glow.withAlpha(0)], stops: const [0, .5])),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(1, .7), radius: 1.1, colors: [th.soft, th.soft.withAlpha(0)], stops: const [0, .55])),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: EdgeInsets.fromLTRB(hPad, short ? 8 : 14, hPad, 24),
                child: AnimatedBuilder(
                  animation: host,
                  builder: (context, _) => Column(children: [
                    header(narrow),
                    if (!host.hideProgress) progressBar(),
                    Expanded(child: stage(short, bw)),
                    footer(),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget header(bool narrow) => Row(children: [
        Pressable(
          scale: .96,
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromRGBO(255, 255, 255, .7),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, .85)),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .45), blurRadius: 18, offset: Offset(0, 10), spreadRadius: -12)]),
            child: Center(child: Text('‹', style: ts(30, FontWeight.w400, th.dark, height: 1))),
          ),
        ),
        SizedBox(width: narrow ? 8 : 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PETALHAVEN PLAY', style: ts(10, FontWeight.w800, vio, ls: 1.6)),
            const SizedBox(height: 5),
            Text(widget.title, style: ts(21, FontWeight.w800, ink, ls: -.3)),
          ]),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12, vertical: narrow ? 8 : 9),
          decoration: BoxDecoration(color: th.soft, borderRadius: BorderRadius.circular(99)),
          child: Text('Level $level', style: ts(narrow ? 11 : 12, FontWeight.w800, th.dark)),
        ),
      ]);

  Widget progressBar() => Container(
        height: 8,
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        decoration: BoxDecoration(color: th.soft, borderRadius: BorderRadius.circular(10)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: easeCurve,
            widthFactor: host.progress.clamp(0.0, 1.0).toDouble(),
            child: Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [th.accent, Color.lerp(Colors.white, th.accent, .55)!]), borderRadius: BorderRadius.circular(10))),
          ),
        ),
      );

  Widget stage(bool short, double bw0) => LayoutBuilder(
        builder: (context, cons) {
          var bw = bw0;
          if (widget.noScroll) {
            bw = math.min(440.0, math.max(140.0, (cons.maxHeight - widget.chrome) * widget.aspect));
            if (widget.cap != null) bw = math.min(bw, widget.cap!);
          }
          final content = ConstrainedBox(
            constraints: BoxConstraints(minHeight: cons.maxHeight),
            child: Stack(alignment: Alignment.center, children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!short && !widget.noScroll)
                  Container(
                    width: 58,
                    height: 58,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xCFFFFFFF), th.soft]),
                      boxShadow: [BoxShadow(color: th.accent, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -18)],
                    ),
                    child: Center(child: Text(widget.emblem, style: TextStyle(fontSize: 32, color: th.accent))),
                  ),
                if (host.variants != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: host.variants!),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40, maxWidth: 360),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(host.status, textAlign: TextAlign.center, style: ts(13, FontWeight.w700, th.dark, height: 1.5)),
                  ),
                ),
                if (host.answer != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 58, maxWidth: 450),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: Text(host.answer!,
                            textAlign: TextAlign.center,
                            style: ts((MediaQuery.of(context).size.width * .05).clamp(19.0, 29.0).toDouble(), FontWeight.w800, th.dark, ls: 3.4)),
                      ),
                    ),
                  ),
                AnimatedBuilder(
                  animation: shakeBoard,
                  builder: (_, child) => Transform.translate(
                      offset: Offset(shakeBoard.isAnimating ? math.sin(shakeBoard.value * math.pi * 2) * -6 : 0, 0), child: child),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: bw), child: KeyedSubtree(key: ValueKey('$boardKey'), child: widget.builder(host)))),
                  ),
                ),
                if (host.extra != null) host.extra!,
                if (host.tools.isNotEmpty)
                  Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                    for (final t in host.tools)
                      Opacity(
                        opacity: t.enabled ? 1 : .55,
                        child: Pressable(
                          scale: .96,
                          onTap: t.enabled ? t.onTap : null,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 190),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                            decoration: BoxDecoration(
                                color: t.on ? th.accent : const Color.fromRGBO(255, 255, 255, .85),
                                border: Border.all(color: t.on ? th.accent : th.edge, width: 1.5),
                                borderRadius: BorderRadius.circular(30)),
                            child: Text(t.label, textAlign: TextAlign.center, style: ts(12, FontWeight.w800, t.on ? Colors.white : th.dark)),
                          ),
                        ),
                      ),
                  ]),
              ]),
              if (sparkKey > 0) Positioned.fill(child: IgnorePointer(child: Sparks(key: ValueKey(sparkKey), color: th.accent))),
            ]),
          );
          return widget.noScroll
              ? FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: cons.maxWidth, child: content))
              : SingleChildScrollView(child: content);
        },
      );

  Widget footer() => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Opacity(opacity: .8, child: SizedBox(height: 16, child: Text(recordText, textAlign: TextAlign.center, style: ts(12, FontWeight.w500, th.dark)))),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
            flex: nextLabel != null ? 36 : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Pressable(
                scale: .96,
                onTap: () => setState(() => _reset(level)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .85), border: Border.all(color: th.edge, width: 1.5), borderRadius: BorderRadius.circular(30)),
                  child: Center(child: Text('New board', style: ts(12, FontWeight.w800, th.dark))),
                ),
              ),
            ),
          ),
          if (nextLabel != null) const SizedBox(width: 12),
          if (nextLabel != null)
            Expanded(
              flex: 64,
              child: Pressable(
                scale: .96,
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                      color: th.accent,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: th.accent, blurRadius: 22, offset: const Offset(0, 14), spreadRadius: -14)]),
                  child: Center(child: Text(nextLabel!, style: ts(14, FontWeight.w800, Colors.white))),
                ),
              ),
            ),
        ]),
      ]);
}

/// celebratory sparks (".mini-spark")
class Sparks extends StatefulWidget {
  final Color color;
  const Sparks({super.key, required this.color});
  @override
  State<Sparks> createState() => _SparksState();
}

class _SparksState extends State<Sparks> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();
  final rand = math.Random();
  late final List<double> dist = List.generate(16, (_) => 90 + rand.nextDouble() * 80);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => Stack(children: [
          for (var i = 0; i < 16; i++) spark(i),
        ]),
      );

  Widget spark(int i) {
    final delay = i * 12 / 1500, dur = 1100 / 1500;
    final t = ((c.value - delay) / dur).clamp(0.0, 1.0).toDouble();
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final e = Curves.easeOut.transform(t);
    final a = i / 16 * 6.283;
    final dx = math.cos(a) * dist[i], dy = math.sin(a) * dist[i] - 40;
    return Align(
      alignment: const Alignment(0, -.16),
      child: Transform.translate(
        offset: Offset(dx * e, dy * e),
        child: Transform.rotate(angle: 200 * math.pi / 180 * e, child: Opacity(opacity: 1 - e, child: Text(['✿', '✧', '♡', '☾'][i % 4], style: TextStyle(fontSize: 22, color: widget.color)))),
      ),
    );
  }
}
