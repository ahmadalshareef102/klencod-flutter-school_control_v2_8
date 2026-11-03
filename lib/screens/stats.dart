import 'package:flutter/material.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../results_service.dart';

/// خلاصة إحصائية لكل صف (تقابل ورقة C في الكنترول الأصلي).
class ClassStat {
  final String name;
  final int male, female, attended, absent, passed, second, failed;
  ClassStat(this.name, this.male, this.female, this.attended, this.absent,
      this.passed, this.second, this.failed);
  int get total => male + female;
  double get passRate => attended == 0 ? 0 : passed / attended * 100;
  List<String> get cells => [
        name, '$male', '$female', '$total', '$attended', '$absent',
        '$passed', '$second', '$failed', '${passRate.toStringAsFixed(1)}%',
      ];
}

const statHeads = [
  'الصف', 'ذكور', 'إناث', 'المسجلون', 'حضر', 'غاب',
  'نجح', 'دور ثانٍ', 'رسب', 'نسبة النجاح',
];

Future<List<ClassStat>> loadStats() async {
  final d = await Db.get();
  final out = <ClassStat>[];
  for (final c in await d.query('classes', orderBy: 'id')) {
    final res = await classResults(c['id'] as int);
    if (res.isEmpty) continue;
    int cnt(bool Function(RankedResult) f) => res.where(f).length;
    out.add(ClassStat(
      c['name'] as String,
      cnt((r) => r.student['gender'] != 'أنثى'),
      cnt((r) => r.student['gender'] == 'أنثى'),
      cnt((r) => r.result.status != 'غائب'),
      cnt((r) => r.result.status == 'غائب'),
      cnt((r) => r.result.status == 'ناجح'),
      cnt((r) => r.result.status == 'دور ثانٍ'),
      cnt((r) => r.result.status == 'راسب'),
    ));
  }
  return out;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<ClassStat> stats = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStats().then((s) {
      if (mounted) setState(() {
        stats = s;
        loading = false;
      });
    });
  }

  Future<void> _print() async {
    final bytes = await buildStatsSheet(statHeads,
        [for (final s in stats) s.cells], await Db.setting('school'),
        await Db.setting('year'));
    await printPdf(bytes, 'الإحصاء العام');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإحصاءات'), actions: [
          IconButton(
              tooltip: 'طباعة',
              icon: const Icon(Icons.print),
              onPressed: stats.isEmpty ? null : _print),
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : stats.isEmpty
                ? const Center(child: Text('لا توجد بيانات بعد'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          for (final h in statHeads) DataColumn(label: Text(h))
                        ],
                        rows: [
                          for (final s in stats)
                            DataRow(cells: [
                              for (final c in s.cells) DataCell(Text(c))
                            ]),
                        ],
                      ),
                    ),
                  ),
      );
}
