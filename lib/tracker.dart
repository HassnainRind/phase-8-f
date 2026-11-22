// Dart port of rainlight-tracker-core.js + the storage part of rainlight-tracker.js
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _day = 86400000;
const String storeKey = 'rainlight.tracker.v1';

int stamp(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) throw const FormatException('Use a valid date.');
  final n = DateTime.parse('${s}T00:00:00Z').millisecondsSinceEpoch;
  if (DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toIso8601String().substring(0, 10) != s) throw const FormatException('Use a valid date.');
  return n;
}
String iso(int n) =>
    DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toIso8601String().substring(0, 10);
String addDays(String d, int n) => iso(stamp(d) + n * _day);
int gap(String a, String b) => ((stamp(b) - stamp(a)) / _day).round();

String todayKey() {
  final n = DateTime.now();
  return dayKey(n.year, n.month - 1, n.day);
}

String dayKey(int y, int m0, int d) =>
    '$y-${(m0 + 1).toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';

class Period {
  String start;
  String? end;
  Period(this.start, [this.end]);
}

String endOf(Period p, [String? nextStart]) {
  var end = p.end ?? addDays(p.start, 4);
  if (p.end == null && nextStart != null && end.compareTo(nextStart) >= 0) {
    end = addDays(nextStart, -1);
  }
  return end;
}

class Forecast {
  final String earliest, latest, predictedEnd, next, ovStart, ovEnd, fertileStart, fertileEnd, lutealStart, preStart, last, source;
  Forecast(this.earliest, this.latest, this.predictedEnd, this.next, this.ovStart, this.ovEnd, this.fertileStart,
      this.fertileEnd, this.lutealStart, this.preStart, this.last, this.source);
}

class Estimate {
  String phase;
  int? day;
  double? mean;
  Forecast? forecast;
  String? reason;
  int late;
  bool approaching;
  bool fertile;
  int excluded;
  Estimate(this.phase,
      {this.day, this.mean, this.forecast, this.reason, this.late = 0, this.approaching = false, this.fertile = false, this.excluded = 0});
}

class TrackerState {
  List<Period> periods;
  Map<String, Map<String, dynamic>> logs;
  Map<String, List<int>> exercise;
  bool predictions;
  int reminderDays;
  TrackerState({required this.periods, required this.logs, required this.exercise, this.predictions = true, this.reminderDays = 3});

  factory TrackerState.fresh() => TrackerState(
        periods: ['2026-06-22', '2026-07-17', '2026-08-14', '2026-09-12', '2026-10-10', '2026-11-05'].map((s) => Period(s)).toList(),
        logs: {},
        exercise: {},
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'periods': periods.map((p) => {'start': p.start, 'end': p.end}).toList(),
        'logs': logs,
        'exercise': exercise,
        'settings': {'predictions': predictions, 'reminderDays': reminderDays},
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };

  factory TrackerState.fromJson(Map<String, dynamic> j) => validateTracker(j, todayKey());
}

const _allowed = {
  'mood': ['', 'Good', 'Quiet', 'Tired', 'Sensitive'],
  'flow': ['', 'None', 'Spotting', 'Light', 'Medium', 'Heavy'],
  'pain': ['', 'None', 'Mild', 'Moderate', 'Severe'],
  'energy': ['', 'Low', 'Okay', 'High'],
  'sleep': ['', 'Poor', 'Okay', 'Good'],
  'lh': ['', 'Not taken', 'Negative', 'Positive'],
};

