import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'tracker.dart';
import 'widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class Exercise {
  final String name, key, time, why, whyText;
  final List<List<String>> views;
  final List<String> steps;
  const Exercise(this.name, this.key, this.views, this.time, this.steps, this.why, this.whyText);
}

const exercises = <Exercise>[
  Exercise("Child’s pose", 'child', [['', 'child']], '2 min',
      ['Kneel, knees a little wide, big toes touching', 'Sit hips back toward heels, walk hands forward', 'Rest forehead down, breathe slowly'],
      'A gentle resting stretch for the back and hips.',
      'This resting shape gently stretches the back and hips - gentle yoga may help some people feel better during a period. This specific pose is not a proven treatment for cramps.'),
  Exercise('Cat–cow', 'cat', [['', 'cat']], '90 sec',
      ['Hands under shoulders, knees under hips', 'Inhale: drop belly, lift chest (cow)', 'Exhale: round spine, tuck chin (cat)'],
      'Gentle spinal mobility and movement.',
      'Moving the spine slowly is a gentle form of mobility - regular light activity, including yoga, can help some people manage period discomfort.'),
  Exercise('Cobra', 'cobra', [['', 'cobra']], '1 min',
      ['Lie on belly, hands under shoulders', 'Press up gently, elbows soft', 'Hold 5 slow breaths, then lower'],
      'A mild backbend - move only within comfort.',
      'This is a mild backbend for the front of the torso - choose an easy range and skip it if it feels uncomfortable. No single pose is established as a cure for period pain.'),
  Exercise('Reclined twist', 'twist', [['', 'twist']], '2 min',
      ['Lie on back, hug knees in', 'Drop both knees to one side, arms open', 'Gaze the other way, then switch sides'],
      'A gentle twist for the back and torso.',
      'This slow twist changes how the lower back and hips are positioned - it may feel relaxing, while evidence supports gentle exercise overall rather than any single pose.'),
  Exercise('Butterfly', 'butterfly', [['Front', 'bff'], ['Side', 'bfs']], '2 min',
      ['Sit tall, soles of feet together', 'Let knees fall open', 'Fold forward from the hips and breathe'],
      'A comfortable hip stretch.',
      'This seated position provides a gentle stretch through the hips - it is a comfortable way to try light movement, which may help some people during a period.'),
  Exercise('Seated shoulder rolls', 'rolls', [['', 'rolls']], '1 min',
      ['Kneel or sit tall, hands resting on your thighs', 'Lift both shoulders toward your ears, then roll them back and down', 'Keep the circles slow for 30 seconds, then reverse direction'],
      'Gentle movement for the shoulders.',
      'Rolling the shoulders is an easy movement break - it can help you move after sitting for a while, but it is not a specific treatment for menstrual cramps.'),
];

const tileGif = {
  'child': 'dffe5ec88363', 'cat': '935a28af7293', 'cobra': 'ca2e527684c0',
  'twist': '2be27be9ffed', 'butterfly': '029bcb4bdce5', 'rolls': '541adaf9bd42',
};
const stageGif = {
  'child': 'fee18be3e3b6', 'cat': 'a3145521571c', 'cobra': '4283c457faa8', 'twist': '2dc501929226',
  'bff': '6c1a668d7d49', 'bfs': 'f46d412aeae6', 'rolls': '1d5e416ec928',
};

Future<void> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

Future<void> showPanel(BuildContext context, Widget Function(BuildContext) builder) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 550), reverseDuration: Duration(milliseconds: 350), curve: springCurve, reverseCurve: easeCurve),
      barrierColor: const Color.fromRGBO(43, 34, 87, 0.3),
      builder: (c) => SheetDragger(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.88),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFFAF7FF)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            boxShadow: [BoxShadow(color: Color.fromRGBO(70, 44, 150, .5), blurRadius: 60, offset: Offset(0, -30), spreadRadius: -30)],
          ),
          child: SafeArea(top: false, child: Rise(delay: const Duration(milliseconds: 120), child: builder(c))),
        ),
      )),
    );

