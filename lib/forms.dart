// Daily log, period form, history, settings & backup (ports of the tracker layer's modals).
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercise.dart';
import 'theme.dart';
import 'tracker.dart';
import 'widgets.dart';

const monthsShortF = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
String fmtD(String d) => '${int.parse(d.substring(8))} ${monthsShortF[int.parse(d.substring(5, 7)) - 1]}';
String fmtRange(String a, String b) => a == b ? fmtD(a) : '${fmtD(a)} – ${fmtD(b)}';
String fmtLocal(String d) => '${d.substring(8)}/${d.substring(5, 7)}/${d.substring(0, 4)}';

// ------------------------------------------------------------------ small building blocks
Widget rtNote(String text, {bool small = false}) => Padding(
    padding: const EdgeInsets.only(top: 8), child: Text(text, style: ts(small ? 13 : 15, FontWeight.w700, mut, height: 1.5)));

Widget rtTitle(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 8), child: Text(t, style: ts(23, FontWeight.w800, ink, ls: -.3)));

BoxDecoration inputBox() => BoxDecoration(color: lav2, border: Border.all(color: lav3), borderRadius: BorderRadius.circular(18));

class RtField extends StatelessWidget {
  final String label;
  final Widget child;
  const RtField(this.label, this.child, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: ts(15, FontWeight.w700, ink)),
          const SizedBox(height: 7),
          child,
        ]),
      );
}

class RtSelect extends StatelessWidget {
  final String label, value;
  final List<String> values;
  final String Function(String)? labelOf;
  final ValueChanged<String> onChanged;
  const RtSelect(this.label, this.values, this.value, this.onChanged, {super.key, this.labelOf});
  @override
  Widget build(BuildContext context) => RtField(
        label,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: inputBox(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: values.contains(value) ? value : values.first,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              style: ts(15, FontWeight.w600, ink),
              icon: const Icon(Icons.keyboard_arrow_down, color: mut),
              items: [for (final v in values) DropdownMenuItem(value: v, child: Text(labelOf != null ? labelOf!(v) : (v.isEmpty ? 'Not recorded' : v)))],
              onChanged: (v) => onChanged(v ?? ''),
            ),
          ),
        ),
      );
}

InputDecoration inputDeco() => InputDecoration(
      filled: true,
      fillColor: lav2,
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: lav3)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: lav3)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: vio)),
      counterText: '',
    );

class DateField extends StatelessWidget {
  final String label;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const DateField(this.label, this.value, this.onChanged, {super.key, this.enabled = true});
  @override
  Widget build(BuildContext context) => RtField(
        label,
        Opacity(
          opacity: enabled ? 1 : .5,
          child: GestureDetector(
            onTap: !enabled
                ? null
                : () async {
                    final now = DateTime.now();
                    final init = value != null && value!.isNotEmpty ? DateTime.parse('${value}T12:00:00') : now;
                    final d = await showDatePicker(context: context, initialDate: init.isAfter(now) ? now : init, firstDate: DateTime(2000), lastDate: now);
                    if (d != null) onChanged(dayKey(d.year, d.month - 1, d.day));
                  },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: inputBox(),
              child: Text(value == null || value!.isEmpty ? 'dd/mm/yyyy' : fmtLocal(value!), style: ts(15, FontWeight.w600, ink)),
            ),
          ),
        ),
      );
}

/// ".cta" button
Widget ctaButton(String text, VoidCallback? onTap, {bool secondary = false, EdgeInsets margin = EdgeInsets.zero, bool disabled = false}) => Padding(
      padding: margin,
      child: Opacity(
        opacity: disabled ? .7 : 1,
        child: Pressable(
          scale: .96,
          onTap: disabled ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(
              gradient: secondary ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white, Color(0xFFF3EDFF)]) : grad160(const Color(0xFF8A6FE0), const Color(0xFF5C40B3)),
              border: secondary ? Border.all(color: const Color(0xFFE3D7FB)) : null,
              borderRadius: BorderRadius.circular(30),
              boxShadow: disabled
                  ? null
                  : secondary
                      ? const [BoxShadow(color: Color.fromRGBO(122, 90, 208, .35), blurRadius: 22, offset: Offset(0, 10), spreadRadius: -14)]
                      : const [BoxShadow(color: Color.fromRGBO(92, 64, 179, .8), blurRadius: 26, offset: Offset(0, 16), spreadRadius: -14)],
            ),
            child: Center(child: Text(text, textAlign: TextAlign.center, style: ts(15, FontWeight.w800, secondary ? vio : Colors.white))),
          ),
        ),
      ),
    );