/// Port of RainlightTrackerCore.validate
TrackerState validateTracker(Map raw, String today) {
  if (raw['version'] != 1 || raw['periods'] is! List || (raw['periods'] as List).length > 1000) throw const FormatException('Unsupported backup.');
  final periods = <Period>[];
  for (final p in raw['periods'] as List) {
    final start = p['start'];
    if (start is! String) throw const FormatException('Use a valid date.');
    stamp(start);
    if (start.compareTo(today) > 0) throw const FormatException('Period dates cannot be in the future.');
    final end = p['end'];
    if (end != null && end != '') {
      if (end is! String) throw const FormatException('Use a valid date.');
      stamp(end);
      if (end.compareTo(start) < 0 || end.compareTo(today) > 0 || gap(start, end) > 90) throw const FormatException('Check period end dates.');
    }
    periods.add(Period(start, (end == null || end == '') ? null : end as String));
  }
  periods.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < periods.length; i++) {
    final prev = periods[i - 1];
    if (periods[i].start == prev.start || (prev.end != null && periods[i].start.compareTo(prev.end!) <= 0)) throw const FormatException('Period entries overlap.');
  }
  for (final key in ['logs', 'exercise']) {
    if (raw[key] is! Map || (raw[key] as Map).length > 20000) throw const FormatException('Invalid daily records.');
  }
  final logs = <String, Map<String, dynamic>>{};
  (raw['logs'] as Map).forEach((date, l) {
    stamp(date as String);
    if (date.compareTo(today) > 0 || l is! Map) throw const FormatException('Invalid log date.');
    final out = <String, dynamic>{};
    _allowed.forEach((field, allowed) {
      final v = l[field];
      if (v != null && !allowed.contains(v)) throw FormatException('Invalid $field');
      out[field] = v ?? '';
    });
    final notes = l['notes'];
    if (notes != null && (notes is! String || notes.length > 2000)) throw const FormatException('Notes must be under 2,000 characters.');
    out['notes'] = notes ?? '';
    final b = l['bbt'];
    if (b == null || b == '') {
      out['bbt'] = '';
    } else {
      final n = b is num ? b.toDouble() : double.tryParse('$b');
      if (n == null || !n.isFinite || n < 34 || n > 42) throw const FormatException('Temperature must be 34–42 °C.');
      out['bbt'] = n;
    }
    logs[date] = out;
  });
  final ex = <String, List<int>>{};
  (raw['exercise'] as Map).forEach((date, list) {
    stamp(date as String);
    if (date.compareTo(today) > 0 || list is! List || list.any((i) => i is! int || i < 0 || i > 5)) throw const FormatException('Invalid exercise history.');
    ex[date] = list.cast<int>().toSet().toList();
  });
  final st = raw['settings'];
  if (st is! Map || st['predictions'] is! bool || ![1, 2, 3, 5, 7].contains(st['reminderDays'])) throw const FormatException('Invalid settings.');
  return TrackerState(periods: periods, logs: logs, exercise: ex, predictions: st['predictions'] as bool, reminderDays: st['reminderDays'] as int);
}