/// Top handle ("hem"): hold and drag it to pull the whole sheet down, like the breathing sheet.
Widget grabHandle() => Builder(builder: (c) {
      final scope = SheetDragScope.maybeOf(c);
      const bar = SizedBox(width: 42, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFDDD1F6), borderRadius: BorderRadius.all(Radius.circular(4)))));
      if (scope == null) return const Center(child: Padding(padding: EdgeInsets.only(bottom: 16), child: bar));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => scope.update(d.delta.dy),
        onVerticalDragEnd: (d) => scope.end(d.primaryVelocity ?? 0),
        onVerticalDragCancel: () => scope.end(0),
        child: Container(width: double.infinity, height: 20, alignment: Alignment.topCenter, child: bar),
      );
    });

class SheetDragScope extends InheritedWidget {
  final void Function(double dy) update;
  final void Function(double velocity) end;
  const SheetDragScope({super.key, required this.update, required this.end, required super.child});
  static SheetDragScope? maybeOf(BuildContext c) => c.dependOnInheritedWidgetOfExactType<SheetDragScope>();
  @override
  bool updateShouldNotify(SheetDragScope old) => false;
}

/// Makes any sheet follow the finger: drag the handle, or pull down while the content is at its top.
class SheetDragger extends StatefulWidget {
  final Widget child;
  const SheetDragger({super.key, required this.child});
  @override
  State<SheetDragger> createState() => _SheetDraggerState();
}

class _SheetDraggerState extends State<SheetDragger> with SingleTickerProviderStateMixin {
  double dy = 0, from = 0, to = 0, lastV = 0;
  bool closing = false;
  int lastT = 0;
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
    ..addListener(() => setState(() => dy = from + (to - from) * Curves.easeOutCubic.transform(ac.value)))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed && closing && mounted) Navigator.of(context).maybePop();
    });

  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  void update(double d) {
    if (closing) return;
    ac.stop();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastT != 0 && now > lastT) lastV = d / (now - lastT) * 1000;
    lastT = now;
    setState(() => dy = math.max(0.0, dy + d));
  }

  void end(double velocity) {
    if (closing || dy <= 0) return;
    final v = velocity != 0 ? velocity : lastV;
    final h = context.size?.height ?? 600;
    lastT = 0;
    lastV = 0;
    closing = dy > math.min(110.0, h * .2) || v > 700;
    from = dy;
    to = closing ? h : 0;
    ac.forward(from: 0);
  }

  bool onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      update(-n.overscroll);
    } else if (n is ScrollUpdateNotification && dy > 0 && n.dragDetails != null && (n.scrollDelta ?? 0) > 0) {
      update(-(n.scrollDelta ?? 0));
    } else if (n is ScrollEndNotification) {
      end(0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => SheetDragScope(
        update: update,
        end: end,
        child: NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: Transform.translate(offset: Offset(0, dy), child: widget.child),
        ),
      );
}

class ExerciseSheet extends StatefulWidget {
  final int index;
  final Tracker tracker;
  const ExerciseSheet({super.key, required this.index, required this.tracker});
  @override
  State<ExerciseSheet> createState() => _ExerciseSheetState();
}

