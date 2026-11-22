import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercise.dart';
import 'games.dart';
import 'theme.dart';
import 'tracker.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ shared bits
Widget glowBlob({double? left, double? right, double top = -50, double w = 340, double h = 340}) => Positioned(
      left: left,
      right: right,
      top: top,
      width: w,
      height: h,
      child: Breathe(
        seconds: 9,
        child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(radius: .48, colors: [Color(0xFFD3C5FB), Color(0x00D3C5FB)]))),
      ),
    );

/// ellipse radial gradient (closest-side) used by ".hero .ph::before"
class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = RadialGradient(
      radius: .5,
      colors: const [Color.fromRGBO(255, 255, 255, .75), Color.fromRGBO(226, 214, 251, .35), Color.fromRGBO(226, 214, 251, 0)],
      stops: const [0, .55, 1],
      transform: _EllipseGT(size),
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _EllipseGT extends GradientTransform {
  final Size size;
  const _EllipseGT(this.size);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = math.min(size.width, size.height);
    final sx = size.width / shortest, sy = size.height / shortest;
    final c = bounds.center;
    return Matrix4.identity()
      ..translate(c.dx, c.dy)
      ..scale(sx, sy)
      ..translate(-c.dx, -c.dy);
  }
}

/// the photo box (".hero .ph"): soft breathing glow behind + image (contain, opacity .88)
class HeroPhoto extends StatelessWidget {
  final String asset;
  final Alignment align;
  final double glowL, glowR, glowT, glowB;
  final Widget Function(Widget)? mask;
  const HeroPhoto({super.key, required this.asset, required this.align, required this.glowL, required this.glowR, required this.glowT, required this.glowB, this.mask});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final dpr = MediaQuery.of(context).devicePixelRatio;
          // decode at the size it is shown, not at the file's full resolution
          Widget img = Image.asset(asset, fit: BoxFit.contain, alignment: align, cacheWidth: w.isFinite ? (w * dpr).round() : null, filterQuality: FilterQuality.medium);
          if (mask != null) img = mask!(img);
          return RepaintBoundary(
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: w * glowL,
                right: w * glowR,
                top: h * glowT,
                bottom: h * glowB,
                // the gradient is already soft; the extra 10px live blur is not visible but cost a lot per frame
                child: Breathe(seconds: 9, child: CustomPaint(painter: _GlowPainter())),
              ),
              Positioned.fill(child: RepaintBoundary(child: Opacity(opacity: .88, child: img))),
            ]),
          );
        },
      );
}

Widget edgeMask(Widget child, {required List<double> h, required List<double> v}) => ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
              stops: h)
          .createShader(r),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                stops: v)
            .createShader(r),
        child: child,
      ),
    );

Widget listRow({required Widget leading, required Widget body, required Widget trailing, VoidCallback? onTap, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18), double gap = 0}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Pressable(
        scale: .96,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, .7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, .85)),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .45), blurRadius: 24, offset: Offset(0, 14), spreadRadius: -20)],
          ),
          child: Row(children: [leading, Expanded(child: body), trailing]),
        ),
      ),
    );

Widget h2(String s) => Padding(padding: const EdgeInsets.only(top: 24, bottom: 12), child: Text(s, style: ts(23, FontWeight.w800, ink, ls: -.3)));

// ------------------------------------------------------------------ Poses (s1)
class PosesScreen extends StatelessWidget {
  final Tracker tracker;
  final int token;
  const PosesScreen({super.key, required this.tracker, this.token = 0});

