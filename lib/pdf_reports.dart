import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'logic.dart';

class SheetStudent {
  final int? seat;
  final String name, className, gender;
  final int? committee;
  SheetStudent(this.seat, this.name, this.className, this.gender,
      [this.committee]);
}

class CommitteeSheet {
  final int no;
  final String className;
  final List<SheetStudent> students;
  CommitteeSheet(this.no, this.className, this.students);
}

Future<pw.ThemeData> _theme() async {
  final r = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final b = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  return pw.ThemeData.withFont(base: r, bold: b);
}

pw.Widget _t(String s,
        {double size = 11,
        bool bold = false,
        pw.TextAlign align = pw.TextAlign.center}) =>
    pw.Text(s,
        textDirection: pw.TextDirection.rtl,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

pw.Widget _cell(String s, {bool bold = false, double size = 10}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 3),
    child: _t(s, bold: bold, size: size));

/// يعرض الأعمدة من اليمين لليسار بعكس ترتيبها المنطقي.
List<T> _rtl<T>(List<T> l) => l.reversed.toList();

pw.Widget _header(String school, String year) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: _rtl([
        pw.Column(children: [
          _t('الجمهورية اليمنية', bold: true),
          _t('وزارة التربية والتعليم'),
        ]),
        _t('بسم الله الرحمن الرحيم', bold: true, size: 12),
        pw.Column(children: [
          _t('المدرسة: ${school.isEmpty ? '................' : school}'),
          _t('العام الدراسي: $year'),
        ]),
      ]),
    );

pw.Widget _signatures() => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: _rtl([
        _t('رئيس الكنترول: ...............'),
        _t('مدير المدرسة: ...............'),
      ]),
    );

/// كشوف مناداة الطلاب في اللجان: صفحة لكل لجنة.
Future<Uint8List> buildCallSheets(
    List<CommitteeSheet> sheets, String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  for (final sh in sheets) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(children: [
        _header(school, year),
        pw.SizedBox(height: 10),
        _t('كشف مناداة الطلاب في اللجنة (${sh.no}) - ${sh.className}',
            bold: true, size: 14),
        pw.SizedBox(height: 8),
      ]),
      footer: (_) => _signatures(),
      build: (_) {
        const heads = ['م', 'اسم الطالب', 'رقم الجلوس', 'التوقيع', 'الحالة', 'ملاحظات'];
        final widths = _rtl([
          const pw.FixedColumnWidth(24),
          const pw.FlexColumnWidth(4),
          const pw.FixedColumnWidth(60),
          const pw.FlexColumnWidth(2),
          const pw.FixedColumnWidth(60),
          const pw.FlexColumnWidth(2),
        ]);
        return [
          pw.Table(
            border: pw.TableBorder.all(width: 0.6),
            columnWidths: {for (var i = 0; i < widths.length; i++) i: widths[i]},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: _rtl([for (final h in heads) _cell(h, bold: true)]),
              ),
              for (var i = 0; i < sh.students.length; i++)
                pw.TableRow(
                  children: _rtl([
                    _cell('${i + 1}'),
                    _cell(sh.students[i].name),
                    _cell('${sh.students[i].seat ?? '-'}'),
                    _cell(''),
                    _cell('حاضر / غائب'),
                    _cell(''),
                  ]),
                ),
            ],
          ),
        ];
      },
    ));
  }
  return doc.save();
}

/// بطاقات أرقام الجلوس (10 بطاقات في الصفحة).
Future<Uint8List> buildSeatCards(
    List<SheetStudent> students, String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  for (var start = 0; start < students.length; start += 10) {
    final chunk = students.skip(start).take(10).toList();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.GridView(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          for (final s in chunk)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _t('بطاقة رقم جلوس - ${school.isEmpty ? '' : school}',
                      bold: true, size: 10),
                  _t(s.name, bold: true, size: 12),
                  _t('رقم الجلوس: ${s.seat ?? '-'}', size: 12, bold: true),
                  _t('${s.className}   •   اللجنة: ${s.committee ?? '-'}',
                      size: 10),
                  _t(year, size: 9),
                ],
              ),
            ),
        ],
      ),
    ));
  }
  if (students.isEmpty) doc.addPage(pw.Page(build: (_) => _t('لا يوجد طلاب')));
  return doc.save();
}

Future<void> printPdf(Uint8List bytes, String name, {bool share = false}) =>
    share
        ? Printing.sharePdf(bytes: bytes, filename: '$name.pdf')
        : Printing.layoutPdf(onLayout: (_) async => bytes, name: name);

