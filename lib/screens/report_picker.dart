import 'package:flutter/material.dart';
import '../app_state.dart';
import '../dates.dart';
import '../db.dart';
import '../report_engine.dart';
import '../widgets.dart';

class ReportSel {
  final RMeta meta;
  final Scope? scope;
  final int semester;
  final DateTime date;
  final int count;
  const ReportSel(this.meta, this.scope, this.semester, this.date, this.count);
}

/// اختيار نوع التقرير والنطاق (مشترك بين التقارير ومركز Excel).
class ReportPicker extends StatefulWidget {
  final ValueChanged<ReportSel> onChanged;
  const ReportPicker({super.key, required this.onChanged});
  @override
  State<ReportPicker> createState() => _ReportPickerState();
}

class _ReportPickerState extends State<ReportPicker> {
  RMeta meta = reportMetas.first;
  int semester = 0;
  DateTime date = DateTime.now();
  Scope? scope;
  int count = 0;
  String cls = '', subject = '';

  Future<void> _emit() async {
    final sc = scope;
    if (sc != null) {
      count = (await Db.students(classId: sc.classId, section: sc.section)).length;
      cls = await Db.className(sc.classId);
      if (sc.subjectId != null) {
        final r = await (await Db.get())
            .query('subjects', where: 'id=?', whereArgs: [sc.subjectId]);
        subject = r.isEmpty ? '' : '${r.first['name']}';
      }
    }
    if (mounted) setState(() {});
    widget.onChanged(ReportSel(meta, sc, semester, date, count));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = scope;
    final hijri = AppState.hijri.value;
    final lines = <String>[
      'التقرير: ${meta.title}',
      if (meta.semester) 'الفصل الدراسي: ${semester == 0 ? 'الأول' : semester == 1 ? 'الثاني' : 'الفصلان معاً'}',
      'الصف: $cls  |  الشعبة: ${sc?.section ?? 'كل الشعب'}',
      if (meta.subject) 'المادة: $subject',
      if (meta.month && sc != null) 'الشهر: ${monthName(sc.month, hijri)}',
      if (meta.date) 'شهر التقرير: ${gregMonths[date.month - 1]} ${date.year}',
      'التاريخ: ${fmtDate(DateTime.now(), hijri: hijri, offset: AppState.hijriOffset)}',
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (meta.semester) ...[
              Text('الفصل الدراسي', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: [
                  const ButtonSegment(value: 0, label: Text('الفصل الأول')),
                  const ButtonSegment(value: 1, label: Text('الفصل الثاني')),
                  if (meta.both) const ButtonSegment(value: 2, label: Text('الفصلان معاً')),
                ],
                selected: {semester},
                onSelectionChanged: (s) {
                  semester = s.first;
                  _emit();
                },
              ),
              const SizedBox(height: 12),
            ],
            Pick<RKind>(
              label: 'نوع التقرير',
              value: meta.kind,
              items: [
                for (final m in reportMetas)
                  DropdownMenuItem(
                      value: m.kind,
                      child: Row(children: [
                        Flexible(child: Text(m.title, overflow: TextOverflow.ellipsis)),
                        if (m.isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text('★ جديد',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ]))
              ],
              onChanged: (v) {
                meta = reportMetas.firstWhere((m) => m.kind == v);
                if (!meta.both && semester == 2) semester = 0;
                scope = null;
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            ScopeBar(
              key: ValueKey(meta.kind),
              subject: meta.subject,
              month: meta.month,
              onChanged: (s) {
                scope = s;
                _emit();
              },
            ),
            if (meta.date) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text('اختر أي يوم من الشهر المطلوب: ${gregMonths[date.month - 1]} ${date.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (d != null) {
                    date = d;
                    _emit();
                  }
                },
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Card(
        color: cs.primaryContainer.withOpacity(.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.check_circle, color: cs.primary, size: 20),
              const SizedBox(width: 6),
              Text('عدد الطلاب المشمولين: $count',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
            ]),
            const SizedBox(height: 6),
            Text(meta.desc, style: Theme.of(context).textTheme.bodySmall),
            const Divider(),
            for (final l in lines) Text('• $l', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    ]);
  }
}
