import 'package:flutter/material.dart';
import '../db.dart';
import '../logic.dart';
import '../pdf_reports.dart';
import '../report_engine.dart';
import '../results_service.dart';
import '../widgets.dart';
import 'form_cert_screen.dart';
import 'student_form.dart';

Future<void> printStudentCard(BuildContext context, int id) async {
  final d = await Db.get();
  final r = await d.query('students', where: 'id=?', whereArgs: [id]);
  if (r.isEmpty) return;
  final s = r.first;
  final cls = await Db.className(s['class_id'] as int);
  final kv = <List<String>>[
    ['الاسم', '${s['name']}'],
    ['رقم القيد', '${s['reg_no'] ?? ''}'],
    ['الصف', cls],
    ['الفصل / الشعبة', '${s['section'] ?? ''}'],
    ['الجنس', '${s['gender'] ?? ''}'],
    ['رقم الجلوس', '${s['seat_no'] ?? ''}'],
    ['اللجنة', '${s['committee_no'] ?? ''}'],
    ['حالة القيد', '${s['status'] ?? ''}'],
    ['تاريخ الميلاد', '${s['birth'] ?? ''}'],
    ['تاريخ التسجيل', '${s['reg_date'] ?? ''}'],
    ['ولي الأمر', '${s['guardian'] ?? ''}'],
    ['هاتف ولي الأمر', '${s['phone'] ?? ''}'],
    ['ملاحظات', '${s['notes'] ?? ''}'],
  ];
  final bytes = await buildStudentCard('${s['name']}', kv,
      await Db.setting('school'), await Db.setting('year'));
  await printPdf(bytes, 'بطاقة ${s['name']}');
}

Future<void> printStudentCert(BuildContext context, int id) async {
  final d = await Db.get();
  final r = await d.query('students', where: 'id=?', whereArgs: [id]);
  if (r.isEmpty) return;
  final which = await showOptions<int>(context, 'شهادة النتيجة', const [
    Opt(Icons.looks_one_outlined, 'نهاية الفصل الأول', 0),
    Opt(Icons.looks_two_outlined, 'نهاية الفصل الثاني', 1),
    Opt(Icons.workspace_premium_outlined, 'نهاية العام (الفصلان)', 2),
    Opt(Icons.assignment_ind_outlined, 'على النموذج الرسمي المطبوع', 3),
  ]);
  if (which == null) return;
  if (which == 3) {
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FormCertScreen(
            classId: r.first['class_id'] as int, studentId: id)));
    return;
  }
  final sc = Scope(r.first['class_id'] as int, null, null, 1);
  final data = await buildReport(
      which == 2 ? RKind.finalCerts : RKind.semesterCerts, sc,
      semester: which, onlyStudent: id);
  await printPdf(await data.pdf(), 'شهادة ${r.first['name']}');
}

class StudentProfile extends StatefulWidget {
  final int id;
  const StudentProfile({super.key, required this.id});
  @override
  State<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  DbRow? s;
  String cls = '';
  List<TranscriptRow> tr = [];
  Map<String, int> att = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Db.get();
    final r = await d.query('students', where: 'id=?', whereArgs: [widget.id]);
    if (r.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    s = r.first;
    cls = await Db.className(s!['class_id'] as int);
    tr = await transcript(widget.id, s!['class_id'] as int);
    final a = await d.rawQuery(
        'SELECT status, COUNT(*) c FROM attendance WHERE student_id=? GROUP BY status',
        [widget.id]);
    att = {for (final e in a) '${e['status']}': e['c'] as int};
    if (mounted) setState(() {});
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 110, child: Text(k, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(v.isEmpty ? '-' : v)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final st = s;
    if (st == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('${st['name']}'), actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () async {
            await open(context, StudentForm(id: widget.id));
            _load();
          },
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'card') await printStudentCard(context, widget.id);
            if (v == 'cert') await printStudentCert(context, widget.id);
            if (v == 'delete' &&
                await confirmDialog(context, 'حذف هذا الطالب نهائياً؟', ok: 'حذف', danger: true)) {
              await Db.deleteStudent(widget.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'card', child: Text('طباعة بطاقة الطالب')),
            PopupMenuItem(value: 'cert', child: Text('طباعة شهادة النتيجة')),
            PopupMenuItem(value: 'delete', child: Text('حذف الطالب')),
          ],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              _kv('رقم القيد', '${st['reg_no'] ?? ''}'),
              _kv('الصف', '$cls - ${st['section'] ?? ''}'),
              _kv('رقم الجلوس', '${st['seat_no'] ?? ''}'),
              _kv('اللجنة', '${st['committee_no'] ?? ''}'),
              _kv('الجنس', '${st['gender'] ?? ''}'),
              _kv('حالة القيد', '${st['status'] ?? ''}'),
              _kv('ولي الأمر', '${st['guardian'] ?? ''}'),
              _kv('الهاتف', '${st['phone'] ?? ''}'),
              _kv('ملاحظات', '${st['notes'] ?? ''}'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('الدرجات', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3)},
              children: [
                TableRow(children: [
                  for (final h in ['المادة', 'ف1', 'ف2', 'المجموع'])
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
                for (final t in tr)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(t.subject)),
                    Padding(padding: const EdgeInsets.all(6), child: Text(nf(t.t1))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(nf(t.t2))),
                    Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text((t.t1 == null && t.t2 == null) ? '' : nf(t.total))),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('الحضور (الكل)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Row(children: [
          for (final e in [
            ('حاضر', Colors.green), ('غائب', Colors.red),
            ('متأخر', Colors.orange), ('مستأذن', Colors.blue),
          ])
            Expanded(child: StatTile(e.$1, '${att[e.$1] ?? 0}', Icons.circle, e.$2)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
                onPressed: () => printStudentCard(context, widget.id),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('بطاقة الطالب')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
                onPressed: () => printStudentCert(context, widget.id),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('شهادة النتيجة')),
          ),
        ]),
      ]),
    );
  }
}