/// جدول عام: [heads] و[rows] بالترتيب المنطقي (يُعرض من اليمين لليسار).
pw.Widget _grid(List<String> heads, List<List<String>> rows,
    List<pw.TableColumnWidth> widths, {double size = 10}) {
  final w = _rtl(widths);
  return pw.Table(
    border: pw.TableBorder.all(width: 0.6),
    columnWidths: {for (var i = 0; i < w.length; i++) i: w[i]},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: _rtl([for (final h in heads) _cell(h, bold: true, size: size)]),
      ),
      for (final r in rows)
        pw.TableRow(children: _rtl([for (final c in r) _cell(c, size: size)])),
    ],
  );
}

/// كشف النتائج مرتباً: ترتيب، اسم، جلوس، مجموع، نسبة، تقدير، نتيجة، مواد الرسوب.
Future<Uint8List> buildResultSheet(String className, List<List<String>> rows,
    String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(children: [
      _header(school, year),
      pw.SizedBox(height: 10),
      _t('كشف النتائج - $className', bold: true, size: 14),
      pw.SizedBox(height: 8),
    ]),
    footer: (_) => _signatures(),
    build: (_) => [
      _grid(
        ['الترتيب', 'اسم الطالب', 'رقم الجلوس', 'المجموع', 'النسبة', 'التقدير', 'النتيجة', 'المواد الراسب فيها'],
        rows,
        const [
          pw.FixedColumnWidth(40), pw.FlexColumnWidth(4), pw.FixedColumnWidth(50),
          pw.FixedColumnWidth(45), pw.FixedColumnWidth(45), pw.FixedColumnWidth(50),
          pw.FixedColumnWidth(50), pw.FlexColumnWidth(3),
        ],
      ),
    ],
  ));
  return doc.save();
}

/// الخلاصة الإحصائية العامة (أفقي).
Future<Uint8List> buildStatsSheet(List<String> heads, List<List<String>> rows,
    String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(children: [
      _header(school, year),
      pw.SizedBox(height: 10),
      _t('الخلاصة العامة لنتائج الطلاب على مستوى المدرسة', bold: true, size: 14),
      pw.SizedBox(height: 8),
    ]),
    footer: (_) => _signatures(),
    build: (_) => [
      _grid(heads, rows, [
        const pw.FlexColumnWidth(3),
        for (var i = 1; i < heads.length; i++) const pw.FlexColumnWidth(1.2),
      ]),
    ],
  ));
  return doc.save();
}

// ===================== المرحلة 2.0: شهادات وإشعارات وتقارير عامة =====================

class MonthlyRowData {
  final String subject;
  final double? hw, att, oral, written;
  MonthlyRowData(this.subject, this.hw, this.att, this.oral, this.written);
  bool get has => hw != null || att != null || oral != null || written != null;
  double get total => (hw ?? 0) + (att ?? 0) + (oral ?? 0) + (written ?? 0);
}

class MonthlyCertData {
  final String name, className, absence;
  final int? seat;
  final List<MonthlyRowData> rows;
  MonthlyCertData(this.name, this.seat, this.className, this.absence, this.rows);
}

class NoticeData {
  final String name, regNo, className, section, avg, exam, total;
  final List<List<String>> monthRows;
  NoticeData(this.name, this.regNo, this.className, this.section,
      this.monthRows, this.avg, this.exam, this.total);
}

class SemAllData {
  final String name, regNo, className, section, totalText, percentText;
  final List<List<String>> rows; // مادة، معدل، اختبار، مجموع
  SemAllData(this.name, this.regNo, this.className, this.section, this.rows,
      this.totalText, this.percentText);
}

String _nn(num? v) => nf(v);

pw.Widget _boxed(pw.Widget child) => pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.8),
          borderRadius: pw.BorderRadius.circular(4)),
      child: child,
    );

