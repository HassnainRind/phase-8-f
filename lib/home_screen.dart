import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'daily_notes.dart';
import 'exercise.dart';
import 'forms.dart';
import 'screens.dart';
import 'theme.dart';
import 'tracker.dart';
import 'widgets.dart';

const monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
const weekdaysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

DateTime parseKey(String k) => DateTime.parse('${k}T12:00:00');
String fmt(String d) {
  final t = parseKey(d);
  return '${t.day} ${monthsShort[t.month - 1]}';
}

String range(String a, String b) => a == b ? fmt(a) : '${fmt(a)} – ${fmt(b)}';

// tile colours (c0..c5)
const tileGradients = [
  [Color(0xFFF2EBFF), Color(0xFFE4D9FC)],
  [Color(0xFFEEF2FF), Color(0xFFDBE3FB)],
  [Color(0xFFF8ECFB), Color(0xFFECD8F6)],
  [Color(0xFFF2EBFF), Color(0xFFE4D9FC)],
  [Color(0xFFEEF2FF), Color(0xFFDBE3FB)],
  [Color(0xFFF8ECFB), Color(0xFFECD8F6)],
];

class HomeScreen extends StatefulWidget {
  final Tracker tracker;
  final DailyNotes notes;
  final int token;
  const HomeScreen({super.key, required this.tracker, required this.notes, this.token = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late int y, m;
  bool swapAnim = false;
  final ScrollController scroll = ScrollController();
  late final AnimationController float = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  final GlobalKey calKey = GlobalKey();

  Tracker get t => widget.tracker;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    y = n.year;
    m = n.month - 1;
  }

  @override
  void dispose() {
    scroll.dispose();
    float.dispose();
    super.dispose();
  }

  void moveMonth(int d) {
    swapAnim = true;
    Future.delayed(const Duration(seconds: 1), () => swapAnim = false);
    _move(d);
  }

  void _move(int d) => setState(() {
        m += d;
        if (m < 0) {
          m = 11;
          y--;
        }
        if (m > 11) {
          m = 0;
          y++;
        }
      });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([t, widget.notes]),
      builder: (context, _) {
        final w = math.min(MediaQuery.of(context).size.width, 430.0);
        final bottomPad = 120.0 + MediaQuery.of(context).padding.bottom;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              controller: scroll,
              physics: const ClampingScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                hero(w),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    weekStrip(),
                    const SizedBox(height: 22),
                    rise(1, cycleCard()),
                    rise(2, moodChips()),
                    const SizedBox(height: 16),
                    rise(3, calendarCard()),
                    rise(4, dailyCard()),
                    rise(5, Text('For you today', style: ts(23, FontWeight.w800, ink, ls: -.3))),
                  ]),
                ),
                const SizedBox(height: 12),
                tiles(),
                SizedBox(height: bottomPad),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget rise(int i, Widget child) => Rise(key: ValueKey('${widget.token}-b$i'), delay: Duration(milliseconds: 100 + i * 40), child: child);

  // ---------------------------------------------------------------- hero
  Widget hero(double w) {
    final now = DateTime.now();
    final date = '${weekdaysLong[now.weekday - 1]} ${now.day} ${monthsLong[now.month - 1]}';
    final narrow = w <= 380;
    return SizedBox(
      height: 254,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 290,
          child: ClipRect(
            child: Stack(children: [
              glowBlob(right: -70),
              Positioned(
                right: -4,
                top: 0,
                width: w * .58,
                height: 296,
                child: AnimatedBuilder(
                  animation: scroll,
                  builder: (_, child) => Transform.translate(offset: Offset(0, scroll.hasClients ? scroll.offset * .1 : 0.0), child: child),
                  child: Loop(
                      seconds: 4,
                      dy: -7,
                      child: const HeroPhoto(asset: 'assets/media/b8e30f1f116d.png', align: Alignment.topRight, glowL: .10, glowR: .04, glowT: .08, glowB: .14)),
                ),
              ),
              Positioned(
                left: 18,
                top: 50,
                width: w * .52,
                child: Rise(
                  key: ValueKey('${widget.token}-hero'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(date, style: ts(narrow ? 13 : 14, FontWeight.w700, vio, height: 1.3)),
                    const SizedBox(height: 6),
                    Text('Hello,\nAina', style: ts(narrow ? 30 : 36, FontWeight.w800, ink, height: 1.02, ls: -.035 * (narrow ? 30 : 36))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget fadeMask(Widget child) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
                begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0x00000000), Color(0xFF000000)], stops: [0, .22])
            .createShader(r),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)], stops: [0, .55, 1])
              .createShader(r),
          child: child,
        ),
      );

  // ---------------------------------------------------------------- week
  Widget weekStrip() {
    final today = todayKey();
    final dow = DateTime.now().weekday % 7; // Sunday = 0
    final start = addDays(today, -dow);
    return Row(children: [
      for (var i = 0; i < 7; i++) ...[
        if (i > 0) const SizedBox(width: 7),
        Expanded(
          child: Rise(
            key: ValueKey('${widget.token}-w$i'),
            delay: Duration(milliseconds: 80 + i * 35),
            child: Column(children: [
              Text('SMTWTFS'[i], style: ts(13, FontWeight.w800, mut)),
              const SizedBox(height: 6),
              dayPill(addDays(start, i), today),
            ]),
          ),
        ),
      ]
    ]);
  }

  Widget dayPill(String d, String today) {
    final isP = t.isPeriod(d), assumed = t.isAssumed(d), isT = d == today;
    final number = int.parse(d.substring(8));
    return LayoutBuilder(builder: (context, c) {
      final pw = c.maxWidth, ph = pw / .82;
      final radius = BorderRadius.all(Radius.elliptical(pw * .5, ph * .42));
      Gradient? g;
      Color? bg = const Color.fromRGBO(255, 255, 255, .92);
      Color fg = ink;
      List<BoxShadow> sh = const [
        BoxShadow(color: Color(0xFFE0D6F6), spreadRadius: 1.5),
        BoxShadow(color: Color.fromRGBO(86, 58, 170, .4), blurRadius: 14, offset: Offset(0, 8), spreadRadius: -10),
      ];
      Border? border;
      if (isP && assumed) {
        bg = const Color(0xFFF7E4EE);
        fg = const Color(0xFFA95C78);
        sh = const [];
        border = Border.all(color: const Color(0xFFD7A4BA));
      } else if (isP) {
        g = pinkGrad;
        bg = null;
        fg = Colors.white;
        sh = const [BoxShadow(color: Color.fromRGBO(224, 85, 127, .7), blurRadius: 16, offset: Offset(0, 10), spreadRadius: -8)];
      } else if (isT) {
        g = violetGrad;
        bg = null;
        fg = Colors.white;
        sh = const [BoxShadow(color: Color.fromRGBO(95, 67, 182, .65), blurRadius: 18, offset: Offset(0, 12), spreadRadius: -8)];
      }
      return Pressable(
        scale: .92,
        radius: 30,
        ripple: fg,
        onTap: () => openDay(d),
        child: PopOn(
          active: isP,
          duration: const Duration(milliseconds: 550),
          child: Container(
            height: ph,
            decoration: BoxDecoration(color: bg, gradient: g, borderRadius: radius, boxShadow: sh, border: border),
            child: Center(child: Text('$number', style: ts(17, FontWeight.w800, fg))),
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------- cycle card
  // Frosted card without a live BackdropFilter (the background is already a soft gradient, so the blur was invisible but very costly).
  // A light top-left to bottom-right sheen keeps the glass look; the RepaintBoundary caches the card while scrolling.
  Widget glass({required Widget child, EdgeInsets padding = const EdgeInsets.all(18), double radius = 30}) => RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(86, 58, 170, .4), blurRadius: 44, offset: Offset(0, 22), spreadRadius: -26),
              BoxShadow(color: Color.fromRGBO(86, 58, 170, .08), blurRadius: 6, offset: Offset(0, 2), spreadRadius: -2),
            ],
          ),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.fromRGBO(255, 255, 255, .88), Color.fromRGBO(251, 248, 255, .74)]),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, .9))),
            child: child,
          ),
        ),
      );

  Widget cycleCard() {
    final v = t.model(), f = v.forecast;
    final nextText = v.late > 0
        ? (v.reason ?? 'Period is ${v.late} day${v.late == 1 ? '' : 's'} past the expected range · log it when it starts')
        : v.approaching
            ? 'Period approaching · time to prepare'
            : f != null
                ? 'Next period · ${range(f.earliest, f.latest)}'
                : (v.reason ?? 'Add dates to get started');
    return glass(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          legend(pink, 'Period'),
          const SizedBox(width: 16),
          legend(vio, 'Estimated fertile'),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: 240, height: 240, child: Ring(tracker: t, v: v)),
        const SizedBox(height: 12),
        Pressable(
          scale: .94,
          onTap: insights,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('${v.phase} ›', style: ts(14, FontWeight.w700, vio))),
        ),
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(nextText, textAlign: TextAlign.center, style: ts(13, FontWeight.w700, mut))),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(t.patternText(), textAlign: TextAlign.center, style: ts(11, FontWeight.w600, const Color(0xFF8B83A7), height: 1.5, ls: .11)),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          actionButton('Log period', pinkGrad, const Icon(Icons.favorite, color: Colors.white, size: 26), () => openPeriodForm(context, t, todayKey()), halo: true),
          const SizedBox(width: 18),
          actionButton('Add dates', null, const Icon(Icons.add, color: vio, size: 28), () {
            final ctx = calKey.currentContext;
            if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: easeCurve);
          }),
          const SizedBox(width: 18),
          actionButton('Breathe', null, const Icon(Icons.blur_circular, color: vio, size: 26), () => showBreathing(context)),
        ]),
      ]),
    );
  }

  Widget legend(Color c, String label) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: ts(14, FontWeight.w800, mut)),
      ]);

  Widget actionButton(String label, Gradient? g, Widget icon, VoidCallback onTap, {bool halo = false}) {
    Widget btn = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: g,
        color: g == null ? const Color.fromRGBO(255, 255, 255, .9) : null,
        border: g == null ? Border.all(color: lav4, width: 1.5) : null,
        boxShadow: g != null
            ? const [BoxShadow(color: Color.fromRGBO(224, 85, 127, .75), blurRadius: 22, offset: Offset(0, 14), spreadRadius: -10)]
            : const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .4), blurRadius: 18, offset: Offset(0, 10), spreadRadius: -12)],
      ),
      child: Center(child: icon),
    );
    if (halo) btn = Halo(child: btn);
    return Column(children: [
      Pressable(scale: .9, radius: 29, ripple: g != null ? Colors.white : vio, onTap: onTap, child: btn),
      const SizedBox(height: 6),
      Text(label, style: ts(14, FontWeight.w800, ink)),
    ]);
  }

  // ---------------------------------------------------------------- mood
  Widget moodChips() {
    final current = t.state.logs[todayKey()]?['mood'];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(children: [
        for (final mood in ['Good', 'Quiet', 'Tired', 'Sensitive']) ...[
          if (mood != 'Good') const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              scale: .94,
              onTap: () => t.setLog(todayKey(), 'mood', mood),
              radius: 16,
              ripple: current == mood ? Colors.white : ink,
              child: _Bounce(
                active: current == mood,
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: springCurve,
                transform: Matrix4.translationValues(0, current == mood ? -3 : 0, 0),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: current == mood ? violetGrad : null,
                  color: current == mood ? null : const Color.fromRGBO(255, 255, 255, .8),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    current == mood
                        ? const BoxShadow(color: Color.fromRGBO(95, 67, 182, .7), blurRadius: 18, offset: Offset(0, 12), spreadRadius: -10)
                        : const BoxShadow(color: Color.fromRGBO(86, 58, 170, .45), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -12),
                  ],
                ),
                child: Center(child: Text(mood, style: ts(15, FontWeight.w800, current == mood ? Colors.white : ink))),
              ),
              ),
            ),
          ),
        ]
      ]),
    );
  }

  // ---------------------------------------------------------------- calendar
  Widget calendarCard() {
    final v = t.model(), f = v.forecast;
    final first = DateTime(y, m + 1, 1).weekday % 7;
    final days = DateTime(y, m + 2, 0).day;
    final today = todayKey();
    final cells = <Widget>[for (var i = 0; i < first; i++) const SizedBox.shrink()];
    for (var d = 1; d <= days; d++) {
      final k = dayKey(y, m, d);
      final isP = t.isPeriod(k), assumed = t.isAssumed(k);
      final pred = f != null && k.compareTo(f.earliest) >= 0 && k.compareTo(f.predictedEnd) <= 0;
      final fert = f != null && !pred && k.compareTo(f.fertileStart) >= 0 && k.compareTo(f.fertileEnd) <= 0;
      final pre = f != null && k.compareTo(f.preStart) >= 0 && k.compareTo(f.earliest) < 0;
      Color bg = const Color(0xFFF6F2FF);
      Gradient? g;
      Color fg = ink;
      Border? border;
      if (isP && assumed) {
        bg = const Color(0xFFF9E8EF);
        fg = const Color(0xFFA95C78);
        border = Border.all(color: const Color(0xFFD7A4BA));
      } else if (isP) {
        g = pinkGrad;
        fg = Colors.white;
      } else if (pred) {
        bg = const Color(0xFFF9E1EB);
      } else if (fert) {
        bg = const Color(0xFFE1D6FB);
      }
      if (!isP && pre) border = Border.all(color: const Color(0xFFB38A9F));
      if (k == today) border = Border.all(color: vio, width: 2);
      cells.add(CellIn(
        key: ValueKey('ci-$k-$swapAnim'),
        animate: swapAnim,
        delay: Duration(milliseconds: d * 8),
        child: Pressable(
        scale: .9,
        radius: 40,
        ripple: fg,
        onTap: () => openDay(k),
        child: PopOn(
          key: ValueKey('cell-$k'),
          active: isP,
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: g == null ? bg : null, gradient: g, border: border),
            child: Stack(alignment: Alignment.center, children: [
              Text('$d', style: ts(15, FontWeight.w800, fg)),
              if (t.state.logs.containsKey(k)) Positioned(bottom: 3, child: Container(width: 3, height: 3, decoration: BoxDecoration(color: fg, shape: BoxShape.circle))),
            ]),
          ),
        ),
      )));
    }
    return KeyedSubtree(
      key: calKey,
      child: glass(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            navBtn('‹', () => moveMonth(-1)),
            Text('${monthsLong[m]} $y', style: ts(15, FontWeight.w800, ink)),
            navBtn('›', () => moveMonth(1)),
          ]),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: cells,
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(t.saveMessage, textAlign: TextAlign.center, style: ts(15, FontWeight.w700, mut))),
            if (t.canUndo)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Pressable(
                  scale: .94,
                  onTap: t.undoLast,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(color: lav2, borderRadius: BorderRadius.circular(999)),
                    child: Text('Undo', style: ts(13, FontWeight.w800, vio)),
                  ),
                ),
              ),
          ]),
          linkRowEqual([
            LinkBtn('Daily log', () => openDaily(context, t, selectedDay ?? todayKey())),
            LinkBtn('History', () => openHistory(context, t)),
            LinkBtn('Settings & backup', () => openSettings(context, t)),
          ]),
        ]),
      ),
    );
  }

  Widget navBtn(String s, VoidCallback onTap) => Pressable(
        scale: .9,
        onTap: onTap,
        child: Container(
            width: 34, height: 34, decoration: const BoxDecoration(color: lav2, shape: BoxShape.circle), child: Center(child: Text(s, style: ts(16, FontWeight.w700, vio)))),
      );

  // ---------------------------------------------------------------- daily notes
  Widget dailyCard() {
    final n = widget.notes;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 22, 0, 21),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E2F6)),
        gradient: const LinearGradient(
            begin: Alignment(-.6, -1), end: Alignment(.6, 1), colors: [Color.fromRGBO(255, 255, 255, .96), Color.fromRGBO(248, 243, 255, .88)]),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(66, 39, 115, .26), blurRadius: 28, offset: Offset(0, 13), spreadRadius: -23)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A LITTLE SOMETHING NEW', style: ts(9, FontWeight.w800, const Color(0xFF8C7BAD), ls: 1.0)),
            const SizedBox(height: 4),
            Text('A note for today', style: ts(20, FontWeight.w800, ink)),
          ]),
          Pressable(
            scale: .95,
            onTap: n.shuffle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFF0EAFD), border: Border.all(color: const Color(0xFFE5DAF7)), borderRadius: BorderRadius.circular(99)),
              child: Text('↻ Shuffle', style: ts(11, FontWeight.w700, const Color(0xFF6D4CB6))),
            ),
          ),
        ]),
        const SizedBox(height: 15),
        snippet('LITTLE ADVICE', n.currentAdvice, n.sources, false),
        const SizedBox(height: 9),
        snippet('MINI FACT', n.currentFact, n.sources, true),
        const SizedBox(height: 11),
        Padding(padding: const EdgeInsets.only(left: 2), child: Text('A small moment of care and curiosity.', style: ts(10, FontWeight.w500, const Color(0xFF8D83A7)))),
      ]),
    );
  }

  Widget snippet(String kind, Note note, Map<String, String> sources, bool fact) {
    final url = sources[note.src] ?? 'https://www.nhs.uk';
    final host = Uri.parse(url).host.replaceFirst('www.', '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(color: fact ? const Color(0xFFF9F7FE) : Colors.white, border: Border.all(color: const Color(0xFFF0EBF9)), borderRadius: BorderRadius.circular(17)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$kind · ${note.category}', style: ts(10, FontWeight.w800, const Color(0xFF956DB9), ls: .3)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(note.text, style: ts(13, FontWeight.w700, const Color(0xFF352954), height: 1.5))),
        GestureDetector(
          onTap: () => openLink(url),
          child: Text('Source: $host ↗', style: ts(10, FontWeight.w500, const Color(0xFF7B5BC6)).copyWith(decoration: TextDecoration.underline)),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- tiles
  Widget tiles() => SizedBox(
        height: 164,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
          itemCount: exercises.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => Rise(key: ValueKey('${widget.token}-t$i'), delay: Duration(milliseconds: 120 + i * 50), duration: const Duration(milliseconds: 500), child: tile(i)),
        ),
      );

  Widget tile(int i) {
    final e = exercises[i];
    return Pressable(
      scale: .96,
      radius: 26,
      onTap: () => showPanel(context, (c) => ExerciseSheet(index: i, tracker: t)),
      child: Container(
        width: 138,
        height: 150,
        decoration: BoxDecoration(
          gradient: grad160(tileGradients[i][0], tileGradients[i][1]),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .5), blurRadius: 26, offset: Offset(0, 18), spreadRadius: -20)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(children: [
            // Mini-card GIF: static (no float) and fully contained inside the card.
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              height: 68,
              child: Image.asset('assets/media/${tileGif[e.key]}.gif', fit: BoxFit.contain, alignment: Alignment.bottomCenter, cacheHeight: (68 * MediaQuery.of(context).devicePixelRatio).round()),
            ),
            Positioned(
              left: 14,
              top: 14,
              right: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.name, style: ts(18, FontWeight.w800, ink, height: 1.15)),
                Text(e.time, style: ts(14, FontWeight.w700, ink.withAlpha(230))),
              ]),
            ),
            if (e.views.length > 1)
              Positioned(
                top: 18,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, .78),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .5), blurRadius: 12, offset: Offset(0, 6), spreadRadius: -8)]),
                  child: Text('${e.views.length} views', style: ts(11, FontWeight.w800, vio, ls: .22)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sheets
  String? selectedDay;

  void openDay(String date) {
    selectedDay = date;
    openDaily(context, t, date);
  }

  Widget noteText(String s) => Padding(padding: const EdgeInsets.only(top: 8), child: Text(s, style: ts(15, FontWeight.w700, mut)));

  Widget panelBody(String title, List<Widget> kids) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          grabHandle(),
          Text(title, style: ts(23, FontWeight.w800, ink)),
          ...kids,
          const SizedBox(height: 18),
          Pressable(
            scale: .96,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(gradient: grad160(const Color(0xFF8A6FE0), const Color(0xFF5C40B3)), borderRadius: BorderRadius.circular(30)),
              child: Center(child: Text('Close', style: ts(16, FontWeight.w800, Colors.white))),
            ),
          ),
        ]),
      );

  void insights() {
    final v = t.model(), f = v.forecast;
    Widget row(String a, String b) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF0EBF9))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a, style: ts(15, FontWeight.w800, ink)),
            Text(b, style: ts(13, FontWeight.w700, mut)),
          ]),
        );
    showPanel(context, (c) => panelBody('Your cycle', [
          noteText(v.phase),
          if (f != null) ...[
            row('Next period', range(f.earliest, f.latest)),
            row(f.source != 'calendar' ? 'Ovulation · ${f.source}' : 'Possible ovulation', range(f.ovStart, f.ovEnd)),
            row('Estimated fertile timing', range(f.fertileStart, f.fertileEnd)),
            row('Estimated luteal days', range(f.lutealStart, addDays(f.latest, -1))),
            row('Period approaching', 'From ${fmt(f.preStart)} · ${t.state.reminderDays} days before the earliest estimate'),
            noteText('The lead-up is a preparation reminder, not a prediction that you will feel unwell. Your own symptom logs matter more.'),
          ] else
            noteText(v.reason ?? 'More history is needed.'),
          if (v.excluded > 0) noteText('${v.excluded} unusual cycle${v.excluded == 1 ? '' : 's'} (outside 21–35 days) left out of the average.'),
          noteText('Menstruation is part of the follicular phase. Luteal timing follows ovulation, which dates alone cannot confirm. These broad ranges can overlap and are not measured hormone phases.'),
          noteText('Fertile timing is a calendar estimate, not a safe-day guide or contraception. No day is labelled safe.'),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => openLink('https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/'),
              child: Text('How cycle timing works · NHS', style: ts(14, FontWeight.w700, vio).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ]));
  }
}