  @override
  Widget build(BuildContext context) {
    final w = math.min(MediaQuery.of(context).size.width, 430.0);
    final done = tracker.state.exercise[todayKey()] ?? <int>[];
    final bottomPad = 120.0 + MediaQuery.of(context).padding.bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: w <= 380 ? 350 : 362,
              child: ClipRect(
                child: Stack(children: [
                  glowBlob(right: -70),
                  Positioned(
                    right: 10,
                    top: 8,
                    width: w * (w <= 380 ? .54 : .64),
                    height: w <= 380 ? 330 : 356,
                    child: Loop(
                        seconds: 4,
                        dy: -7,
                        child: const HeroPhoto(asset: 'assets/media/b8e30f1f116d.png', align: Alignment.centerRight, glowL: .04, glowR: 0, glowT: .06, glowB: .08)),
                  ),
                  Positioned(
                    left: 18,
                    top: 56,
                    width: w * .52,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Gentle movement', style: ts(w <= 380 ? 13 : 14, FontWeight.w700, vio, height: 1.3)),
                      const SizedBox(height: 6),
                      Text('Move\nwith ease', style: ts(w <= 380 ? 30 : 36, FontWeight.w800, ink, height: 1.02, ls: -.035 * (w <= 380 ? 30 : 36))),
                    ]),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: const EdgeInsets.only(top: 6), child: h2('Relief poses')),
                Rise(
                  key: ValueKey('$token-r0'),
                  delay: const Duration(milliseconds: 80),
                  child: listRow(
                  leading: const SizedBox.shrink(),
                  body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Guided breathing', style: ts(18, FontWeight.w800, ink)),
                    const SizedBox(height: 4),
                    Text('4-6 or 4-7-8 · Choose a breathing rhythm', style: ts(14, FontWeight.w700, mut, height: 1.4)),
                  ]),
                  trailing: Text('›', style: ts(20, FontWeight.w700, mut)),
                  onTap: () => showBreathing(context),
                )),
                for (var i = 0; i < exercises.length; i++)
                  Rise(
                    key: ValueKey('$token-r${i + 1}'),
                    delay: Duration(milliseconds: 125 + i * 45),
                    child: listRow(
                    leading: const SizedBox.shrink(),
                    body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(exercises[i].name, style: ts(18, FontWeight.w800, ink)),
                      const SizedBox(height: 4),
                      Text('${exercises[i].time} · ${exercises[i].why}', style: ts(14, FontWeight.w700, mut, height: 1.4)),
                    ]),
                    trailing: Text(done.contains(i) ? '✓' : '›', style: ts(20, FontWeight.w700, mut)),
                    onTap: () => showPanel(context, (c) => ExerciseSheet(index: i, tracker: tracker)),
                  )),
              ]),
            ),
            SizedBox(height: bottomPad),
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Games hub (s2)
const _gameColors = {
  'memory': [Color(0xFFF8E3EC), Color(0xFFB0507A)],
  'slider': [Color(0xFFE1EEFA), Color(0xFF3F78B0)],
  'sequence': [Color(0xFFECE4FB), Color(0xFF7A5AD0)],
  'crosses': [Color(0xFFFBE8DC), Color(0xFFC0704F)],
  'words': [Color(0xFFE3F1E4), Color(0xFF5A8566)],
  'lights': [Color(0xFFF8EDCF), Color(0xFFA8802F)],
  'trail': [Color(0xFFDAF1EF), Color(0xFF3D8D92)],
  'maze': [Color(0xFFE4D9FC), Color(0xFF7A5AD0)],
  'mines': [Color(0xFFFBE0DC), Color(0xFFCC5F55)],
  'snake': [Color(0xFFE0E5FA), Color(0xFF5668C8)],
};