Widget actionsRow(List<Widget> kids) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Row(children: [for (var i = 0; i < kids.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: kids[i])]]));

/// ".rt-links" button row
Widget linksRow(List<Widget> buttons) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Wrap(spacing: 8, runSpacing: 8, children: [for (final b in buttons) b]));

class LinkBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool expand;
  final double minHeight;
  const LinkBtn(this.text, this.onTap, {super.key, this.expand = true, this.minHeight = 0});
  @override
  Widget build(BuildContext context) => Pressable(
        scale: .94,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: lav2, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .5), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -12)]),
          child: Center(child: Text(text, textAlign: TextAlign.center, style: ts(minHeight > 0 ? 14 : 13, FontWeight.w700, ink))),
        ),
      );
}

Widget linkRowEqual(List<Widget> buttons) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(children: [for (var i = 0; i < buttons.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: buttons[i])]]));

Future<bool> confirmBox(BuildContext context, String text) async =>
    (await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: Text(text, style: ts(15, FontWeight.w700, ink, height: 1.4)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Cancel', style: ts(14, FontWeight.w800, mut))),
                TextButton(onPressed: () => Navigator.pop(c, true), child: Text('OK', style: ts(14, FontWeight.w800, vio))),
              ],
            ))) ??
    false;

Future<void> alertBox(BuildContext context, String text) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Text(text, style: ts(15, FontWeight.w700, ink, height: 1.4)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK', style: ts(14, FontWeight.w800, vio)))],
        ));

Widget sheetScroll(String title, List<Widget> kids) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        grabHandle(),
        Text(title, style: ts(23, FontWeight.w800, ink)),
        ...kids,
      ]),
    );

Widget historyRow(Widget content, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Pressable(
        scale: .97,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, .7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color.fromRGBO(255, 255, 255, .85)),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(86, 58, 170, .45), blurRadius: 24, offset: Offset(0, 14), spreadRadius: -20)],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: content), const SizedBox(width: 8), Text('›', style: ts(20, FontWeight.w700, mut))]),
        ),
      ),
    );

// ================================================================== Daily log
void openDaily(BuildContext context, Tracker t, String date) => showPanel(context, (c) => DailySheet(tracker: t, date: date));

class DailySheet extends StatefulWidget {
  final Tracker tracker;
  final String date;
  const DailySheet({super.key, required this.tracker, required this.date});
  @override
  State<DailySheet> createState() => _DailySheetState();
}

class _DailySheetState extends State<DailySheet> {
  Tracker get t => widget.tracker;
  late Map<String, dynamic> l = Map<String, dynamic>.from(t.state.logs[widget.date] ?? {});
  late final TextEditingController bbt = TextEditingController(text: l['bbt'] is num ? '${l['bbt']}' : '');
  late final TextEditingController notes = TextEditingController(text: (l['notes'] ?? '') as String);

  @override
  void dispose() {
    bbt.dispose();
    notes.dispose();
    super.dispose();
  }

  String v(String k) => (l[k] ?? '') as String;
  void set(String k, String val) => setState(() => l[k] = val);