// ======================================================================= ring
class _Bounce extends StatefulWidget {
  final bool active;
  final Widget child;
  const _Bounce({required this.active, required this.child});
  @override
  State<_Bounce> createState() => _BounceState();
}

/// keyframes "bounce": translateY(-9px) at 40%, settling back
class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400), value: 1);
  @override
  void didUpdateWidget(_Bounce old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) c.forward(from: 0);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final t = c.value;
          final y = t >= 1 ? 0.0 : (t < .4 ? -9 * easeCurve.transform(t / .4) : -9 * (1 - easeCurve.transform((t - .4) / .6)));
          return Transform.translate(offset: Offset(0, y), child: child);
        },
        child: widget.child,
      );
}

class Ring extends StatefulWidget {
  final Tracker tracker;
  final Estimate v;
  const Ring({super.key, required this.tracker, required this.v});
  @override
  State<Ring> createState() => _RingState();
}

class _RingState extends State<Ring> with SingleTickerProviderStateMixin {
  // total 1.8s: spin 1.4s, arcs draw 1s, marker pop 1.2s..1.8s (keyframes spin / draw / pop)
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final late = v.late;
    final ring = AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final ms = c.value * 1800;
        final spin = easeCurve.transform((ms / 1400).clamp(0.0, 1.0).toDouble());
        double drawAt(double delay) => easeCurve.transform(((ms - delay) / 1000).clamp(0.0, 1.0).toDouble());
        final pop = ((ms - 600) / 450).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: spin,
          child: Transform.rotate(
            angle: (1 - spin) * -200 * math.pi / 180,
            child: Transform.scale(scale: .8 + .2 * spin, child: RepaintBoundary(child: CustomPaint(size: const Size(240, 240), painter: RingPainter(widget.tracker, v, todayKey(), [drawAt(150), drawAt(250), drawAt(350)], pop)))),
          ),
        );
      },
    );
    return Stack(alignment: Alignment.center, children: [
      Breathe(
        seconds: 6,
        child: Container(
          width: 240 * .72,
          height: 240 * .72,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color.fromRGBO(154, 128, 234, .3), Color.fromRGBO(154, 128, 234, 0)], stops: [0, .7])),
        ),
      ),
      RepaintBoundary(child: ring),
      Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (v.day ?? 0).toDouble()),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
          builder: (_, val, __) => ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => grad160(const Color(0xFF4A3AA0), const Color(0xFF9A80EA)).createShader(r),
            child: Text(v.day == null ? '—' : '${val.round()}', style: ts(52, FontWeight.w700, Colors.white, height: 1, ls: -2.1)),
          ),
        ),
        const SizedBox(height: 4),
        Text(late > 0 ? '$late day${late == 1 ? '' : 's'} late' : 'Cycle day', style: ts(16, FontWeight.w700, mut)),
      ]),
    ]);
  }
}