class _ExerciseSheetState extends State<ExerciseSheet> {
  int view = 0, hi = 0;
  Timer? timer, tmr;
  static const secs = [120, 90, 60, 120, 120, 60];
  late int remaining = secs[widget.index];
  int deadline = 0;
  late String timerText = 'Start timer · ${exercises[widget.index].time}';
  late bool done = widget.tracker.state.exercise[todayKey()]?.contains(widget.index) ?? false;
  Exercise get e => exercises[widget.index];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 2800), (_) => setState(() => hi = (hi + 1) % e.steps.length));
  }

  @override
  void dispose() {
    timer?.cancel();
    tmr?.cancel();
    stopAlarm();
    super.dispose();
  }

  void tick() {
    remaining = math.max(0, ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil());
    if (remaining == 0) {
      tmr?.cancel();
      tmr = null;
      playAlarm();
    }
    setState(() => timerText = remaining > 0 ? 'Pause · ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}' : 'Finished · repeat');
  }

  void toggleTimer() {
    if (tmr != null) {
      tick();
      tmr?.cancel();
      tmr = null;
      setState(() => timerText = 'Resume · $remaining sec');
    } else {
      stopAlarm();
      if (remaining == 0) remaining = secs[widget.index];
      deadline = DateTime.now().millisecondsSinceEpoch + remaining * 1000;
      tmr = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
      tick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        grabHandle(),
        // .stage
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Container(
            height: 210,
            width: double.infinity,
            decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EEFF), Color(0xFFE2D8F9)])),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Image.asset('assets/media/${stageGif[e.views[view][1]]}.gif', key: ValueKey(view), height: 210, fit: BoxFit.contain, cacheHeight: (210 * MediaQuery.of(context).devicePixelRatio).round()),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (e.views.length > 1)
          Center(
            child: Container(
              width: 230,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: lav2, borderRadius: BorderRadius.circular(999)),
              child: Stack(children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 450),
                  curve: springCurve,
                  alignment: view == 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 1 / e.views.length,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .6), blurRadius: 14, offset: Offset(0, 6), spreadRadius: -8)]),
                    ),
                  ),
                ),
                Row(children: [
                  for (var j = 0; j < e.views.length; j++)
                    Expanded(
                      child: Pressable(
                        scale: .94,
                        onTap: () => setState(() => view = j),
                        child: SizedBox(
                          height: 40,
                          child: Center(child: Text(e.views[j][0], style: ts(14, FontWeight.w800, j == view ? vio : mut))),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
        Text(e.name, style: ts(28, FontWeight.w800, ink, height: 1.05, ls: -.7)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: lav2, borderRadius: BorderRadius.circular(20)),
              child: Text(e.time, style: ts(13, FontWeight.w800, vio))),
          Text(e.why, style: ts(15, FontWeight.w700, mut, height: 1.5)),
        ]),
        const SizedBox(height: 24),
        for (var i = 0; i < e.steps.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == e.steps.length - 1 ? 0 : 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 22, child: Text('${i + 1}.', style: ts(15, FontWeight.w800, vio, height: 1.55))),
              const SizedBox(width: 4),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 450),
                  style: ts(15, FontWeight.w600, i == hi ? ink : mut, height: 1.55),
                  child: Text(e.steps[i]),
                ),
              ),
            ]),
          ),
        // .why-card
        Container(
          margin: const EdgeInsets.symmetric(vertical: 15),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(color: const Color(0xFFF6F0FF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFECE2FC))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Why this exercise?', style: ts(14, FontWeight.w700, const Color(0xFF38266D))),
            const SizedBox(height: 5),
            Text(e.whyText, style: ts(12, FontWeight.w500, const Color(0xFF5C517A), height: 1.55)),
            const SizedBox(height: 7),
            GestureDetector(
              onTap: () => openLink('https://www.nhs.uk/symptoms/period-pain/'),
              child: Text('Why gentle movement may help - NHS ↗', style: ts(11, FontWeight.w500, const Color(0xFF6A48B6)).copyWith(decoration: TextDecoration.underline)),
            ),
          ]),
        ),
        // .rt-form-actions: timer + mark complete
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _cta(timerText, toggleTimer)),
          const SizedBox(width: 12),
          Expanded(
            child: _cta(done ? 'Done today ✓' : 'Mark complete', () {
              if (!done) {
                final err = widget.tracker.transact((s) {
                  final l = List<int>.from(s.exercise[todayKey()] ?? <int>[]);
                  if (!l.contains(widget.index)) l.add(widget.index);
                  s.exercise[todayKey()] = l;
                });
                if (err != null) return;
                setState(() => done = true);
                GameSound.play('done');
              }
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted) Navigator.of(context).pop();
              });
            }, dim: done),
          ),
        ]),
      ]),
    );
  }
}

Widget _cta(String text, VoidCallback onTap, {bool dim = false}) => Pressable(
      scale: .96,
      onTap: onTap,
      child: Opacity(
        opacity: dim ? .7 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            gradient: grad160(const Color(0xFF8A6FE0), const Color(0xFF5C40B3)),
            borderRadius: BorderRadius.circular(30),
            boxShadow: dim ? null : const [BoxShadow(color: Color.fromRGBO(92, 64, 179, .8), blurRadius: 26, offset: Offset(0, 16), spreadRadius: -14)],
          ),
          child: Center(child: Text(text, textAlign: TextAlign.center, style: ts(15, FontWeight.w800, Colors.white))),
        ),
      ),
    );