pw.Widget _monthlyBlock(MonthlyCertData c, String school, String year,
    String monthLabel, List<String> labels, List<double> maxes, double convertTo) {
  final totalMax = maxes.fold<double>(0, (a, b) => a + b);
  final heads = ['المادة', ...labels, 'المجموع', 'المحوّلة'];
  final rows = <List<String>>[
    for (final r in c.rows)
      [
        r.subject, _nn(r.hw), _nn(r.att), _nn(r.oral), _nn(r.written),
        r.has ? _nn(r.total) : '',
        r.has ? _nn(totalMax == 0 ? 0 : r.total / totalMax * convertTo) : '',
      ],
    ['النهاية العظمى', ...maxes.map(_nn), _nn(totalMax), _nn(convertTo)],
  ];
  final withData = c.rows.where((r) => r.has).toList();
  final conv = withData.fold<double>(
      0, (a, r) => a + (totalMax == 0 ? 0 : r.total / totalMax * convertTo));
  final summary = withData.isEmpty
      ? 'لم تُرصد درجات لهذا الشهر'
      : 'المجموع الكلي: ${_nn(conv)} من ${_nn(withData.length * convertTo)}';
  return pw.SizedBox(
    width: 540,
    child: _boxed(pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: _rtl([
          _t(school.isEmpty ? '' : school, size: 9),
          _t('شهادة درجات شهر $monthLabel', bold: true, size: 12),
          _t('العام الدراسي: $year', size: 9),
        ]),
      ),
      pw.SizedBox(height: 4),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: _rtl([
          _t('الطالب: ${c.name}', size: 10, bold: true),
          _t('رقم الجلوس: ${c.seat ?? '-'}', size: 10),
          _t(c.className, size: 10),
          _t(c.absence, size: 10),
        ]),
      ),
      pw.SizedBox(height: 4),
      _grid(heads, rows, <pw.TableColumnWidth>[
        const pw.FlexColumnWidth(3),
        const pw.FixedColumnWidth(54), const pw.FixedColumnWidth(54),
        const pw.FixedColumnWidth(54), const pw.FixedColumnWidth(54),
        const pw.FixedColumnWidth(48), const pw.FixedColumnWidth(48),
      ]),
      pw.SizedBox(height: 3),
      _t(summary, size: 9, bold: true),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: _rtl([
          _t('رائد الفصل: ..........', size: 8),
          _t('ولي الأمر: ..........', size: 8),
          _t('مسؤول الكنترول: ..........', size: 8),
          _t('المدير: ..........', size: 8),
        ]),
      ),
    ])),
  );
}

/// شهادات الدرجات الشهرية: ثلاث شهادات في صفحة A4.
Future<Uint8List> buildMonthlyCerts(
    List<MonthlyCertData> data,
    String school,
    String year,
    String monthLabel,
    List<String> labels,
    List<double> maxes,
    double convertTo) async {
  final doc = pw.Document(theme: await _theme());
  if (data.isEmpty) {
    doc.addPage(pw.Page(build: (_) => _t('لا يوجد طلاب')));
  }
  for (var i = 0; i < data.length; i += 3) {
    final chunk = data.skip(i).take(3).toList();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Column(children: [
        for (final c in chunk)
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.FittedBox(
                  child: _monthlyBlock(
                      c, school, year, monthLabel, labels, maxes, convertTo)),
            ),
          ),
        for (var k = chunk.length; k < 3; k++) pw.Expanded(child: pw.SizedBox()),
      ]),
    ));
  }
  return doc.save();
}

const _brand = PdfColor.fromInt(0xFF1E3A8A);

pw.Widget _tw(String s, {double size = 9, bool bold = false}) => pw.Text(s,
    textDirection: pw.TextDirection.rtl,
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(
        fontSize: size,
        color: PdfColors.white,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

pw.Widget _banner(String title, String sub) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      decoration: pw.BoxDecoration(
          color: _brand, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(children: [_tw(title, size: 11, bold: true), _tw(sub, size: 7)]),
    );

pw.Widget _summaryBox(List<List<String>> items) => pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _brand, width: 0.9),
          borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        children: _rtl([
          for (final it in items)
            pw.Expanded(
              child: pw.Column(children: [
                _t(it[0], size: 7),
                _t(it[1], size: 12, bold: true),
              ]),
            ),
        ]),
      ),
    );

/// يوزّع الكتل على صفحة بخطوط قص: 1 أو 2 أو 4 في الصفحة.
pw.Widget _cutPage(List<pw.Widget> blocks, int perPage) {
  pw.Widget cell(int i) => i < blocks.length
      ? pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topCenter,
              child: blocks[i]),
        )
      : pw.SizedBox();
  pw.Widget hcut() => pw.Column(children: [
        _t('قص هنا', size: 7),
        pw.Divider(height: 4, thickness: 0.6, color: PdfColors.grey600, borderStyle: pw.BorderStyle.dashed),
      ]);
  if (perPage == 1) {
    return pw.SizedBox(width: double.infinity, height: double.infinity, child: cell(0));
  }
  if (perPage == 2) {
    return pw.Column(children: [pw.Expanded(child: cell(0)), hcut(), pw.Expanded(child: cell(1))]);
  }
  pw.Widget row(int a, int b) => pw.Expanded(
        child: pw.Row(children: _rtl([
          pw.Expanded(child: cell(a)),
          pw.VerticalDivider(width: 6, thickness: 0.6, color: PdfColors.grey600, borderStyle: pw.BorderStyle.dashed),
          pw.Expanded(child: cell(b)),
        ])),
      );
  return pw.Column(children: [row(0, 1), hcut(), row(2, 3)]);
}