  Future<void> save() async {
    final data = <String, dynamic>{
      for (final k in ['flow', 'mood', 'pain', 'energy', 'sleep', 'lh']) k: v(k),
      'bbt': bbt.text.trim(),
      'notes': notes.text,
    };
    final empty = data.values.every((x) => x == '');
    final err = t.transact((s) {
      if (empty) {
        s.logs.remove(widget.date);
      } else {
        s.logs[widget.date] = data;
      }
    });
    if (err != null) {
      await alertBox(context, err);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final saved = t.state.logs[date] != null;
    if (date.compareTo(todayKey()) > 0) {
      final m = t.model(date);
      return sheetScroll(fmtD(date), [rtNote(m.phase), rtNote('Future dates are estimates. Actual symptoms and periods can be logged on or after the day.'), ctaButton('Close', () => Navigator.pop(context), margin: const EdgeInsets.only(top: 30))]);
    }
    final period = t.periodOn(date);
    final more = (l['energy'] ?? '') != '' || (l['sleep'] ?? '') != '' || (l['lh'] ?? '') != '' || bbt.text.isNotEmpty || notes.text.isNotEmpty;
    return sheetScroll(fmtD(date), [
      linkRowEqual([
        LinkBtn(period != null ? 'Edit period' : 'Period started', () async {
          if (period != null) {
            Navigator.pop(context);
            openPeriodForm(context, t, date);
          } else {
            final err = t.transact((s) => s.periods.add(Period(date)));
            if (err != null) {
              await alertBox(context, err);
            } else if (mounted) {
              Navigator.pop(context);
            }
          }
        }),
        if (period != null)
          LinkBtn('Remove period', () async {
            if (await confirmBox(context, 'Remove the period starting ${fmtD(period.start)}? Daily symptom logs will stay.')) {
              final err = t.transact((s) => s.periods.removeWhere((x) => x.start == period.start));
              if (err != null) {
                if (mounted) await alertBox(context, err);
              } else if (mounted) {
                Navigator.pop(context);
              }
            }
          }),
      ]),
      if (period != null)
        linkRowEqual([
          LinkBtn('Remove this day only', () async {
            final err = t.removePeriodDay(date);
            if (err != null) {
              if (mounted) await alertBox(context, err);
            } else if (mounted) {
              Navigator.pop(context);
            }
          }),
        ]),
      RtSelect('Flow', const ['', 'None', 'Spotting', 'Light', 'Medium', 'Heavy'], v('flow'), (x) => set('flow', x)),
      RtSelect('Mood', const ['', 'Good', 'Quiet', 'Tired', 'Sensitive'], v('mood'), (x) => set('mood', x)),
      RtSelect('Cramps', const ['', 'None', 'Mild', 'Moderate', 'Severe'], v('pain'), (x) => set('pain', x)),
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text('More details${more ? ' · saved' : ''}', style: ts(15, FontWeight.w700, mut)),
          iconColor: mut,
          collapsedIconColor: mut,
          children: [
            RtSelect('Energy', const ['', 'Low', 'Okay', 'High'], v('energy'), (x) => set('energy', x)),
            RtSelect('Sleep', const ['', 'Poor', 'Okay', 'Good'], v('sleep'), (x) => set('sleep', x)),
            RtSelect('Ovulation test', const ['', 'Not taken', 'Negative', 'Positive'], v('lh'), (x) => set('lh', x)),
            RtField('Waking temperature · °C', TextField(controller: bbt, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: ts(15, FontWeight.w600, ink), decoration: inputDeco())),
            RtField('Notes', TextField(controller: notes, maxLength: 2000, minLines: 3, maxLines: 6, style: ts(15, FontWeight.w600, ink), decoration: inputDeco())),
          ],
        ),
      ),
      actionsRow([ctaButton('Save', save, secondary: true), ctaButton('Close', () => Navigator.pop(context))]),
      if (saved)
        linkRowEqual([
          LinkBtn('Remove daily log', () async {
            if (await confirmBox(context, 'Remove the daily log for ${fmtD(date)}? Period dates will stay.')) {
              final err = t.transact((s) => s.logs.remove(date));
              if (err == null && mounted) Navigator.pop(context);
            }
          }),
        ]),
    ]);
  }
}

// ================================================================== Period form
void openPeriodForm(BuildContext context, Tracker t, String date, {Period? original, bool forceNew = false}) =>
    showPanel(context, (c) => PeriodSheet(tracker: t, date: date, original: original, forceNew: forceNew));