Estimate estimate(TrackerState s, String date) {
  final ps = s.periods.where((p) => p.start.compareTo(date) <= 0).toList();
  if (ps.isEmpty) return Estimate('Add a period start');
  final last = ps.last;
  final day = gap(last.start, date) + 1;
  final bleeding = date.compareTo(endOf(last)) <= 0;
  var intervals = <int>[for (var i = 1; i < ps.length; i++) gap(ps[i - 1].start, ps[i].start)];
  if (intervals.length > 6) intervals = intervals.sublist(intervals.length - 6);
  final usable = intervals.where((n) => n >= 21 && n <= 35).toList();
  final excluded = intervals.length - usable.length;
  final double? mean = usable.isEmpty ? null : usable.reduce((a, b) => a + b) / usable.length;
  final basePhase = bleeding ? (last.end != null ? 'Period logged' : 'Period days · estimated end') : 'Timing uncertain';
  Estimate base({String? phase, String? reason, int late = 0}) =>
      Estimate(phase ?? basePhase, day: day, mean: mean, reason: reason, late: late, excluded: excluded);

  if (!s.predictions) return base(phase: bleeding ? basePhase : 'Predictions paused');
  if (usable.length < 3) {
    return base(
        reason: intervals.length < 3
            ? 'Log at least four period starts for estimates.'
            : 'Cycle timing varies; calendar phase estimates are paused.');
  }
  final lo = usable.reduce((a, b) => a < b ? a : b), hi = usable.reduce((a, b) => a > b ? a : b);
  if (excluded > (intervals.length / 3).floor() || hi - lo > 9) {
    return base(reason: 'Cycle timing varies; calendar phase estimates are paused.');
  }
  final earliest = addDays(last.start, lo), latest = addDays(last.start, hi), next = addDays(last.start, mean!.round());
  final late = (!bleeding && date.compareTo(latest) > 0) ? gap(latest, date) : 0;
  var ovStart = addDays(earliest, -16), ovEnd = addDays(latest, -10), source = 'calendar';
  final cur = s.logs.keys.where((d) => d.compareTo(last.start) >= 0 && d.compareTo(date) <= 0).toList()..sort();
  String? lhDay;
  for (final d in cur) {
    if (s.logs[d]!['lh'] == 'Positive') {
      lhDay = d;
      break;
    }
  }
  if (lhDay != null) {
    ovStart = addDays(lhDay, 1);
    ovEnd = addDays(lhDay, 2);
    source = 'LH test';
  } else {
    final t = cur.where((d) => s.logs[d]!['bbt'] is num && (s.logs[d]!['bbt'] as num) > 0).toList();
    for (var i = 6; i + 2 < t.length; i++) {
      final base0 = t.sublist(i - 6, i).map((d) => (s.logs[d]!['bbt'] as num).toDouble()).reduce((a, b) => a > b ? a : b);
      if (t.sublist(i, i + 3).every((d) => (s.logs[d]!['bbt'] as num) >= base0 + 0.2)) {
        ovStart = ovEnd = addDays(t[i], -1);
        source = 'temperature shift';
        break;
      }
    }
  }
  var fertileStart = addDays(ovStart, -5);
  if (source != 'calendar' && fertileStart.compareTo(last.start) < 0) fertileStart = last.start;
  final fertileEnd = addDays(ovEnd, 1), lutealStart = addDays(ovEnd, 1), preStart = addDays(earliest, -s.reminderDays);
  final predictedEnd = addDays(latest, 4);
  if (date.compareTo(predictedEnd) > 0) {
    return base(
        late: late,
        reason: 'Your period is $late day${late == 1 ? '' : 's'} late. Log it when it starts, or keep tracking symptoms.');
  }
  final inPredicted = date.compareTo(earliest) >= 0 && date.compareTo(predictedEnd) <= 0;
  String phase;
  if (bleeding) {
    phase = basePhase;
  } else if (late > 0) {
    phase = 'Period late · $late day${late == 1 ? '' : 's'}';
  } else if (inPredicted) {
    phase = 'Estimated period · not confirmed';
  } else if (date.compareTo(ovStart) < 0) {
    phase = lhDay != null ? 'Fertile · LH surge logged' : 'Estimated follicular';
  } else if (date.compareTo(ovEnd) <= 0) {
    phase = source == 'calendar' ? 'Possible ovulation timing' : 'Ovulation likely · $source';
  } else {
    phase = 'Estimated luteal${source == 'calendar' ? '' : ' · ovulation seen by $source'}';
  }
  return Estimate(phase,
      day: day,
      mean: mean,
      late: late,
      excluded: excluded,
      approaching: date.compareTo(preStart) >= 0 && date.compareTo(earliest) < 0,
      fertile: !inPredicted && date.compareTo(fertileStart) >= 0 && date.compareTo(fertileEnd) <= 0,
      forecast: Forecast(earliest, latest, predictedEnd, next, ovStart, ovEnd, fertileStart, fertileEnd, lutealStart, preStart, last.start, source));
}

