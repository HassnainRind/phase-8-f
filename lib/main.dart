import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'daily_notes.dart';
import 'home_screen.dart';
import 'screens.dart';
import 'theme.dart';
import 'tracker.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFECE6FF),
      systemNavigationBarIconBrightness: Brightness.dark));
  await GameSound.load();
  final tracker = Tracker();
  await tracker.load();
  final notes = DailyNotes();
  await notes.load();
  runApp(PetalhavenApp(tracker: tracker, notes: notes));
}

class PetalhavenApp extends StatelessWidget {
  final Tracker tracker;
  final DailyNotes notes;
  const PetalhavenApp({super.key, required this.tracker, required this.notes});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Petalhaven',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, fontFamily: 'Urbanist', scaffoldBackgroundColor: const Color(0xFFF5F0FF)),
        home: Shell(tracker: tracker, notes: notes),
      );
}

class Shell extends StatefulWidget {
  final Tracker tracker;
  final DailyNotes notes;
  const Shell({super.key, required this.tracker, required this.notes});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final List<int> tokens = [0, 0, 0];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment(-0.14, -1), end: Alignment(0.14, 1), colors: [Color(0xFFFDFCFF), Color(0xFFF5F0FF), Color(0xFFECE6FF)], stops: [0, .52, 1])),
        child: Stack(children: [
          const Aurora(),
          SafeArea(
            bottom: false,
            child: IndexedStack(index: tab, children: [
              HomeScreen(tracker: widget.tracker, notes: widget.notes, token: tokens[0]),
              AnimatedBuilder(animation: widget.tracker, builder: (_, __) => PosesScreen(tracker: widget.tracker, token: tokens[1])),
              GamesScreen(token: tokens[2]),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 + bottom,
            child: Center(child: NavPill(index: tab, onChanged: (i) => setState(() {
              if (i != tab) tokens[i]++;
              tab = i;
            }))),
          ),
        ]),
      ),
    );
  }
}

class PhaseTwo extends StatelessWidget {
  final String title, sub;
  const PhaseTwo({super.key, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 50, 18, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ts(14, FontWeight.w700, vio)),
          const SizedBox(height: 6),
          Text(sub, style: ts(40, FontWeight.w800, ink, height: 1.05, ls: -1)),
          const SizedBox(height: 24),
          Text('This screen is not rebuilt yet (phase 2).', style: ts(15, FontWeight.w700, mut)),
        ]),
      );
}

class NavPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const NavPill({super.key, required this.index, required this.onChanged});
  static const icons = ['📅', '🧘', '🎮'];

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.86),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.9)),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(70, 44, 150, 0.45), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -18)],
        ),
        child: SizedBox(
          width: 60 * 3 + 20,
          height: 60,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 450),
              curve: springCurve,
              left: index * 70.0,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: grad160(const Color(0xFF8D73E6), const Color(0xFF5C40B3)),
                  boxShadow: const [BoxShadow(color: Color.fromRGBO(92, 64, 179, 0.7), blurRadius: 20, offset: Offset(0, 12), spreadRadius: -8)],
                ),
              ),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: i * 70.0,
                child: Pressable(
                  scale: .88,
                  radius: 30,
                  ripple: i == index ? Colors.white : ink,
                  onTap: () => onChanged(i),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(
                      child: AnimatedScale(
                        scale: i == index ? 1.05 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        curve: springCurve,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(i == index ? 'on$i' : 'off$i'),
                          tween: Tween(begin: i == index ? .7 : 1.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: const Cubic(.34, 1.56, .64, 1),
                          builder: (_, s, child) => Transform.scale(scale: s, child: child),
                          child: ColorFiltered(
                            colorFilter: i == index ? const ColorFilter.mode(Colors.transparent, BlendMode.dst) : grayscale,
                            child: Opacity(opacity: i == index ? 1 : .9, child: Text(icons[i], style: const TextStyle(fontSize: 22))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ));
}

/// Three slowly drifting radial glows (".aurora")
class Aurora extends StatelessWidget {
  const Aurora({super.key});
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: RepaintBoundary(child: Stack(children: [
        Blob(left: size.width * -.02, top: size.height * .02, d: 340, color: const Color(0xFFC9B6FB), secs: 26, dx: 90, dy: 120, scaleTo: 1.18),
        Blob(right: size.width * -.04, top: size.height * .34, d: 300, color: const Color(0xFFB8C9F8), secs: 32, dx: -110, dy: -90, scaleTo: .9),
        Blob(left: size.width * .16, bottom: size.height * -.06, d: 360, color: const Color(0xFFECC6F2), secs: 38, dx: 70, dy: -130, scaleTo: 1.12),
      ])),
    );
  }
}

class Blob extends StatefulWidget {
  final double? left, right, top, bottom;
  final double d, dx, dy, scaleTo;
  final int secs;
  final Color color;
  const Blob({super.key, this.left, this.right, this.top, this.bottom, required this.d, required this.color, required this.secs, required this.dx, required this.dy, required this.scaleTo});
  @override
  State<Blob> createState() => _BlobState();
}

class _BlobState extends State<Blob> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(seconds: widget.secs))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        left: widget.left,
        right: widget.right,
        top: widget.top,
        bottom: widget.bottom,
        // The glow is painted once into its own layer; the animation only moves that cached layer (no repaint, no saveLayer).
        child: AnimatedBuilder(
          animation: c,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(c.value);
            return Transform.translate(offset: Offset(widget.dx * t, widget.dy * t), child: Transform.scale(scale: 1 + (widget.scaleTo - 1) * t, child: child));
          },
          child: RepaintBoundary(
            child: Container(
              width: widget.d,
              height: widget.d,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(radius: .48, colors: [widget.color.withAlpha(204), widget.color.withAlpha(0)])),
            ),
          ),
        ),
      );
}