class GamesScreen extends StatefulWidget {
  final int token;
  const GamesScreen({super.key, this.token = 0});
  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<dynamic> games = [];
  Map<String, dynamic> icons = {};
  int wins = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/data/games.json')) as Map<String, dynamic>;
    var w = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonDecode(prefs.getString('rainlight.mini-games.v1') ?? '{}') as Map<String, dynamic>;
      for (final r in data.values) {
        if (r is Map && r['wins'] is int) w += r['wins'] as int;
      }
    } catch (_) {}
    if (mounted) setState(() {
          games = j['games'] as List<dynamic>;
          icons = j['icons'] as Map<String, dynamic>;
          wins = w;
        });
  }

  @override
  Widget build(BuildContext context) {
    final w = math.min(MediaQuery.of(context).size.width, 430.0);
    final bottomPad = 120.0 + MediaQuery.of(context).padding.bottom;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: w <= 380 ? 340 : 365,
              child: ClipRect(
                child: Stack(children: [
                  glowBlob(left: -36, top: -22, w: 295, h: 325),
                  Positioned(
                    left: w <= 380 ? -37 : -42,
                    top: -3,
                    width: w * (w <= 380 ? .83 : .82),
                    height: w <= 380 ? 350 : 379,
                    child: Loop(
                      seconds: 4,
                      dy: -7,
                      child: HeroPhoto(
                        asset: 'assets/media/23672cc45bc8.webp',
                        align: Alignment.bottomLeft,
                        glowL: .08,
                        glowR: 0,
                        glowT: .04,
                        glowB: .07,
                        mask: (img) => edgeMask(img, h: const [0, .07, .90, 1], v: const [0, .06, .65, .99]),
                      ),
                    ),
                  ),
                  Positioned(
                    right: w <= 380 ? 5 : 6,
                    top: w <= 380 ? 104 : 101,
                    width: w * .39,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: Text('Petalhaven Play', style: ts(12, FontWeight.w700, vio, height: 1.3))),
                      const SizedBox(height: 6),
                      Text('Play a\nlittle', style: ts(w <= 380 ? 30 : 35, FontWeight.w800, ink, height: 1.06, ls: -.035 * (w <= 380 ? 30 : 35))),
                    ]),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                h2('Mini games'),
                Padding(
                  padding: const EdgeInsets.only(top: 0, bottom: 14),
                  child: Text('${games.length} games · $wins ${wins == 1 ? 'round' : 'rounds'} won', style: ts(15, FontWeight.w700, mut)),
                ),
                for (var gi = 0; gi < games.length; gi++)
                  Rise(key: ValueKey('${widget.token}-g$gi'), delay: Duration(milliseconds: 80 + gi * 45), child: gameRow(games[gi] as List<dynamic>)),
              ]),
            ),
            SizedBox(height: bottomPad),
          ]),
        ),
      ),
    );
  }

  Widget gameRow(List<dynamic> g) {
    final id = g[0] as String, name = g[1] as String, desc = g[2] as String;
    final col = _gameColors[id]!;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${icons[id]}</svg>';
    return listRow(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      leading: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: grad160(Colors.white, col[0]),
          boxShadow: [BoxShadow(color: col[1], blurRadius: 14, offset: const Offset(0, 8), spreadRadius: -10)],
        ),
        child: Center(child: SvgPicture.string(svg, width: 23, height: 23, theme: SvgTheme(currentColor: col[1]))),
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: ts(16, FontWeight.w800, ink, height: 1.2)),
        const SizedBox(height: 3),
        Text(desc, style: ts(12, FontWeight.w700, mut, height: 1.4)),
      ]),
      trailing: Padding(padding: const EdgeInsets.only(left: 12), child: Text('›', style: ts(20, FontWeight.w700, mut))),
      onTap: () async {
        if (implementedGames.contains(id)) {
          await openGame(context, g);
          load();
        } else {
          showPanel(
              context,
              (c) => Padding(
                    padding: const EdgeInsets.fromLTRB(26, 14, 26, 40),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      grabHandle(),
                      Text(name, style: ts(28, FontWeight.w800, ink)),
                      const SizedBox(height: 8),
                      Text(desc, style: ts(15, FontWeight.w700, mut)),
                      const SizedBox(height: 14),
                      Text('This game is not rebuilt yet.', style: ts(15, FontWeight.w700, vio)),
                    ]),
                  ));
        }
      },
    );
  }
}

// ------------------------------------------------------------------ Guided breathing
Future<void> showBreathing(BuildContext context) => showPanel(context, (c) => const BreathingSheet());

class _Step {
  final String label;
  final int ms;
  final double from, to;
  const _Step(this.label, this.ms, this.from, this.to);
}

class _Mode {
  final String name, description;
  final int total;
  final List<_Step> steps;
  const _Mode(this.name, this.description, this.total, this.steps);
}