class PeriodSheet extends StatefulWidget {
  final Tracker tracker;
  final String date;
  final Period? original;
  final bool forceNew;
  const PeriodSheet({super.key, required this.tracker, required this.date, this.original, this.forceNew = false});
  @override
  State<PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<PeriodSheet> {
  Tracker get t => widget.tracker;
  late final Period? p = widget.forceNew ? null : (widget.original ?? t.periodOn(widget.date));
  late String start = p?.start ?? widget.date;
  late bool estimate = p?.end == null;
  late String end = p?.end ?? '';

  Future<void> save() async {
    if (!estimate && end.isEmpty) {
      await alertBox(context, 'Enter the actual last day, or keep the five-day estimate.');
      return;
    }
    final old = p;
    final err = t.transact((s) {
      if (old != null) s.periods.removeWhere((x) => x.start == old.start);
      s.periods.add(Period(start, estimate ? null : end));
    });
    if (err != null) {
      await alertBox(context, err);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    String hint;
    try {
      hint = estimate ? 'Assumed end: ${fmtD(addDays(start, 4))} (five inclusive days; not confirmed).' : 'Enter the actual last day below.';
    } catch (_) {
      hint = '';
    }
    return sheetScroll(p != null ? 'Edit period' : 'Log period', [
      DateField('First day', start, (d) => setState(() => start = d)),
      GestureDetector(
        onTap: () => setState(() => estimate = !estimate),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(estimate ? Icons.check_box : Icons.check_box_outline_blank, color: vio, size: 22),
            const SizedBox(width: 8),
            Expanded(child: Text('Use a five-day estimate until the actual end is known', style: ts(15, FontWeight.w700, ink, height: 1.3))),
          ]),
        ),
      ),
      Text(p?.end != null && !estimate ? 'Actual end recorded' : hint, style: ts(13, FontWeight.w700, mut, height: 1.5)),
      DateField('Actual last day (when known)', end, (d) => setState(() => end = d), enabled: !estimate),
      rtNote('The first day is a confirmed cycle start. Estimated last days stay marked as estimates, and can be corrected later.'),
      actionsRow([ctaButton('Save period', save, secondary: true), ctaButton('Close', () => Navigator.pop(context))]),
      if (p != null)
        ctaButton('Remove this period entry', () async {
          if (await confirmBox(context, 'Remove this period entry? You can undo it in Settings.')) {
            final old = p!;
            final err = t.transact((s) => s.periods.removeWhere((x) => x.start == old.start));
            if (err == null && mounted) Navigator.pop(context);
          }
        }, margin: const EdgeInsets.only(top: 30)),
    ]);
  }
}

// ================================================================== History
void openHistory(BuildContext context, Tracker t) => showPanel(context, (c) => HistorySheet(tracker: t));

class HistorySheet extends StatefulWidget {
  final Tracker tracker;
  const HistorySheet({super.key, required this.tracker});
  @override
  State<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<HistorySheet> {
  Tracker get t => widget.tracker;
  String year = 'all';
  int visible = 90;

  @override
  Widget build(BuildContext context) {
    final st = t.state;
    final logs = st.logs.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final years = logs.map((e) => e.key.substring(0, 4)).toSet().toList()..sort((a, b) => b.compareTo(a));
    final filtered = year == 'all' ? logs : logs.where((e) => e.key.startsWith(year)).toList();
    final shown = filtered.take(visible).toList();
    final sessions = st.exercise.values.fold<int>(0, (n, a) => n + a.length);
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) => sheetScroll('History', [
        rtNote('Your saved records are all available here. Five-day endings remain estimates until you enter the actual last day.'),
        linkRowEqual([
          LinkBtn('＋ Add period start', minHeight: 52, () {
            Navigator.pop(context);
            openPeriodForm(context, t, todayKey(), forceNew: true);
          }),
          LinkBtn('Import records', minHeight: 52, () {
            Navigator.pop(context);
            openSettings(context, t);
          }),
        ]),
        if (st.periods.isEmpty) rtNote('No period dates yet. Add a start above.'),
        for (final p in st.periods.reversed)
          historyRow(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmtD(p.start)} ${p.start.substring(0, 4)}', style: ts(16, FontWeight.w800, ink)),
              const SizedBox(height: 4),
              Text(p.end != null ? 'Last day: ${fmtD(p.end!)} · recorded' : 'Around ${fmtD(endOf(p))} · estimated 5 days', style: ts(13, FontWeight.w700, mut, height: 1.35)),
            ]),
            () {
              Navigator.pop(context);
              openPeriodForm(context, t, p.start, original: p);
            },
          ),
        rtTitle('Daily records'),
        RtSelect('Find records by year', ['all', ...years], year, (v) => setState(() {
              year = v;
              visible = 90;
            }), labelOf: (v) => v == 'all' ? 'All years' : v),
        rtNote('Showing ${shown.length} of ${filtered.length} saved daily records. All records remain stored.', small: true),
        if (filtered.isEmpty) rtNote('No daily records for this selection.'),
        for (final e in shown)
          historyRow(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${fmtD(e.key)} ${e.key.substring(0, 4)}', style: ts(16, FontWeight.w800, ink)),
              const SizedBox(height: 4),
              Text(
                  [e.value['mood'], if ((e.value['pain'] ?? '') != '') '${e.value['pain']} pain', if ((e.value['flow'] ?? '') != '') '${e.value['flow']} flow']
                          .where((x) => x != null && x != '')
                          .join(' · ')
                          .isEmpty
                      ? 'Notes saved'
                      : [e.value['mood'], if ((e.value['pain'] ?? '') != '') '${e.value['pain']} pain', if ((e.value['flow'] ?? '') != '') '${e.value['flow']} flow'].where((x) => x != null && x != '').join(' · '),
                  style: ts(13, FontWeight.w700, mut, height: 1.35)),
            ]),
            () {
              Navigator.pop(context);
              openDaily(context, t, e.key);
            },
          ),
        if (visible < filtered.length)
          ctaButton('Show ${filtered.length - visible < 90 ? filtered.length - visible : 90} more', () => setState(() => visible += 90), margin: const EdgeInsets.only(top: 16)),
        rtTitle('Movement'),
        rtNote('$sessions completed sessions across ${st.exercise.length} days.'),
        ctaButton('Close', () => Navigator.pop(context), margin: const EdgeInsets.only(top: 26)),
      ]),
    );
  }
}