Future<Uint8List> _cutDoc(List<pw.Widget> blocks, int perPage) async {
  final doc = pw.Document(theme: await _theme());
  if (blocks.isEmpty) {
    doc.addPage(pw.Page(build: (_) => _t('لا يوجد طلاب')));
  }
  for (var i = 0; i < blocks.length; i += perPage) {
    final chunk = blocks.skip(i).take(perPage).toList();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => _cutPage(chunk, perPage),
    ));
  }
  return doc.save();
}

pw.Widget _infoRow(String a, String b) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: _rtl([_t(a, size: 8, bold: true), _t(b, size: 8)]),
    );

/// إشعارات درجات المادة: أربعة في الصفحة (2×2) بخطوط قص.
Future<Uint8List> buildNotices(List<NoticeData> data, String school, String year,
    String semester, String subject, List<String> monthHeads,
    double avgMax, double examMax) {
  pw.Widget block(NoticeData n) => pw.SizedBox(
        width: 262,
        child: _boxed(pw.Column(children: [
          _banner('إشعار درجات أعمال السنة - $semester',
              'الجمهورية اليمنية - وزارة التربية والتعليم'),
          pw.SizedBox(height: 5),
          _infoRow('اسم الطالب: ${n.name}', 'رقم القيد: ${n.regNo}'),
          _infoRow('الصف: ${n.className} - الفصل: ${n.section}', 'المادة: $subject'),
          pw.Divider(height: 8, thickness: 0.5),
          _grid(monthHeads, n.monthRows, <pw.TableColumnWidth>[
            const pw.FlexColumnWidth(1.5),
            for (var i = 1; i < monthHeads.length; i++) const pw.FlexColumnWidth(1),
          ], size: 7),
          pw.SizedBox(height: 6),
          _summaryBox([
            ['معدل الأشهر / ${nf(avgMax)}', n.avg],
            ['اختبار المنتصف / ${nf(examMax)}', n.exam],
            ['المجموع النهائي / ${nf(avgMax + examMax)}', n.total],
          ]),
          pw.SizedBox(height: 60),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: _rtl([
              _t('معلم المادة: ..........', size: 7),
              _t('توقيع ولي الأمر: ..........', size: 7),
            ]),
          ),
        ])),
      );
  return _cutDoc([for (final n in data) block(n)], 4);
}

/// إشعار فصلي لجميع المواد: [perPage] = 4 (2×2) أو 1.
Future<Uint8List> buildSemesterAll(List<SemAllData> data, String school,
    String year, String semester, double avgMax, double examMax, int perPage) {
  final w = perPage == 1 ? 520.0 : 262.0;
  final fs = perPage == 1 ? 10.0 : 7.0;
  pw.Widget block(SemAllData n) => pw.SizedBox(
        width: w,
        child: _boxed(pw.Column(children: [
          _banner('إشعار درجات الفصل - $semester',
              'الجمهورية اليمنية - وزارة التربية والتعليم${school.isEmpty ? '' : ' - $school'}'),
          pw.SizedBox(height: 5),
          _infoRow('اسم الطالب: ${n.name}', 'رقم القيد: ${n.regNo}'),
          _infoRow('الصف: ${n.className} - الفصل: ${n.section}', 'العام: $year'),
          pw.Divider(height: 8, thickness: 0.5),
          _grid(
            [
              'المادة',
              'معدل الأشهر (${nf(avgMax)})',
              'الاختبار (${nf(examMax)})',
              'المجموع (${nf(avgMax + examMax)})',
            ],
            n.rows,
            <pw.TableColumnWidth>[
              const pw.FlexColumnWidth(2), const pw.FlexColumnWidth(1),
              const pw.FlexColumnWidth(1), const pw.FlexColumnWidth(1),
            ],
            size: fs,
          ),
          pw.SizedBox(height: 6),
          _summaryBox([
            ['المجموع الكلي', n.totalText],
            ['النسبة المئوية', n.percentText],
          ]),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: _rtl([
              _t('رائد الفصل: ..........', size: 7),
              _t('توقيع ولي الأمر: ..........', size: 7),
            ]),
          ),
        ])),
      );
  return _cutDoc([for (final n in data) block(n)], perPage);
}

