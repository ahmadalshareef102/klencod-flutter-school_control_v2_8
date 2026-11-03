import 'package:flutter/material.dart';
import '../data_io.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../report_engine.dart';
import '../widgets.dart';
import 'committees.dart';
import 'detailed_options.dart';
import 'excel_center.dart';
import 'official_cert_screen.dart';
import 'report_picker.dart';
import 'results.dart';
import 'stats.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  ReportSel? sel;
  DetailedOptions det = DetailedOptions();
  bool busy = false;
  String year = '';

  @override
  void initState() {
    super.initState();
    Db.setting('year').then((v) {
      if (mounted) setState(() => year = v);
    });
  }

  Future<void> _run(String action) async {
    final s = sel;
    if (s == null || s.scope == null) return;
    setState(() => busy = true);
    try {
      final data = await buildReport(s.meta.kind, s.scope!,
          semester: s.semester, date: s.date, detailed: det);
      switch (action) {
        case 'print':
          await printPdf(await data.pdf(), data.table.title);
        case 'share':
          await printPdf(await data.pdf(), data.table.title, share: true);
        case 'xlsx':
          await shareReport(data, xlsx: true);
        case 'csv':
          await shareReport(data, xlsx: false);
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر إنشاء التقرير: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
      PageHeader('التقارير والاستمارات الرسمية',
          subtitle: 'استمارات A4 وطباعة PDF للعام $year',
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              final v = await showOptions<int>(context, 'تقارير أخرى', const [
                Opt(Icons.event_seat, 'اللجان وكشوف المناداة وبطاقات الجلوس', 0),
                Opt(Icons.leaderboard, 'شاشة النتائج', 1),
                Opt(Icons.bar_chart, 'الإحصاء العام وطباعته', 2),
                Opt(Icons.table_chart, 'مركز Excel و CSV', 3),
                Opt(Icons.workspace_premium, 'الشهادة الرسمية على النموذج (طباعة البيانات فقط)', 4),
              ]);
              if (v == null || !mounted) return;
              open(context, [
                const CommitteesScreen(), const ResultsScreen(),
                const StatsScreen(), const ExcelCenter(),
                const OfficialCertScreen(),
              ][v]);
            },
          )),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          ReportPicker(onChanged: (s) {
            final changed = sel?.meta.kind != s.meta.kind;
            sel = s;
            if (changed && mounted) setState(() {});
          }),
          if (sel?.meta.kind == RKind.detailedSheet) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final o = await showDetailedOptions(context, det);
                  if (o != null) setState(() => det = o);
                },
                icon: const Icon(Icons.tune),
                label: const Text('تخصيص الترويسة والأعمدة ومستوى التفاصيل'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: busy ? null : () => _run('print'),
              icon: const Icon(Icons.print),
              label: const Text('طباعة فورية A4 (طابعة أو PDF)'),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _run('share'),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('مشاركة / حفظ PDF')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final v = await showOptions<String>(context, 'تصدير الجدول', const [
                            Opt(Icons.table_chart, 'Excel (xlsx)', 'xlsx'),
                            Opt(Icons.description_outlined, 'CSV بترميز UTF-8', 'csv'),
                          ]);
                          if (v != null) _run(v);
                        },
                  icon: const Icon(Icons.download),
                  label: const Text('Excel / CSV')),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