class Tracker extends ChangeNotifier {
  TrackerState state = TrackerState.fresh();
  String saveMessage = 'Not saved yet';
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(storeKey);
    if (raw != null) {
      try {
        state = TrackerState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        saveMessage = 'Saved on this device';
      } catch (_) {
        saveMessage = 'Saved data could not be read. Export recovery data before restoring a backup.';
      }
    }
  }

  TrackerState? undoState;
  SharedPreferences? get prefs => _prefs;

  void _commit(String msg) {
    saveMessage = msg;
    _prefs?.setString(storeKey, jsonEncode(state.toJson()));
    notifyListeners();
  }

  /// Apply a change on a validated copy; returns an error message or null (success).
  String? transact(void Function(TrackerState s) change) {
    try {
      final copy = validateTracker(jsonDecode(jsonEncode(state.toJson())) as Map, '9999-12-31');
      change(copy);
      final checked = validateTracker(copy.toJson(), todayKey());
      undoState = state;
      state = checked;
      _commit('Saved on this device');
      return null;
    } on FormatException catch (e) {
      saveMessage = 'Not saved: ${e.message}';
      notifyListeners();
      return saveMessage;
    }
  }

  bool get canUndo => undoState != null;

  void undoLast() {
    final prev = undoState;
    if (prev == null) return;
    state = prev;
    undoState = null;
    _commit('Change undone');
  }

  void replaceAll(TrackerState next, String msg) {
    undoState = state;
    state = next;
    _commit(msg);
  }

  Estimate model([String? d]) => estimate(state, d ?? todayKey());

  Period? periodOn(String d) {
    final ps = state.periods;
    for (var i = 0; i < ps.length; i++) {
      if (d.compareTo(ps[i].start) >= 0 && d.compareTo(endOf(ps[i], i + 1 < ps.length ? ps[i + 1].start : null)) <= 0) return ps[i];
    }
    return null;
  }

  bool isPeriod(String d) => periodOn(d) != null;
  bool isAssumed(String d) {
    final p = periodOn(d);
    return p != null && p.end == null && d != p.start;
  }

  void addPeriodStart(String date) {
    if (date.compareTo(todayKey()) > 0 || isPeriod(date)) return;
    transact((s) => s.periods.add(Period(date)));
  }

  void removePeriodOn(String date) {
    final p = periodOn(date);
    if (p == null) return;
    transact((s) => s.periods.removeWhere((x) => x.start == p.start));
  }

  /// Remove ONE day from a period (start, end or middle) instead of the whole batch.
  /// A middle day splits the period in two; estimated days are turned into confirmed days first.
  String? removePeriodDay(String date) {
    final p = periodOn(date);
    if (p == null) return null;
    final ps = state.periods;
    final i = ps.indexWhere((x) => x.start == p.start);
    final next = i + 1 < ps.length ? ps[i + 1].start : null;
    final eff = endOf(p, next);
    final today = todayKey();
    final lastDay = eff.compareTo(today) > 0 ? today : eff;
    return transact((s) {
      final idx = s.periods.indexWhere((x) => x.start == p.start);
      if (idx < 0) return;
      s.periods.removeAt(idx);
      final parts = <Period>[];
      if (date != p.start) parts.add(Period(p.start, addDays(date, -1)));
      final after = addDays(date, 1);
      if (after.compareTo(lastDay) <= 0) parts.add(Period(after, lastDay));
      s.periods.insertAll(idx, parts);
    });
  }

  void setLog(String date, String field, String value) {
    transact((s) {
      final l = Map<String, dynamic>.from(s.logs[date] ?? {});
      l[field] = value;
      s.logs[date] = l;
    });
  }

  void markExercise(String date, int i) {
    transact((s) {
      final l = List<int>.from(s.exercise[date] ?? <int>[]);
      if (!l.contains(i)) l.add(i);
      s.exercise[date] = l;
    });
  }

  String patternText() {
    final periods = state.periods;
    if (periods.isEmpty) return 'Start by adding the first period date';
    final spans = <int>[for (var i = 1; i < periods.length; i++) gap(periods[i - 1].start, periods[i].start)];
    final last6 = spans.length > 6 ? spans.sublist(spans.length - 6) : spans;
    final n = last6.isEmpty ? null : (last6.reduce((a, b) => a + b) / last6.length).round();
    final assumed = periods.where((p) => p.end == null).length;
    return '${periods.length} ${periods.length == 1 ? 'start' : 'starts'} saved'
        '${n != null ? ' · about $n days between starts' : ''} · '
        '${assumed > 0 ? '$assumed ${assumed == 1 ? 'end' : 'ends'} estimated at ~5 days' : 'all end dates confirmed'}';
  }
}
