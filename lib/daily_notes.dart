// Port of the "Daily little" notes: same 500 tips + 500 facts, same shuffled order and day stepping.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tracker.dart';

class Note {
  final String category, text, src;
  Note(this.category, this.text, this.src);
}

int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

List<int> permutation(int n, int seed) {
  var x = seed & 0xFFFFFFFF;
  double rand() {
    x = (x + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(x ^ (x >> 15), 1 | x);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  final ar = List<int>.generate(n, (i) => i);
  for (var i = n - 1; i > 0; i--) {
    final j = (rand() * (i + 1)).floor();
    final tmp = ar[i];
    ar[i] = ar[j];
    ar[j] = tmp;
  }
  return ar;
}

class DailyNotes extends ChangeNotifier {
  late List<Note> advice, facts;
  late Map<String, String> sources;
  late List<int> orderA, orderF;
  int step = 0;
  String day = todayKey();
  static const key = 'rainlight.unique-notes.v2';
  SharedPreferences? _prefs;

  int get cycle => advice.length;

  Future<void> load() async {
    final j = jsonDecode(await rootBundle.loadString('assets/data/daily.json')) as Map<String, dynamic>;
    List<Note> toNotes(List l) => l.map((e) => Note(e['category'], e['text'], e['src'])).toList();
    advice = toNotes(j['advice']);
    facts = toNotes(j['facts']);
    sources = Map<String, String>.from(j['sources']);
    orderA = permutation(advice.length, 0x51a2b3c4);
    orderF = permutation(facts.length, 0xa1e6dc9b);
    step = (stamp(day) ~/ 86400000) % cycle;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(key);
    if (raw != null) {
      try {
        final st = jsonDecode(raw) as Map<String, dynamic>;
        step = (st['step'] as int) % cycle;
        if (st['day'] != day) step = (step + 1) % cycle;
      } catch (_) {}
    }
    _save();
  }

  void _save() => _prefs?.setString(key, jsonEncode({'day': day, 'step': step}));

  Note get currentAdvice => advice[orderA[step]];
  Note get currentFact => facts[orderF[step]];

  void shuffle() {
    step = (step + 1) % cycle;
    _save();
    notifyListeners();
  }
}