/// تقرير جدولي عام (قوائم، كشوف رصد، حضور...).
Future<Uint8List> buildTableReport(String title, List<String> heads,
    List<List<String>> rows, String school, String year,
    {bool landscape = false, List<double>? flex}) async {
  final doc = pw.Document(theme: await _theme());
  final w = <pw.TableColumnWidth>[
    for (var i = 0; i < heads.length; i++)
      pw.FlexColumnWidth(flex != null && i < flex.length ? flex[i] : 1),
  ];
  doc.addPage(pw.MultiPage(
    pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => pw.Column(children: [
      _header(school, year),
      pw.SizedBox(height: 10),
      _t(title, bold: true, size: 14),
      pw.SizedBox(height: 8),
    ]),
    footer: (_) => _signatures(),
    build: (_) => [_grid(heads, rows, w)],
  ));
  return doc.save();
}

/// بطاقة بيانات طالب.
Future<Uint8List> buildStudentCard(String name, List<List<String>> kv,
    String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => pw.Column(children: [
      _header(school, year),
      pw.SizedBox(height: 16),
      _t('بطاقة بيانات الطالب', bold: true, size: 16),
      pw.SizedBox(height: 4),
      _t(name, bold: true, size: 14),
      pw.SizedBox(height: 14),
      _grid(['البيان', 'القيمة'], kv,
          <pw.TableColumnWidth>[const pw.FlexColumnWidth(1), const pw.FlexColumnWidth(2)]),
      pw.Spacer(),
      _signatures(),
    ]),
  ));
  return doc.save();
}

// ===================== كشف اللجان التفصيلي (التوزيع المتقدم) =====================

class CommitteeDetail {
  final int no;
  final String genderLabel;
  final Map<String, int> classCounts;
  final int males, females;
  final List<List<String>> rows; // م، الاسم، الصف، الجنس، رقم القيد، رقم الجلوس
  CommitteeDetail(this.no, this.genderLabel, this.classCounts, this.males,
      this.females, this.rows);
}

/// صفحة ملخص + صفحة تفصيلية لكل لجنة بأسماء مرتبة أبجدياً.
Future<Uint8List> buildCommitteeDetails(
    List<CommitteeDetail> data, String school, String year) async {
  final doc = pw.Document(theme: await _theme());
  pw.Widget head(String title) => pw.Column(children: [
        _header(school, year),
        pw.SizedBox(height: 10),
        _t(title, bold: true, size: 14),
        pw.SizedBox(height: 8),
      ]);

  final sumHeads = ['اللجنة', 'النوع', 'ذكور', 'إناث', 'الإجمالي', 'الصفوف وأعداد طلابها'];
  final sumRows = [
    for (final d in data)
      [
        '${d.no}', d.genderLabel, '${d.males}', '${d.females}',
        '${d.males + d.females}',
        d.classCounts.entries.map((e) => '${e.key}: ${e.value}').join('، '),
      ]
  ];
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(28),
    header: (_) => head('ملخص توزيع الطلاب على اللجان'),
    footer: (_) => _signatures(),
    build: (_) => [
      _grid(sumHeads, sumRows, <pw.TableColumnWidth>[
        const pw.FlexColumnWidth(1), const pw.FlexColumnWidth(1.2),
        const pw.FlexColumnWidth(1), const pw.FlexColumnWidth(1),
        const pw.FlexColumnWidth(1.2), const pw.FlexColumnWidth(5),
      ], size: 9),
    ],
  ));

  const heads = ['م', 'اسم الطالب', 'الصف', 'الجنس', 'رقم القيد', 'رقم الجلوس'];
  for (final d in data) {
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => head('لجنة رقم ${d.no} - ${d.genderLabel}'),
      footer: (_) => _signatures(),
      build: (_) => [
        _t(
            'ذكور: ${d.males}   إناث: ${d.females}   الإجمالي: ${d.males + d.females}'
            '   |   ${d.classCounts.entries.map((e) => '${e.key}: ${e.value}').join('، ')}',
            size: 10),
        pw.SizedBox(height: 8),
        _grid(
          heads,
          d.rows,
          <pw.TableColumnWidth>[
            const pw.FlexColumnWidth(0.8), const pw.FlexColumnWidth(5),
            const pw.FlexColumnWidth(2.2), const pw.FlexColumnWidth(1.2),
            const pw.FlexColumnWidth(1.6), const pw.FlexColumnWidth(1.6),
          ],
          size: 10,
        ),
      ],
    ));
  }
  return doc.save();
}
