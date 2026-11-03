import 'package:flutter/material.dart';
import '../app_state.dart';
import '../dates.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../report_engine.dart';
import '../widgets.dart';

const _states = [
  ('حاضر', Colors.green),
  ('غائب', Colors.red),
  ('متأخر', Colors.orange),
  ('مستأذن', Colors.blue),
];

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime date = DateTime.now();
  Scope? scope;
  List<DbRow> rows = [];
  Map<int, String> att = {};

  String get iso => isoDate(date);

  Future<void> _load() async {
    final sc = scope;
    if (sc == null) return;
    rows = await Db.students(classId: sc.classId, section: sc.section);
    att = await Db.attendanceOn(iso);
    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (d != null) {
      date = d;
      _load();
    }
  }

  void _shift(int days) {
    date = date.add(Duration(days: days));
    _load();
  }

  Future<void> _allPresent() async {
    for (final r in rows) {
      att[r['id'] as int] = 'حاضر';
      await Db.setAttendance(r['id'] as int, iso, 'حاضر');
    }
    if (mounted) setState(() {});
  }

  Future<void> _menu() async {
    final v = await showOptions<String>(context, 'خيارات الحضور', const [
      Opt(Icons.done_all, 'تحضير الكل حاضر', 'all'),
      Opt(Icons.print, 'طباعة تقرير الحضور الشهري', 'print'),
      Opt(Icons.ios_share, 'مشاركة التقرير PDF', 'share'),
      Opt(Icons.cleaning_services_outlined, 'مسح تحضير هذا اليوم', 'clear'),
    ]);
    if (v == null || !mounted) return;
    final sc = scope;
    if (sc == null) return;
    if (v == 'all') await _allPresent();
    if (v == 'print' || v == 'share') {
      try {
        final data = await buildReport(RKind.attendance, sc, date: date);
        await printPdf(await data.pdf(), data.table.title, share: v == 'share');
      } catch (e) {
        if (mounted) toast(context, 'تعذر إنشاء التقرير: $e');
      }
    }
    if (v == 'clear' &&
        await confirmDialog(context, 'مسح تحضير هذا اليوم لكل طلاب الاختيار؟',
            ok: 'مسح', danger: true)) {
      for (final r in rows) {
        await Db.setAttendance(r['id'] as int, iso, null);
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    int count(String s) => att.entries.where((e) => e.value == s && rows.any((r) => r['id'] == e.key)).length;
    final present = count('حاضر') + count('متأخر');
    final recorded = rows.where((r) => att.containsKey(r['id'])).length;
    final rate = recorded == 0 ? '-' : '${(present / recorded * 100).toStringAsFixed(0)}%';
    return Scaffold(
      appBar: AppBar(
        title: const Text('رصد الحضور والغياب'),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: _menu)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(-1)),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(fmtDate(date,
                      hijri: AppState.hijri.value, offset: AppState.hijriOffset)),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(1)),
            ]),
            const SizedBox(height: 8),
            ScopeBar(onChanged: (s) {
              scope = s;
              _load();
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    onPressed: rows.isEmpty ? null : _allPresent,
                    icon: const Icon(Icons.done_all),
                    label: const Text('تحضير الكل حاضر')),
              ),
            ]),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  for (final s in _states)
                    Column(children: [
                      Text('${count(s.$1)}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: s.$2)),
                      Text(s.$1, style: TextStyle(color: s.$2)),
                    ]),
                  Column(children: [
                    Text(rate,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
                    Text('نسبة الحضور (${rows.length - recorded} لم يُرصد)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ]),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('لا يوجد طلاب في هذا الاختيار'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final sid = r['id'] as int;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('رقم القيد: ${r['reg_no'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, children: [
                            for (final s in _states)
                              ChoiceChip(
                                label: Text(s.$1),
                                selected: att[sid] == s.$1,
                                selectedColor: s.$2.withOpacity(.28),
                                side: BorderSide(color: s.$2),
                                onSelected: (_) async {
                                  if (att[sid] == s.$1) {
                                    att.remove(sid);
                                    await Db.setAttendance(sid, iso, null);
                                  } else {
                                    att[sid] = s.$1;
                                    await Db.setAttendance(sid, iso, s.$1);
                                  }
                                  if (mounted) setState(() {});
                                },
                              ),
                          ]),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