// ================================================================== Settings & backup
const extraKeys = ['rainlight.mini-games.v1', 'rainlight_unique_games_v3', 'rainlight.breathing.v1', 'rainlight.unique-notes.v2'];

void openSettings(BuildContext context, Tracker t) => showPanel(context, (c) => SettingsSheet(tracker: t));

class _Pending {
  final String kind;
  final TrackerState tracker;
  final Map<String, String> extras;
  final int periods, days;
  _Pending(this.kind, this.tracker, this.extras, this.periods, this.days);
}

class SettingsSheet extends StatefulWidget {
  final Tracker tracker;
  const SettingsSheet({super.key, required this.tracker});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  Tracker get t => widget.tracker;
  late bool predictions = t.state.predictions;
  late int reminder = t.state.reminderDays;
  bool soundOn = GameSound.enabled;
  _Pending? pending;
  String importStatus = 'Nothing selected.';

  Map<String, dynamic> fullBackup() {
    final extras = <String, String>{};
    for (final k in extraKeys) {
      final v = t.prefs?.getString(k);
      if (v != null) extras[k] = v;
    }
    return {'format': 'rainlight-full-backup', 'version': 2, 'exportedAt': DateTime.now().toUtc().toIso8601String(), 'tracker': t.state.toJson(), 'extras': extras};
  }