const _modes = {
  'slow': _Mode('Slow breathing', '1 minute · 4 seconds in, 6 seconds out', 60000,
      [_Step('Breathe in', 4000, 0, 1), _Step('Breathe out', 6000, 1, 0)]),
  '478': _Mode('4-7-8 breathing', '4 rounds · 4 in, 7 hold, 8 out', 76000,
      [_Step('Breathe in', 4000, 0, 1), _Step('Hold', 7000, 1, 1), _Step('Breathe out', 8000, 1, 0)]),
};

class BreathingSheet extends StatefulWidget {
  const BreathingSheet({super.key});
  @override
  State<BreathingSheet> createState() => _BreathingSheetState();
}

class _BreathingSheetState extends State<BreathingSheet> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const idleHint = 'Sit or lie down, relax your shoulders, then tap Start. Stop if you feel dizzy.';
  String mode = 'slow', phase = '', label = 'Get comfortable', hint = idleHint, mainText = 'Start';
  double elapsed = 0, fraction = 0;
  Duration last = Duration.zero;
  bool running = false, haptics = false, finished = false;
  int sessions = 0;
  late final Ticker ticker = createTicker(onTick);
  _Mode get cfg => _modes[mode]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) {
      try {
        sessions = ((jsonDecode(p.getString('rainlight.breathing.v1') ?? '{}') as Map)['sessions'] as num? ?? 0).toInt();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.stop();
    ticker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed && running) pause();
  }

  void cue(String phaseLabel) {
    switch (phaseLabel) {
      case 'Breathe in':
        GameSound.play('breathe_in');
        break;
      case 'Hold':
        GameSound.play('hold');
        break;
      case 'Breathe out':
        GameSound.play('breathe_out');
        break;
    }
  }

  void buzz([String? phaseLabel]) {
    if (!haptics) return;
    switch (phaseLabel) {
      case 'Breathe in':
        vibratePattern(const [0, 90]);
        break;
      case 'Hold':
        vibratePattern(const [0, 50, 70, 50]);
        break;
      case 'Breathe out':
        vibratePattern(const [0, 160]);
        break;
      default:
        vibratePattern(const [0, 70]);
    }
  }

  double ease(double t) => t < .5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;

  String fmtTime(double ms) {
    final s = (ms / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void onTick(Duration now) {
    if (!running) return;
    if (last != Duration.zero) elapsed = math.min(cfg.total.toDouble(), elapsed + math.min(100, (now - last).inMilliseconds).toDouble());
    last = now;
    paint();
    if (elapsed >= cfg.total) finish();
  }

  void paint() {
    final cycle = cfg.steps.fold<int>(0, (a, s) => a + s.ms);
    var t = math.min(elapsed, cfg.total - 0.001) % cycle;
    var step = cfg.steps.first;
    for (final item in cfg.steps) {
      if (t < item.ms) {
        step = item;
        break;
      }
      t -= item.ms;
    }
    setState(() {
      fraction = step.from + (step.to - step.from) * ease(t / step.ms);
      if (step.label != phase) {
        phase = step.label;
        label = phase;
        buzz(phase);
        cue(phase);
      }
    });
  }

  void start() {
    if (elapsed >= cfg.total) {
      elapsed = 0;
      phase = '';
    }
    finished = false;
    running = true;
    last = Duration.zero;
    setState(() {
      mainText = 'Pause';
      hint = mode == '478' ? 'Inhale gently, hold without straining, then exhale slowly.' : 'In through your nose, out slowly through your mouth.';
    });
    ticker.stop();
    ticker.start();
  }

  void pause() {
    if (!running) return;
    ticker.stop();
    running = false;
    setState(() {
      mainText = 'Resume';
      label = 'Paused';
      phase = '';
    });
  }

  Future<void> finish() async {
    ticker.stop();
    running = false;
    sessions++;
    try {
      (await SharedPreferences.getInstance()).setString('rainlight.breathing.v1', jsonEncode({'sessions': sessions}));
    } catch (_) {}
    setState(() {
      fraction = 0;
      finished = true;
      label = 'Well done';
      hint = 'Breathing session complete. Session $sessions on this device.';
      mainText = 'Again';
    });
    GameSound.play('finish');
    if (haptics) vibratePattern(const [0, 200, 100, 200, 100, 400]);
  }

  void choose() {
    ticker.stop();
    running = false;
    setState(() {
      mode = mode == 'slow' ? '478' : 'slow';
      elapsed = 0;
      phase = '';
      fraction = 0;
      finished = false;
      label = 'Get comfortable';
      hint = idleHint;
      mainText = 'Start';
    });
  }

  @override
  Widget build(BuildContext context) {
    final stage = math.min(MediaQuery.of(context).size.width * .7, 260.0);
    final remaining = finished ? 0.0 : cfg.total - elapsed;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
      child: Column(children: [
        grabHandle(),
        Text('Breathe', style: ts(28, FontWeight.w800, ink, ls: -.7)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: lav2, border: Border.all(color: lav4), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final m in const [('slow', '4–6'), ('478', '4–7–8')])
              Pressable(
                haptic: false,
                scale: .96,
                onTap: () {
                  if (mode != m.$1) choose();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minWidth: 84, minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: mode == m.$1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: mode == m.$1 ? const [BoxShadow(color: Color.fromRGBO(92, 64, 179, .35), blurRadius: 12, offset: Offset(0, 4), spreadRadius: -4)] : null,
                  ),
                  child: Center(child: Text(m.$2, style: ts(14, FontWeight.w800, mode == m.$1 ? vio : mut))),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(cfg.description, textAlign: TextAlign.center, style: ts(15, FontWeight.w700, mut, height: 1.45)),
        const SizedBox(height: 16),
        SizedBox(
          width: stage,
          height: stage,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _BreathRing(finished ? 1 : elapsed / cfg.total))),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(stage * .12),
                child: Transform.scale(
                  scale: finished || (!running && elapsed == 0) ? .5 : .5 + .5 * fraction,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(center: Alignment(-.3, -.4), radius: 1.0, colors: [Color(0xFFE2D6FC), Color(0xFFA58BEC), Color(0xFF7A5AD0)], stops: [0, .68, 1]),
                      boxShadow: [BoxShadow(color: Color.fromRGBO(122, 90, 208, .4), blurRadius: 44)],
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(height: 34, child: Text(label, style: ts(26, FontWeight.w800, ink, ls: -.5))),
        const SizedBox(height: 2),
        Text(fmtTime(remaining), style: ts(15, FontWeight.w800, vio)),
        const SizedBox(height: 8),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 290), child: Text(hint, textAlign: TextAlign.center, style: ts(14, FontWeight.w600, mut, height: 1.5))),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            flex: 14,
            child: Pressable(
              haptic: false,
              scale: .96,
              onTap: () => running ? pause() : start(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  gradient: grad160(const Color(0xFF8A6FE0), const Color(0xFF5C40B3)),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(92, 64, 179, .8), blurRadius: 26, offset: Offset(0, 16), spreadRadius: -14)],
                ),
                child: Center(child: Text(mainText, style: ts(15, FontWeight.w800, Colors.white))),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 10,
            child: Pressable(
              haptic: false,
              scale: .96,
              onTap: () {
                setState(() => haptics = !haptics);
                buzz();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: lav4, width: 1.5), borderRadius: BorderRadius.circular(30)),
                child: Center(child: Text('Haptics: ${haptics ? 'on' : 'off'}', style: ts(15, FontWeight.w800, vio))),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Pressable(
          haptic: false,
          scale: .96,
          onTap: () {
            GameSound.setEnabled(!GameSound.enabled);
            setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text('Sound: ${GameSound.enabled ? 'on' : 'off'}', style: ts(14, FontWeight.w800, vio)),
          ),
        ),
      ]),
    );
  }
}

class _BreathRing extends CustomPainter {
  final double progress;
  _BreathRing(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    const c = Offset(50, 50);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE7DFFA);
    canvas.drawCircle(c, 46, base);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 46), -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0).toDouble(), false, base..color = const Color(0xFF7A5AD0));
    }
  }

  @override
  bool shouldRepaint(covariant _BreathRing old) => old.progress != progress;
}
