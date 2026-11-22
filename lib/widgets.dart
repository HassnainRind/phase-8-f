import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'theme.dart';

/// Press-in scale effect (:active -> scale) + the site's tap ripple (".rip": currentColor, .25 opacity, 600ms)
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale, radius;
  final Color? ripple;
  final bool haptic;
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.92, this.radius = 22, this.ripple, this.haptic = true});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false;
  Offset pos = Offset.zero;
  int nextId = 0;
  final Map<int, Offset> rips = {};

  void spawn() {
    final id = nextId++;
    setState(() => rips[id] = pos);
  }

  @override
  Widget build(BuildContext context) {
    Widget body = widget.child;
    if (rips.isNotEmpty) {
      final box = context.findRenderObject() as RenderBox?;
      final z = box == null ? 60.0 : math.max(box.size.width, box.size.height);
      body = Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.radius),
              child: Stack(children: [
                for (final e in rips.entries)
                  _Rip(key: ValueKey(e.key), pos: e.value, z: z, color: widget.ripple ?? ink, onDone: () {
                    if (mounted) setState(() => rips.remove(e.key));
                  }),
              ]),
            ),
          ),
        ),
      ]);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => setState(() {
        down = true;
        pos = d.localPosition;
      }),
      onTapUp: (_) => setState(() => down = false),
      onTapCancel: () => setState(() => down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) tickHaptic();
              spawn();
              widget.onTap!();
            },
      child: AnimatedScale(scale: down ? widget.scale : 1.0, duration: const Duration(milliseconds: 280), curve: springCurve, child: body),
    );
  }
}

class _Rip extends StatefulWidget {
  final Offset pos;
  final double z;
  final Color color;
  final VoidCallback onDone;
  const _Rip({super.key, required this.pos, required this.z, required this.color, required this.onDone});
  @override
  State<_Rip> createState() => _RipState();
}

class _RipState extends State<_Rip> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..forward().whenComplete(widget.onDone);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => CustomPaint(painter: _RipPainter(widget.pos, widget.z, Curves.easeOut.transform(c.value), widget.color)),
        ),
      );
}

class _RipPainter extends CustomPainter {
  final Offset pos;
  final double z, t;
  final Color color;
  _RipPainter(this.pos, this.z, this.t, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(pos, z / 2 * 2.6 * t, Paint()..color = color.withAlpha((255 * .25 * (1 - t)).round()));
  }

  @override
  bool shouldRepaint(covariant _RipPainter old) => old.t != t;
}

/// keyframes "pop": scale .5 -> 1.15 (60%) -> 1. Plays on mount if active, and whenever it turns active.
class PopOn extends StatefulWidget {
  final bool active;
  final Widget child;
  final Duration duration;
  const PopOn({super.key, required this.active, required this.child, this.duration = const Duration(milliseconds: 520)});
  @override
  State<PopOn> createState() => _PopOnState();
}

class _PopOnState extends State<PopOn> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: widget.duration, value: 1);
  @override
  void initState() {
    super.initState();
    if (widget.active) c.forward(from: 0);
  }

  @override
  void didUpdateWidget(PopOn old) {
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
          final s = t >= 1 ? 1.0 : (t < .6 ? .5 + .65 * easeCurve.transform(t / .6) : 1.15 - .15 * easeCurve.transform((t - .6) / .4));
          return Transform.scale(scale: s, child: child);
        },
        child: widget.child,
      );
}

/// keyframes "breathe": scale 1 -> 1.12 and opacity 1 -> .6 at the midpoint, forever
class Breathe extends StatefulWidget {
  final double seconds;
  final Widget child;
  const Breathe({super.key, required this.seconds, required this.child});
  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.seconds * 500).round()))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  // Outer boundary keeps the animation from repainting the page; inner boundary caches the child so only a layer is moved.
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(c.value);
            return Opacity(opacity: 1 - .4 * t, child: Transform.scale(scale: 1 + .12 * t, child: child));
          },
          child: RepaintBoundary(child: widget.child),
        ),
      );
}

/// generic looping translate/scale (keyframes drift / floaty)
class Loop extends StatefulWidget {
  final double seconds, dy, scaleTo;
  final Widget child;
  const Loop({super.key, required this.seconds, this.dy = 0, this.scaleTo = 1, required this.child});
  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.seconds * 1000).round()))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, child) {
            final t = Curves.easeInOut.transform(c.value);
            return Transform.translate(offset: Offset(0, widget.dy * t), child: Transform.scale(scale: 1 + (widget.scaleTo - 1) * t, child: child));
          },
          child: RepaintBoundary(child: widget.child),
        ),
      );
}