  Future<void> shareFile(String name, String content, String mime) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsString(content);
      await Share.shareXFiles([XFile(f.path, mimeType: mime)]);
    } catch (e) {
      if (mounted) await alertBox(context, 'Could not share the file: $e');
    }
  }

  String csvCell(Object? v) => '"${(v ?? '').toString().replaceFirstMapped(RegExp(r'^[=+@-]'), (m) => "'${m[0]}").replaceAll('"', '""')}"';

  String csv() {
    final rows = <List<Object?>>[
      ['Type', 'Date', 'End', 'End status', 'Mood', 'Flow', 'Pain', 'Energy', 'Sleep', 'BBT °C', 'LH test', 'Notes'],
      for (final p in t.state.periods) ['Period', p.start, p.end ?? endOf(p), p.end != null ? 'Recorded' : 'Estimated (5 days)'],
      for (final e in (t.state.logs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) ['Daily', e.key, '', '', e.value['mood'], e.value['flow'], e.value['pain'], e.value['energy'], e.value['sleep'], e.value['bbt'], e.value['lh'], e.value['notes']],
    ];
    return '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}';
  }

  String ics() {
    final f = t.model().forecast;
    if (f == null) throw const FormatException('More current cycle history is needed.');
    final date = f.preStart.replaceAll('-', '');
    final stampNow = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d{3}'), '');
    return ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Rainlight//Preparation reminder//EN', 'BEGIN:VEVENT', 'UID:rainlight-${f.last}@local', 'DTSTAMP:$stampNow', 'DTSTART;VALUE=DATE:$date', 'DTEND;VALUE=DATE:${addDays(f.preStart, 1).replaceAll('-', '')}', 'SUMMARY:A little preparation', 'DESCRIPTION:Check your comfort essentials. Timing is an estimate.', 'BEGIN:VALARM', 'TRIGGER:-PT9H', 'ACTION:DISPLAY', 'DESCRIPTION:A little preparation', 'END:VALARM', 'END:VEVENT', 'END:VCALENDAR'].join('\r\n');
  }

  List<List<String>> csvRows(String text) {
    text = text.replaceFirst('\uFEFF', '');
    final rows = <List<String>>[];
    var row = <String>[], field = '';
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"' && i + 1 < text.length && text[i + 1] == '"') {
          field += '"';
          i++;
        } else if (ch == '"') {
          quoted = false;
        } else {
          field += ch;
        }
      } else if (ch == '"') {
        if (field != '') throw const FormatException('Malformed CSV quotes.');
        quoted = true;
      } else if (ch == ',') {
        row.add(field);
        field = '';
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field);
        if (row.any((x) => x.trim().isNotEmpty)) rows.add(row);
        row = [];
        field = '';
      } else {
        field += ch;
      }
    }
    if (quoted) throw const FormatException('Unclosed CSV quote.');
    row.add(field);
    if (row.any((x) => x.trim().isNotEmpty)) rows.add(row);
    if (rows.length > 50000) throw const FormatException('Too many CSV rows for one import.');
    return rows;
  }

  _Pending importCsv(String text) {
    final rows = csvRows(text);
    final header = rows.isEmpty ? <String>[] : rows.removeAt(0).map((x) => x.trim().replaceFirst('\uFEFF', '')).toList();
    const expected = ['Type', 'Date', 'End', 'End status', 'Mood', 'Flow', 'Pain', 'Energy', 'Sleep', 'BBT °C', 'LH test', 'Notes'];
    for (var i = 0; i < expected.length; i++) {
      if (i >= header.length || header[i] != expected[i]) throw const FormatException('Select a Petalhaven or Rainlight History CSV export with its original column headings.');
    }
    final periods = <Map<String, dynamic>>[];
    final logs = <String, dynamic>{};
    final found = <String>{};
    String restore(String v) => v.replaceFirstMapped(RegExp(r"^'(?=[=+@-])"), (m) => '');
    for (final line in rows) {
      final c = [...line, ...List.filled(line.length < 12 ? 12 - line.length : 0, '')].map(restore).toList();
      final type = c[0], date = c[1];
      if (type == 'Period') {
        if (found.contains(date)) throw FormatException('Duplicate period start in CSV: $date');
        if (!['Recorded', 'Estimated (5 days)'].contains(c[3])) throw FormatException('Invalid end status for $date');
        if (c[3] == 'Recorded' && c[2].isEmpty) throw FormatException('A recorded period end is missing for $date');
        found.add(date);
        periods.add({'start': date, 'end': c[3] == 'Recorded' ? c[2] : null});
      } else if (type == 'Daily') {
        if (logs.containsKey(date)) throw FormatException('Duplicate daily date in CSV: $date');
        logs[date] = {'mood': c[4], 'flow': c[5], 'pain': c[6], 'energy': c[7], 'sleep': c[8], 'bbt': c[9], 'lh': c[10], 'notes': c[11]};
      } else {
        throw FormatException('Unknown CSV record type: $type');
      }
    }
    if (periods.isEmpty && logs.isEmpty) throw const FormatException('This CSV contains no period or daily records.');
    final cand = {'version': 1, 'periods': periods, 'logs': logs, 'exercise': {}, 'settings': {'predictions': t.state.predictions, 'reminderDays': t.state.reminderDays}};
    final tr = validateTracker(cand, todayKey());
    return _Pending('csv', tr, {}, periods.length, logs.length);
  }

  _Pending prepare(String name, String text) {
    if (name.toLowerCase().endsWith('.csv')) return importCsv(text);
    Map raw;
    try {
      raw = jsonDecode(text.replaceFirst('\uFEFF', '')) as Map;
    } catch (_) {
      throw const FormatException('This is not a valid JSON backup.');
    }
    if (raw['format'] == 'rainlight-full-backup') {
      if (raw['version'] != 2 || raw['tracker'] is! Map || raw['extras'] is! Map) throw const FormatException('Unsupported full backup.');
      final extras = <String, String>{};
      for (final k in extraKeys) {
        final v = (raw['extras'] as Map)[k];
        if (v == null) continue;
        if (v is! String || v.length > 3000000) throw const FormatException('Invalid saved game or note data.');
        try {
          jsonDecode(v);
        } catch (_) {
          throw FormatException('Invalid saved data for $k');
        }
        extras[k] = v;
      }
      final tr = validateTracker(raw['tracker'] as Map, todayKey());
      return _Pending('full', tr, extras, tr.periods.length, tr.logs.length);
    }
    final tr = validateTracker(raw, todayKey());
    return _Pending('legacy', tr, {}, tr.periods.length, tr.logs.length);
  }

  Future<void> pickFile() async {
    setState(() {
      pending = null;
    });
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      if (f.size > 15000000) throw const FormatException('The selected file is too large (15 MB maximum).');
      final text = utf8.decode(f.bytes ?? await File(f.path!).readAsBytes(), allowMalformed: true);
      final p = prepare(f.name, text);
      setState(() {
        pending = p;
        importStatus =
            'Ready to import ${p.periods} period starts and ${p.days} daily records from ${p.kind == 'csv' ? 'CSV history' : p.kind == 'full' ? 'full Petalhaven backup' : 'older Rainlight backup'}. Your existing data will be backed up before changes.';
      });
    } on FormatException catch (e) {
      setState(() => importStatus = 'Unable to import: ${e.message}');
    } catch (e) {
      setState(() => importStatus = 'Unable to import: $e');
    }
  }

  TrackerState merge(TrackerState current, TrackerState incoming, List<int> counts) {
    final next = validateTracker(jsonDecode(jsonEncode(current.toJson())) as Map, '9999-12-31');
    final seen = next.periods.map((p) => p.start).toSet();
    for (final p in incoming.periods) {
      if (!seen.contains(p.start)) {
        next.periods.add(p);
        seen.add(p.start);
        counts[0]++;
      }
    }
    incoming.logs.forEach((d, l) {
      if (!next.logs.containsKey(d)) {
        next.logs[d] = l;
        counts[1]++;
      }
    });
    incoming.exercise.forEach((d, ids) => next.exercise[d] = {...(next.exercise[d] ?? []), ...ids}.toList());
    return validateTracker(next.toJson(), todayKey());
  }

  Future<void> apply(String mode) async {
    final what = pending;
    if (what == null) return;
    final ok = await confirmBox(context, mode == 'merge' ? 'Add missing dates and keep existing records? A safety backup will be saved first.' : 'Replace current records with imported data? A safety backup will be saved first.');
    if (!ok) return;
    try {
      final counts = [0, 0];
      TrackerState incoming;
      if (mode == 'merge') {
        incoming = merge(t.state, what.tracker, counts);
      } else if (what.kind == 'csv') {
        final tmp = t.state.toJson();
        tmp['periods'] = what.tracker.toJson()['periods'];
        tmp['logs'] = what.tracker.toJson()['logs'];
        incoming = validateTracker(tmp, todayKey());
      } else {
        incoming = what.tracker;
      }
      // safety copy in the app's documents folder before touching anything
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/safety-before-import-${todayKey()}.json').writeAsString(jsonEncode(fullBackup()));
      final prefs = t.prefs ?? await SharedPreferences.getInstance();
      if (what.kind == 'full') {
        for (final k in extraKeys) {
          if (mode == 'replace') {
            what.extras.containsKey(k) ? await prefs.setString(k, what.extras[k]!) : await prefs.remove(k);
          } else if (prefs.getString(k) == null && what.extras.containsKey(k)) {
            await prefs.setString(k, what.extras[k]!);
          }
        }
      }
      t.replaceAll(incoming, mode == 'merge' ? 'Imported history saved on this device' : 'Backup restored on this device');
      if (!mounted) return;
      final summary = mode == 'merge' ? 'Added ${counts[0]} period starts and ${counts[1]} daily records. Existing entries were kept.' : 'Saved imported records.';
      Navigator.pop(context);
      await alertBox(context, summary + (what.kind == 'full' ? ' Reopen Petalhaven to refresh imported game progress.' : ''));
    } on FormatException catch (e) {
      setState(() => importStatus = e.message);
    } catch (e) {
      setState(() => importStatus = 'Nothing restored: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = todayKey();
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) => sheetScroll('Settings & backup', [
        rtNote(t.saveMessage),
        rtNote('Saved on this device inside this app. Data can disappear when app data is cleared or the app is uninstalled. Keep a private backup. No automatic cloud sync.'),
        GestureDetector(
          onTap: () => setState(() => predictions = !predictions),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Icon(predictions ? Icons.check_box : Icons.check_box_outline_blank, color: vio, size: 22),
              const SizedBox(width: 8),
              Text('Show cycle estimates', style: ts(15, FontWeight.w700, ink)),
            ]),
          ),
        ),
        Text('Pause estimates whenever they do not fit your circumstances.', style: ts(15, FontWeight.w700, mut, height: 1.5)),
        GestureDetector(
          onTap: () {
            setState(() => soundOn = !soundOn);
            GameSound.setEnabled(soundOn);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(children: [
              Icon(soundOn ? Icons.check_box : Icons.check_box_outline_blank, color: vio, size: 22),
              const SizedBox(width: 8),
              Text('Sounds (alarm, games, breathing)', style: ts(15, FontWeight.w700, ink)),
            ]),
          ),
        ),
        RtSelect('Period preparation reminder', const ['1', '2', '3', '5', '7'], '$reminder', (v) => setState(() => reminder = int.parse(v)), labelOf: (v) => '$v days before earliest estimate'),
        ctaButton('Save preferences', () async {
          final err = t.transact((s) {
            s.predictions = predictions;
            s.reminderDays = reminder;
          });
          if (err != null) {
            await alertBox(context, err);
          } else if (mounted) {
            Navigator.pop(context);
          }
        }),
        rtTitle('Your data'),
        rtNote('Share a full JSON backup to preserve periods, daily logs, exercises, game progress, breathing count, and daily note position. The CSV is for reading and importing period dates and daily logs.'),
        actionsRow([
          ctaButton('Share full backup', () => shareFile('rainlight-full-backup-$today.json', const JsonEncoder.withIndent('  ').convert(fullBackup()), 'application/json')),
          ctaButton('Export history CSV', () => shareFile('rainlight-history-$today.csv', csv(), 'text/csv')),
        ]),
        ctaButton('Export reminder to calendar', () async {
          try {
            await shareFile('rainlight-reminder.ics', ics(), 'text/calendar');
          } on FormatException catch (e) {
            await alertBox(context, e.message);
          }
        }, margin: const EdgeInsets.only(top: 18)),
        if (t.canUndo)
          ctaButton('Undo last saved change', () {
            t.undoLast();
            Navigator.pop(context);
          }, margin: const EdgeInsets.only(top: 18)),
        rtTitle('Import your records'),
        rtNote('Choose a full or older JSON backup, or a Petalhaven or older Rainlight history CSV. Merge adds missing dates without overwriting existing ones. Replace changes the current history. A safety copy is saved before either action.'),
        RtField('Choose a backup or history file', Pressable(
          scale: .96,
          onTap: pickFile,
          child: Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: inputBox(), child: Text('Choose file…', style: ts(15, FontWeight.w600, ink))),
        )),
        Text(importStatus, style: ts(15, FontWeight.w700, mut, height: 1.5)),
        if (pending != null)
          actionsRow([
            ctaButton('Merge imported history', () => apply('merge')),
            ctaButton(pending!.kind == 'csv' ? 'Replace dates and daily records' : 'Restore imported backup', () => apply('replace')),
          ]),
        ctaButton('Close', () => Navigator.pop(context), margin: const EdgeInsets.only(top: 30)),
      ]),
    );
  }
}
