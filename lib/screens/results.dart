import 'package:flutter/material.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../results_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int classId = 1;
  List<Map<String, Object?>> classes = [];
  List<RankedResult> results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get className => (classes.firstWhere((c) => c['id'] == classId,
      orElse: () => {'name': ''})['name']) as String;

  Future<void> _load() async {
    final d = await Db.get();
    classes = await d.query('classes');
    results = await classResults(classId);
    if (mounted) setState(() {});
  }

  Color _color(String s) => s == 'ناجح'
      ? Colors.green
      : s == 'راسب'
          ? Colors.red
          : Colors.orange;

  Future<void> _print() async {
    if (results.isEmpty) return;
    final rows = [
      for (final r in results)
        [
          '${r.rank ?? '-'}',
          r.student['name'] as String,
          '${r.student['seat_no'] ?? '-'}',
          r.result.total.toStringAsFixed(0),
          '${r.result.percent.toStringAsFixed(1)}%',
          r.result.rating,
          r.result.status,
          r.result.failed.join('، '),
        ]
    ];
    final bytes = await buildResultSheet(className, rows,
        await Db.setting('school'), await Db.setting('year'));
    await printPdf(bytes, 'نتائج $className');
  }

  @override
  Widget build(BuildContext context) {
    final pass = results.where((r) => r.result.status == 'ناجح').length;
    return Scaffold(
      appBar: AppBar(title: const Text('النتائج'), actions: [
        IconButton(
            tooltip: 'طباعة كشف النتائج',
            icon: const Icon(Icons.print),
            onPressed: _print),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButton<int>(
            isExpanded: true,
            value: classId,
            items: [
              for (final c in classes)
                DropdownMenuItem(
                    value: c['id'] as int, child: Text(c['name'] as String))
            ],
            onChanged: (v) {
              classId = v!;
              _load();
            },
          ),
        ),
        Text('الإجمالي: ${results.length} • ناجحون: $pass'),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) {
              final s = results[i].student, r = results[i].result;
              return ListTile(
                leading: CircleAvatar(child: Text('${results[i].rank ?? '-'}')),
                title: Text(s['name'] as String),
                subtitle: Text(
                    '${r.total.toStringAsFixed(0)} / ${r.max.toStringAsFixed(0)}'
                    ' • ${r.percent.toStringAsFixed(1)}% • ${r.rating}'
                    '${r.failed.isEmpty ? '' : '\nراسب في: ${r.failed.join('، ')}'}'),
                trailing: Text(r.status,
                    style: TextStyle(
                        color: _color(r.status), fontWeight: FontWeight.bold)),
              );
            },
          ),
        ),
      ]),
    );
  }
}
