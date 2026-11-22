// Dart port of the website's RainlightMiniCore rules (shuffle, sliding board, lights, ...)
import 'dart:math' as math;

final math.Random rng = math.Random();

List<T> shuffle<T>(List<T> a, [math.Random? r]) {
  final x = List<T>.from(a);
  final rand = r ?? rng;
  for (var i = x.length - 1; i > 0; i--) {
    final j = rand.nextInt(i + 1);
    final t = x[i];
    x[i] = x[j];
    x[j] = t;
  }
  return x;
}

List<int> neighbors(int i, [int n = 3]) {
  final out = <int>[i - n, i + n];
  if (i % n != 0) out.add(i - 1);
  if (i % n < n - 1) out.add(i + 1);
  return out.where((k) => k >= 0 && k < n * n).toList();
}

bool solved(List<int> a) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != (i + 1) % a.length) return false;
  }
  return true;
}

List<int>? slide(List<int> a, int i) {
  final blank = a.indexOf(0);
  if (!neighbors(blank, math.sqrt(a.length).round()).contains(i)) return null;
  final b = List<int>.from(a);
  final t = b[i];
  b[i] = b[blank];
  b[blank] = t;
  return b;
}

List<int> slidingBoard([int size = 3, int steps = 90]) {
  var a = List<int>.generate(size * size, (i) => (i + 1) % (size * size));
  var previous = -1;
  for (var n = 0; n < steps; n++) {
    final blank = a.indexOf(0);
    final choices = neighbors(blank, size).where((i) => i != previous).toList();
    a = slide(a, choices[rng.nextInt(choices.length)])!;
    previous = blank;
  }
  return solved(a) ? slide(a, a.length - 2)! : a;
}

List<bool> toggleLights(List<bool> a, int i, int n) {
  final b = List<bool>.from(a);
  for (final k in [i, ...neighbors(i, n)]) {
    b[k] = !b[k];
  }
  return b;
}

class LightsPuzzle {
  final List<bool> board;
  final Set<int> solution;
  LightsPuzzle(this.board, this.solution);
}

LightsPuzzle lightsPuzzle(int n, int steps) {
  var a = List<bool>.filled(n * n, false);
  final sol = shuffle(List<int>.generate(n * n, (i) => i)).take(math.min(steps, n * n)).toList();
  for (final i in sol) {
    a = toggleLights(a, i, n);
  }
  if (a.every((v) => !v)) {
    a = toggleLights(a, 0, n);
    if (sol.contains(0)) {
      sol.remove(0);
    } else {
      sol.add(0);
    }
  }
  return LightsPuzzle(a, sol.toSet());
}

List<List<bool>> mazeCells(int n, math.Random random) {
  final cells = List.generate(n * n, (_) => [true, true, true, true]);
  final seen = <int>{0};
  final stack = <int>[0];
  while (stack.isNotEmpty) {
    final i = stack.last;
    final options = neighbors(i, n).where((j) => !seen.contains(j)).toList();
    if (options.isEmpty) {
      stack.removeLast();
      continue;
    }
    final j = shuffle(options, random)[0];
    final d = j == i - n ? 0 : j == i + 1 ? 1 : j == i + n ? 2 : 3;
    cells[i][d] = false;
    cells[j][(d + 2) % 4] = false;
    seen.add(j);
    stack.add(j);
  }
  return cells;
}