/// fade + rise-in (keyframes "rise")
class Rise extends StatefulWidget {
  final Widget child;
  final Duration delay, duration;
  const Rise({super.key, required this.child, this.delay = Duration.zero, this.duration = const Duration(milliseconds: 450)});
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: widget.duration);
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) c.forward();
    });
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
          final t = easeCurve.transform(c.value);
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child));
        },
        child: RepaintBoundary(child: widget.child), // cached card layer: scrolling just moves it
      );
}

/// Pulsing halo (keyframes "halo") around the main action button
class Halo extends StatefulWidget {
  final Widget child;
  const Halo({super.key, required this.child});
  @override
  State<Halo> createState() => _HaloState();
}

class _HaloState extends State<Halo> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, child) => DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(color: Color.fromRGBO(224, 85, 127, 0.4 * (1 - c.value)), spreadRadius: 18 * c.value, blurRadius: 0),
            ]),
            child: RepaintBoundary(child: child),
          ),
          child: widget.child,
        ),
      );
}

/// Grayscale filter used for inactive nav icons
const ColorFilter grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// keyframes "cellin": opacity 0, scale .6, translateY 6px -> in (calendar month switch)
class CellIn extends StatefulWidget {
  final bool animate;
  final Duration delay;
  final Widget child;
  const CellIn({super.key, required this.animate, required this.delay, required this.child});
  @override
  State<CellIn> createState() => _CellInState();
}

class _CellInState extends State<CellIn> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350), value: widget.animate ? 0 : 1);
  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) c.forward();
      });
    }
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
          final t = easeCurve.transform(c.value);
          return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: Transform.scale(scale: .6 + .4 * t, child: child)));
        },
        child: widget.child,
      );
}

/// Real device vibration (works even when the phone's "touch feedback" setting is off),
/// with the built-in haptic as a fallback.
Future<void> vibratePattern(List<int> pattern, {bool quiet = false}) async {
  try {
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate(pattern: pattern, intensities: quiet ? [0, 90] : const []);
      return;
    }
  } catch (_) {}
  try {
    await HapticFeedback.heavyImpact();
  } catch (_) {}
}

final AudioPlayer _alarmPlayer = AudioPlayer();

/// Short alarm beeps (assets/sounds/alarm.wav) + vibration, for timers that finish.
Future<void> playAlarm() async {
  try {
    if (!GameSound.enabled) throw 'muted';
    await _alarmPlayer.stop();
    await _alarmPlayer.setReleaseMode(ReleaseMode.stop);
    await _alarmPlayer.play(AssetSource('sounds/alarm.wav'), volume: 1.0);
  } catch (_) {}
  vibratePattern(const [0, 250, 120, 250, 120, 450]);
}

Future<void> stopAlarm() async {
  try {
    await _alarmPlayer.stop();
  } catch (_) {}
}

/// Tiny tap tick for buttons / cells.
void tickHaptic() => vibratePattern(const [0, 14], quiet: true);

/// A touch stronger (wrong move, small warning).
void softHaptic() => vibratePattern(const [0, 35], quiet: true);

/// Strong single pulse (game over).
void strongHaptic() => vibratePattern(const [0, 80]);

/// Little celebratory double pulse (level / game complete).
void successHaptic() => vibratePattern(const [0, 40, 60, 90]);

/// Small pool of players so quick taps / notes can overlap (rhythm game).
class GameSound {
  /// Global sound switch (Settings + Breathing screen), remembered on the device.
  static bool enabled = true;
  static const _key = 'petalhaven.sound.v1';

  static Future<void> load() async {
    try {
      enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool v) async {
    enabled = v;
    if (!v) stopAlarm();
    try {
      (await SharedPreferences.getInstance()).setBool(_key, v);
    } catch (_) {}
  }

  static final List<AudioPlayer> _pool = List.generate(4, (_) => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
  static int _n = 0;
  static Future<void> play(String name, {double volume = .9}) async {
    if (!enabled) return;
    try {
      final pl = _pool[_n++ % _pool.length];
      await pl.stop();
      await pl.play(AssetSource('sounds/$name.wav'), volume: volume);
    } catch (_) {}
  }

  static void note(int i) => play('note${i.clamp(0, 8)}');
}