class RingPainter extends CustomPainter {
  final Tracker tracker;
  final Estimate v;
  final String today;
  final List<double> draws;
  final double pop;
  RingPainter(this.tracker, this.v, this.today, this.draws, this.pop);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200);
    const c = Offset(100, 100);
    const r = 80.0;
    final cc = 2 * math.pi * r;
    final L = math.max(1, v.mean != null ? v.mean!.round() : 28).toDouble();

    Paint stroke(Color col, double w, {double alpha = 1}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = alpha >= 1 ? col : col.withAlpha((col.alpha * alpha).round())
      ..isAntiAlias = true;

    // soft glow under the ring: two wide low-alpha strokes instead of a per-frame blur filter
    for (final g in const [(24.0, .035), (19.0, .05)]) {
      canvas.drawCircle(const Offset(100, 105), r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.$1
        ..color = Color.fromRGBO(122, 90, 208, g.$2));
    }

    canvas.drawCircle(c, r, stroke(const Color(0xFFE7DFFA), 15));

    var arcIndex = 0;
    void arc(double start, double n, Color col) {
      final draw = draws[math.min(arcIndex++, 2)];
      if (draw <= 0) return;
      final dash = math.max(0.0, math.min(n, L) / L * cc - 3);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2 + start / L * 2 * math.pi, dash / r, false, stroke(col, 15 * draw, alpha: draw));
    }

    final periods = tracker.state.periods.where((p) => p.start.compareTo(today) <= 0).toList();
    if (periods.isNotEmpty) {
      final last = periods.last;
      arc(0, (gap(last.start, endOf(last)) + 1).toDouble(), last.end != null ? const Color(0xFFE4648C) : const Color(0xFFEAB2C7));
    }
    final f = v.forecast;
    if (f != null) {
      arc(math.max(0, gap(f.last, f.fertileStart)).toDouble(), math.min(L, (gap(f.fertileStart, f.fertileEnd) + 1).toDouble()), const Color(0xFF7A5AD0));
    }
    final draw = draws[2];
    if (v.day != null && draw > 0) {
      final over = v.day! > L;
      final lap = over ? math.min(v.day! - L, L) : v.day!.toDouble();
      final angle = (lap - .5) / L * 2 * math.pi - math.pi / 2;
      final tone = v.late > 0 ? const Color(0xFFE4648C) : const Color(0xFF7A5AD0);
      if (over) {
        const oc = 2 * math.pi * 92;
        final dash = math.max(1.0, lap / L * oc - 3);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 92), -math.pi / 2, dash / 92, false, stroke(v.late > 0 ? const Color(0xFFE4648C) : const Color(0xFFC9B9F2), 3 * draw, alpha: draw));
      }
      final p = Offset(100 + r * math.cos(angle), 100 + r * math.sin(angle));
      final s = pop >= 1 ? 1.0 : (pop <= 0 ? .5 : (pop < .6 ? .5 + .65 * (pop / .6) : 1.15 - .15 * ((pop - .6) / .4)));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.scale(s);
      canvas.translate(-p.dx, -p.dy);
      canvas.drawCircle(p, 9, Paint()..color = Colors.white.withAlpha((255 * draw).round()));
      canvas.drawCircle(p, 9, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * draw
        ..color = tone.withAlpha((255 * draw).round()));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => true;
}
