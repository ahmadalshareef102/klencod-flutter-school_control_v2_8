import 'package:flutter/material.dart';
import 'smart_distribution.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../widgets.dart';

class CommitteesScreen extends StatefulWidget {
  const CommitteesScreen({super.key});
  @override
  State<CommitteesScreen> createState() => _CommitteesScreenState();
}

class _CommitteesScreenState extends State<CommitteesScreen> {
  List<Map<String, Object?>> classes = [], committees = [];
  int classId = 1;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Db.get();
    classes = await d.query('classes');
    committees = await d.rawQuery('''
      SELECT s.committee_no AS no, s.class_id AS cid, c.name AS cname,
             COUNT(*) AS n, COUNT(DISTINCT s.gender) AS g, MIN(s.gender) AS gender
      FROM students s JOIN classes c ON c.id = s.class_id
      WHERE s.committee_no IS NOT NULL
      GROUP BY s.committee_no, s.class_id ORDER BY s.committee_no''');
    if (mounted) setState(() {});
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _distribute() async {
    final cap = int.tryParse(await Db.setting('committee_capacity')) ?? 25;
    final sep = (await Db.setting('separate_gender')) == '1';
    setState(() => busy = true);
    final n = await Db.distributeCommittees(cap < 1 ? 25 : cap, sep);
    setState(() => busy = false);
    _msg('تم توزيع الطلاب على $n لجنة');
    _load();
  }

  Future<List<SheetStudent>> _students(String where, List<Object?> args) async {
    final d = await Db.get();
    final rows = await d.rawQuery('''
      SELECT s.name, s.gender, s.seat_no, s.committee_no, c.name AS cname
      FROM students s JOIN classes c ON c.id = s.class_id
      WHERE $where ORDER BY s.class_id, s.seat_no, s.id''', args);
    return [
      for (final r in rows)
        SheetStudent(r['seat_no'] as int?, r['name'] as String,
            r['cname'] as String, r['gender'] as String,
            r['committee_no'] as int?)
    ];
  }

  Future<void> _printCommittee(Map<String, Object?> c) async {
    final st = await _students(
        's.committee_no=? AND s.class_id=?', [c['no'], c['cid']]);
    final bytes = await buildCallSheets(
        [CommitteeSheet(c['no'] as int, c['cname'] as String, st)],
        await Db.setting('school'),
        await Db.setting('year'));
    await printPdf(bytes, 'لجنة ${c['no']}');
  }

  Future<void> _printAll() async {
    if (committees.isEmpty) return _msg('وزّع اللجان أولاً');
    final sheets = <CommitteeSheet>[];
    for (final c in committees) {
      sheets.add(CommitteeSheet(c['no'] as int, c['cname'] as String,
          await _students('s.committee_no=? AND s.class_id=?', [c['no'], c['cid']])));
    }
    final bytes = await buildCallSheets(
        sheets, await Db.setting('school'), await Db.setting('year'));
    await printPdf(bytes, 'كشوف المناداة');
  }

  Future<void> _printCards() async {
    final st = await _students('s.class_id=?', [classId]);
    if (st.isEmpty) return _msg('لا يوجد طلاب في هذا الصف');
    final bytes = await buildSeatCards(
        st, await Db.setting('school'), await Db.setting('year'));
    await printPdf(bytes, 'بطاقات الجلوس');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اللجان والجلوس')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  onPressed: () async {
                    await open(context, const SmartDistributionScreen());
                    _load();
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('التوزيع المتقدم (أبجدي ومتوازن)')),
              FilledButton.tonalIcon(
                  onPressed: busy ? null : _distribute,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('توزيع اللجان لكل الصفوف')),
              OutlinedButton.icon(
                  onPressed: _printAll,
                  icon: const Icon(Icons.print),
                  label: const Text('طباعة كل كشوف المناداة')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: classId,
                  items: [
                    for (final c in classes)
                      DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(c['name'] as String))
                  ],
                  onChanged: (v) => setState(() => classId = v!),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                  onPressed: _printCards,
                  icon: const Icon(Icons.badge),
                  label: const Text('بطاقات الجلوس')),
            ]),
          ),
          const Divider(),
          Expanded(
            child: committees.isEmpty
                ? const Center(child: Text('لم تُوزَّع اللجان بعد'))
                : ListView.builder(
                    itemCount: committees.length,
                    itemBuilder: (_, i) {
                      final c = committees[i];
                      final g = (c['g'] as int) > 1 ? 'مختلط' : c['gender'];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${c['no']}')),
                        title: Text('${c['cname']} • $g'),
                        subtitle: Text('عدد الطلاب: ${c['n']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.print),
                          onPressed: () => _printCommittee(c),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      );
}
