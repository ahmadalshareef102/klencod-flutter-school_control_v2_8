import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'arabic_text.dart';
import 'cert.dart';
import 'data_io.dart';
import 'dates.dart';
import 'db.dart';
import 'logic.dart';
import 'pdf_reports.dart';
import 'results_service.dart';
import 'semester_sheet.dart';
import 'widgets.dart';

enum RKind {
  semesterCerts, detailedSheet, notices, monthlySheet, yearWork, attendance, monthlyCerts, studentSemester,
  finalCerts, incomplete, sectionFull, noticesAll, gradeSheet, results,
  classList, semesterFull,
}

class RMeta {
  final RKind kind;
  final String title, desc;
  final IconData icon;
  final bool subject, month, semester, date, both, isNew;
  const RMeta(this.kind, this.title, this.desc, this.icon,
      {this.subject = false,
      this.month = false,
      this.semester = false,
      this.date = false,
      this.both = false,
      this.isNew = false});
}

const reportMetas = <RMeta>[
  RMeta(RKind.semesterCerts, 'شهادات نتيجة امتحان نهاية الفصل (طالب في الصفحة)',
      'شهادة رسمية بإطار زخرفي: المحصلة والاختبار والمجموع والتقدير والترتيب.',
      Icons.workspace_premium_outlined,
      semester: true),
  RMeta(RKind.detailedSheet, 'كشف درجات الطلاب الشامل المفصل (جميع الأشهر والواجبات والشفهي والتحريري والمحصلة)',
      'جدول واحد بكل الأشهر ومكوناتها والمحصلة والامتحان والنتيجة، بمعادلات Excel حية.',
      Icons.table_view_outlined,
      subject: true, semester: true),
  RMeta(RKind.notices, 'إشعارات درجات (4 طلاب في الصفحة)',
      'إشعار رسمي لولي الأمر: الدرجات الشهرية ومعدل الأشهر واختبار المنتصف والمجموع.',
      Icons.mail_outline,
      subject: true, semester: true),
  RMeta(RKind.monthlySheet, 'كشف الدرجات الشهري المعتمد',
      'مكونات الدرجة الشهرية والمجموع والمحوّلة لمادة وشهر.',
      Icons.calendar_view_month,
      subject: true, month: true),
  RMeta(RKind.yearWork, 'المحصلة الشاملة لأعمال السنة والاختبار',
      'درجات كل شهر ومعدل الأشهر واختبار الفصل والمجموع لمادة.',
      Icons.table_rows_outlined,
      subject: true, semester: true),
  RMeta(RKind.attendance, 'تقرير ملخص الحضور والمواظبة',
      'عدد أيام الحضور والغياب والتأخر والاستئذان ونسبة الحضور.',
      Icons.event_available_outlined,
      date: true),
  RMeta(RKind.monthlyCerts, 'تقرير الطالب الشهري (جميع المواد)',
      'شهادة شهرية لكل طالب بكل المواد ومكوناتها ونسبة الغياب (3 في الصفحة).',
      Icons.workspace_premium,
      month: true),
  RMeta(RKind.studentSemester, 'تقرير الطالب الفصلي (جميع المواد)',
      'تقرير فصلي كامل لكل طالب في صفحة: معدل الأشهر والاختبار والمجموع.',
      Icons.assignment_ind_outlined,
      semester: true),
  RMeta(RKind.finalCerts, 'شهادات النتيجة النهائية السنوية (طالب في الصفحة)',
      'شهادة العام الكامل بالفصلين: الدرجات والمجموع والتقدير والترتيب.',
      Icons.verified_outlined),
  RMeta(RKind.incomplete, 'كشف الدرجات غير المكتملة',
      'الطلاب والمواد التي لم تكتمل درجاتها بعد.', Icons.rule_folder_outlined,
      semester: true, both: true),
  RMeta(RKind.sectionFull, 'كشف الشعبة الكامل (جميع المواد × الشعبة)',
      'جدول واحد لكل المواد ومجموع الطالب ونسبته (فصل أو الفصلان معاً).',
      Icons.grid_on,
      semester: true, both: true),
  RMeta(RKind.noticesAll, 'إشعارات 2×2 لجميع المواد (تقرير فصلي)',
      'أربعة إشعارات فصلية في الصفحة بخطوط قص، لكل طالب كل المواد.',
      Icons.view_module_outlined,
      semester: true),
  RMeta(RKind.semesterFull, 'كشف رصد الدرجات الفصلي الكامل (جميع المواد)',
      'الكشف الرسمي: ترويسة وجميع المواد (محصلة/اختبار/إجمالي) والمجموع الكلي والنتيجة وتواقيع المعتمدين.',
      Icons.fact_check_outlined,
      semester: true, isNew: true),
  RMeta(RKind.gradeSheet, 'كشف رصد درجات مادة',
      'الكشف الرسمي لمادة واحدة: المحصلة والاختبار والإجمالي في فصل دراسي.', Icons.grading,
      subject: true, semester: true),
  RMeta(RKind.results, 'كشف النتائج مرتباً',
      'ترتيب الطلاب بالمجموع مع التقدير والنتيجة والمواد الراسب فيها.',
      Icons.leaderboard_outlined),
  RMeta(RKind.classList, 'قائمة أسماء الصف',
      'أسماء الطلاب مع أرقام القيد والجلوس وهاتف ولي الأمر.', Icons.groups_outlined),
];

class ReportData {
  final ExportTable table;
  final Future<Uint8List> Function() pdf;
  final int count;
  /// ملف xlsx غني (دمج ومعادلات) إن وُجد، وإلا يُستعمل الجدول البسيط.
  final Future<Uint8List> Function()? richXlsx;
  ReportData(this.table, this.pdf, this.count, {this.richXlsx});
}

/// خيارات الكشف المفصل (ترويسة وأعمدة ومستوى التفاصيل).
class DetailedOptions {
  bool full;
  String title, year, subject, teacher;
  bool regNo, exam, rating, signatures;
  DetailedOptions({
    this.full = true, this.title = '', this.year = '', this.subject = '',
    this.teacher = '', this.regNo = true, this.exam = true,
    this.rating = true, this.signatures = true,
  });
}

/// يصدّر تقريراً: xlsx الغني إن وُجد، أو الجدول العادي.
Future<void> shareReport(ReportData d,
    {required bool xlsx,
    ExportTable? table,
    bool withTitle = false,
    String school = '',
    String year = ''}) async {
  if (xlsx && d.richXlsx != null && table == null) {
    final safe = d.table.title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    await shareBytes('$safe.xlsx', await d.richXlsx!(),
        mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    return;
  }
  await exportTable(table ?? d.table,
      xlsx: xlsx, withTitle: withTitle, school: school, year: year);
}

Future<String> _subjectName(int? id) async {
  if (id == null) return '';
  final r = await (await Db.get()).query('subjects', where: 'id=?', whereArgs: [id]);
  return r.isEmpty ? '' : r.first['name'] as String;
}

class _Term {
  final List<List<String>> rows;
  final double? avg, exam;
  _Term(this.rows, this.avg, this.exam);
  double get total => (avg ?? 0) + (exam ?? 0);
  bool get has => avg != null || exam != null;
}

Future<(int, int)> _range(int sem) async {
  final f = int.tryParse(await Db.setting('sem${sem + 1}_from')) ?? 1;
  final t = int.tryParse(await Db.setting('sem${sem + 1}_to')) ?? f;
  return (f, t < f ? f : t);
}

/// درجات فصل لمادة: صفوف الأشهر ومعدلها المحوّل والاختبار.
Future<_Term> _term(int sid, int subjectId, int sem, Rules rules,
    MonthlyCfg cfg, (int, int) range, bool hijri) async {
  final d = await Db.get();
  final ms = await d.query('monthly',
      where: 'student_id=? AND subject_id=? AND month BETWEEN ? AND ?',
      whereArgs: [sid, subjectId, range.$1, range.$2]);
  final byMonth = {for (final m in ms) m['month'] as int: m};
  final g = await d.query('grades',
      where: 'student_id=? AND subject_id=?', whereArgs: [sid, subjectId]);
  final gr = g.isEmpty ? null : g.first;
  final rows = <List<String>>[];
  final convs = <double>[];
  for (var m = range.$1; m <= range.$2; m++) {
    final r = byMonth[m];
    String f(String k) {
      final v = r?[k] as num?;
      return v == null ? '-' : nf(v);
    }

    double? sum;
    if (r != null) {
      final vs = [r['hw'], r['att'], r['oral'], r['written']].map((e) => e as num?).toList();
      if (vs.any((e) => e != null)) sum = vs.fold<double>(0, (a, e) => a + (e ?? 0));
    }
    final conv = sum == null ? null : double.parse(cfg.convert(sum).toStringAsFixed(1));
    if (conv != null) convs.add(conv);
    rows.add([monthName(m, hijri), f('hw'), f('att'), f('oral'), f('written'),
      conv == null ? '-' : nf(conv)]);
  }
  final maxW = sem == 0 ? rules.maxW1 : rules.maxW2;
  double? avg;
  if (convs.isNotEmpty) {
    avg = double.parse(
        (convs.reduce((a, b) => a + b) / convs.length / cfg.convertTo * maxW)
            .toStringAsFixed(1));
  } else {
    avg = (gr?[sem == 0 ? 't1_work' : 't2_work'] as num?)?.toDouble();
  }
  final exam = (gr?[sem == 0 ? 't1_exam' : 't2_exam'] as num?)?.toDouble();
  return _Term(rows, avg, exam);
}

String _semName(int sem) =>
    sem == 0 ? 'الفصل الدراسي الأول' : sem == 1 ? 'الفصل الدراسي الثاني' : 'الفصلان معاً';

String _fnum(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
double _r2(double v) => double.parse(v.toStringAsFixed(2));

Future<ReportData> _detailedReport(Scope sc, int sem, List<DbRow> students, String cls,
    String school, String yearSetting, bool hijri, DetailedOptions o) async {
  if (sc.subjectId == null) throw StateError('اختر المادة أولاً');
  final d = await Db.get();
  final rules = await Rules.load();
  final cfg = await MonthlyCfg.load();
  final range = await _range(sem);
  final subject = o.subject.isNotEmpty ? o.subject : await _subjectName(sc.subjectId);
  final teacher = o.teacher.isNotEmpty ? o.teacher : await Db.setting('teacher');
  final yearTxt = o.year.isNotEmpty ? o.year : yearSetting;
  final semLabel = _semName(sem);
  final title = o.title.isNotEmpty
      ? o.title
      : 'درجات أعمال السنة لـ$semLabel للعام الدراسي $yearTxt';
  final maxW = sem == 0 ? rules.maxW1 : rules.maxW2;
  final maxE = sem == 0 ? rules.maxE1 : rules.maxE2;
  final ms = [for (var m = range.$1; m <= range.$2; m++) m];
  final factor = cfg.total / (cfg.convertTo == 0 ? 1 : cfg.convertTo);
  final fs = _fnum(factor);

  // ---- بيانات الطلاب ----
  final recs = <({DbRow st, Map<int, DbRow> byMonth, DbRow? g})>[];
  for (final st in students) {
    final mr = await d.query('monthly',
        where: 'student_id=? AND subject_id=? AND month BETWEEN ? AND ?',
        whereArgs: [st['id'], sc.subjectId, range.$1, range.$2]);
    final g = await d.query('grades',
        where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sc.subjectId]);
    recs.add((st: st, byMonth: {for (final m in mr) m['month'] as int: m}, g: g.isEmpty ? null : g.first));
  }

  // ---- تخطيط الأعمدة ----
  var col = 0;
  final cNo = col++;
  final cReg = o.regNo ? col++ : -1;
  final cName = col++;
  final cCls = col++;
  final cSec = col++;
  final infoLast = col - 1;
  final per = o.full ? 6 : 2;
  final monthStart = col;
  col += ms.length * per;
  final cSum = col++;
  final cWork = col++;
  final cExam = o.exam ? col++ : -1;
  final cFinal = col++;
  final cRate = o.rating ? col++ : -1;
  final cPct = o.rating ? col++ : -1;
  final cNote = col++;
  final nc = col;
  final r0 = 5, n = recs.length;
  final avgRow = r0 + n, sigRow = r0 + n + 2;
  final rows = <List<XCell?>>[
    for (var i = 0; i < sigRow + 1; i++) List<XCell?>.filled(nc, null)
  ];
  final merges = <String>[];
  void merge(int r, int c1, int c2) {
    if (c2 > c1) merges.add('${colLetter(c1)}${r + 1}:${colLetter(c2)}${r + 1}');
  }

  void put(int r, int c, XCell cell) => rows[r][c] = cell;
  void fillStyle(int r, int c1, int c2, int style) {
    for (var c = c1; c <= c2; c++) {
      rows[r][c] ??= XCell.text('', style);
    }
  }

  // ---- الترويسة ----
  final rightW = (nc ~/ 4).clamp(3, 8).toInt();
  put(0, 0, const XCell.text('الجمهورية اليمنية\nوزارة التربية والتعليم', 8));
  fillStyle(0, 0, infoLast, 8);
  merge(0, 0, infoLast);
  put(0, infoLast + 1, XCell.text(school.isEmpty ? 'مكتب التربية والتعليم' : school, 8));
  fillStyle(0, infoLast + 1, nc - rightW - 1, 8);
  merge(0, infoLast + 1, nc - rightW - 1);
  put(0, nc - rightW, XCell.text('العام الدراسي: $yearTxt\n$semLabel', 8));
  fillStyle(0, nc - rightW, nc - 1, 8);
  merge(0, nc - rightW, nc - 1);

  put(1, 0, XCell.text(title, 4));
  merge(1, 0, nc - 1);

  final q = nc ~/ 4;
  final seg = [0, q, 2 * q, 3 * q, nc];
  final infoTexts = [
    'المادة: $subject',
    'الصف: $cls    الشعبة: ${sc.section ?? 'جميع الشعب'}',
    'معلم المادة: ${teacher.isEmpty ? '.................' : teacher}',
    'إجمالي الطلاب: $n طالب',
  ];
  for (var i = 0; i < 4; i++) {
    put(2, seg[i], XCell.text(infoTexts[i], 8));
    fillStyle(2, seg[i], seg[i + 1] - 1, 8);
    merge(2, seg[i], seg[i + 1] - 1);
  }

  // ---- ترويسة المجموعات والأعمدة ----
  put(3, 0, const XCell.text('بيانات الطالب', 6));
  fillStyle(3, 0, infoLast, 6);
  merge(3, 0, infoLast);
  for (var i = 0; i < ms.length; i++) {
    final b = monthStart + i * per;
    put(3, b, XCell.text(monthName(ms[i], hijri), 6));
    fillStyle(3, b, b + per - 1, 6);
    merge(3, b, b + per - 1);
  }
  put(3, cSum, const XCell.text('النتيجة النهائية', 6));
  fillStyle(3, cSum, nc - 1, 6);
  merge(3, cSum, nc - 1);

  put(4, cNo, const XCell.text('الرقم', 2));
  if (cReg >= 0) put(4, cReg, const XCell.text('رقم القيد', 2));
  put(4, cName, const XCell.text('اسم الطالب', 2));
  put(4, cCls, const XCell.text('الصف', 2));
  put(4, cSec, const XCell.text('الشعبة', 2));
  final compHeads = [
    for (var k = 0; k < 4; k++) '${cfg.labels[k]} (${nf(cfg.maxes[k])})'
  ];
  for (var i = 0; i < ms.length; i++) {
    final b = monthStart + i * per;
    var c = b;
    if (o.full) {
      for (final h in compHeads) {
        put(4, c++, XCell.text(h, 2));
      }
    }
    put(4, c++, XCell.text('المجموع (${nf(cfg.total)})', 2));
    put(4, c, XCell.text('المحصلة (${nf(cfg.convertTo)})', 2));
  }
  put(4, cSum, const XCell.text('مجموع المحصلات', 2));
  put(4, cWork, XCell.text('المحصلة (${nf(maxW)})', 2));
  if (cExam >= 0) put(4, cExam, XCell.text('الامتحان (${nf(maxE)})', 2));
  put(4, cFinal, XCell.text('النتيجة النهائية (${nf(maxW + (o.exam ? maxE : 0))})', 2));
  if (cRate >= 0) {
    put(4, cRate, const XCell.text('التقدير', 2));
    put(4, cPct, const XCell.text('النسبة %', 2));
  }
  put(4, cNote, const XCell.text('ملاحظات', 2));

  // ---- صفوف الطلاب ----
  final totalMax = maxW + (o.exam ? maxE : 0);
  String rateOf(double pct) => rules.rating(pct);
  final avgCols = <int, List<double>>{};
  void collect(int c, double v) => (avgCols[c] ??= []).add(v);
  final flat = <List<String>>[];
  final pdfRows = <List<String>>[];

  for (var i = 0; i < n; i++) {
    final r = r0 + i, rn = r + 1;
    final st = recs[i].st, byMonth = recs[i].byMonth, g = recs[i].g;
    put(r, cNo, XCell.num(i + 1.0));
    if (cReg >= 0) put(r, cReg, XCell.text('${st['reg_no'] ?? ''}'));
    put(r, cName, XCell.text('${st['name']}', 5));
    put(r, cCls, XCell.text(cls));
    put(r, cSec, XCell.text('${st['section'] ?? ''}'));
    final convRefs = <String>[];
    final convVals = <double>[];
    final flatMonth = <String>[];
    final pdfMonth = <String>[];
    for (var k = 0; k < ms.length; k++) {
      final b = monthStart + k * per;
      final m = byMonth[ms[k]];
      final vals = [
        for (final key in ['hw', 'att', 'oral', 'written']) (m?[key] as num?)?.toDouble() ?? 0.0
      ];
      final total = vals.fold<double>(0, (a, e) => a + e);
      final conv = _r2(total / factor);
      var c = b;
      if (o.full) {
        for (final v in vals) {
          put(r, c++, XCell.num(v));
        }
        put(r, c, XCell.formula('SUM(${colLetter(b)}$rn:${colLetter(b + 3)}$rn)', n: total));
        c++;
        flatMonth.addAll([...vals.map(nf), nf(total)]);
      } else {
        put(r, c++, XCell.num(total));
        flatMonth.add(nf(total));
      }
      final totRef = '${colLetter(c - 1)}$rn';
      put(r, c, XCell.formula('ROUND($totRef/$fs,2)', n: conv));
      flatMonth.add(nf(conv));
      pdfMonth.add(nf(conv));
      convRefs.add('${colLetter(c)}$rn');
      convVals.add(conv);
      collect(c, conv);
      collect(c - 1, total);
    }
    final sumConv = convVals.fold<double>(0, (a, e) => a + e);
    put(r, cSum, XCell.formula('SUM(${convRefs.join(',')})', n: sumConv));
    collect(cSum, sumConv);
    final pos = convVals.where((v) => v > 0).toList();
    final avg = pos.isEmpty ? 0.0 : pos.reduce((a, b) => a + b) / pos.length;
    final scale = cfg.convertTo == maxW ? '' : '/${_fnum(cfg.convertTo)}*${_fnum(maxW)}';
    final work = _r2(avg * (cfg.convertTo == maxW ? 1 : maxW / cfg.convertTo));
    final posSum = convRefs.map((x) => 'IF($x>0,$x,0)').join('+');
    final posCnt = convRefs.map((x) => 'IF($x>0,1,0)').join('+');
    put(r, cWork, XCell.formula(
        'IFERROR(ROUND(($posSum)/(MAX(1,$posCnt))$scale,2),0)', n: work));
    collect(cWork, work);
    final exam = (g?[sem == 0 ? 't1_exam' : 't2_exam'] as num?)?.toDouble() ?? 0.0;
    if (cExam >= 0) {
      put(r, cExam, XCell.num(exam));
      collect(cExam, exam);
    }
    final fin = work + (o.exam ? exam : 0);
    put(r, cFinal, XCell.formula(
        o.exam ? '${colLetter(cWork)}$rn+${colLetter(cExam)}$rn' : '${colLetter(cWork)}$rn', n: fin));
    collect(cFinal, fin);
    final pct = totalMax == 0 ? 0.0 : fin / totalMax * 100;
    final rate = fin == 0 ? '-' : rateOf(pct);
    if (cRate >= 0) {
      final f = '${colLetter(cFinal)}$rn';
      final p = '$f/${_fnum(totalMax)}*100';
      put(r, cRate, XCell.formula(
          'IF($f=0,"-",IF($p>=${_fnum(rules.excellent)},"ممتاز",IF($p>=${_fnum(rules.veryGood)},"جيد جداً",IF($p>=${_fnum(rules.good)},"جيد",IF($p>=${_fnum(rules.ok)},"مقبول","ضعيف")))))',
          str: rate));
      put(r, cPct, XCell.formula('IFERROR(ROUND($p,1),0)', n: double.parse(pct.toStringAsFixed(1))));
      collect(cPct, pct);
    }
    put(r, cNote, XCell.text('${st['notes'] ?? ''}', 5));
    flat.add([
      '${i + 1}', if (cReg >= 0) '${st['reg_no'] ?? ''}', '${st['name']}', cls,
      '${st['section'] ?? ''}', ...flatMonth, nf(sumConv), nf(work),
      if (cExam >= 0) nf(exam), nf(fin),
      if (cRate >= 0) rate, if (cRate >= 0) pct.toStringAsFixed(1), '${st['notes'] ?? ''}',
    ]);
    pdfRows.add([
      '${i + 1}', '${st['name']}', ...pdfMonth, nf(work),
      if (cExam >= 0) nf(exam), nf(fin), if (cRate >= 0) rate,
    ]);
  }

  // ---- صف المتوسط ----
  put(avgRow, 0, const XCell.text('المتوسط العام للدرجات', 9));
  fillStyle(avgRow, 0, infoLast, 9);
  merge(avgRow, 0, infoLast);
  for (final e in avgCols.entries) {
    final c = e.key;
    final v = e.value;
    final mean = v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;
    put(avgRow, c, XCell.formula(
        'ROUND(AVERAGE(${colLetter(c)}${r0 + 1}:${colLetter(c)}$avgRow),2)',
        n: _r2(mean), s: 9));
  }
  if (cRate >= 0) put(avgRow, cRate, XCell.text('عدد الطلاب: $n', 9));
  fillStyle(avgRow, monthStart, nc - 1, 9);

  // ---- التواقيع ----
  if (o.signatures) {
    final seg3 = [0, nc ~/ 3, 2 * (nc ~/ 3), nc];
    final sig = [
      'معلم المادة: ${teacher.isEmpty ? '.....................' : teacher}\nالتوقيع: .....................',
      'المرشد الطلابي: .....................\nالتوقيع: .....................',
      'مدير المدرسة: .....................\nالختم الرسمي: .....................',
    ];
    for (var i = 0; i < 3; i++) {
      put(sigRow, seg3[i], XCell.text(sig[i], 7));
      fillStyle(sigRow, seg3[i], seg3[i + 1] - 1, 7);
      merge(sigRow, seg3[i], seg3[i + 1] - 1);
    }
  } else {
    rows.removeLast();
  }

  final widths = <int, double>{
    cNo: 5, if (cReg >= 0) cReg: 12, cName: 24, cCls: 14, cSec: 8,
    for (var c = monthStart; c < cSum; c++) c: 9,
    cSum: 11, cWork: 11, if (cExam >= 0) cExam: 10, cFinal: 12,
    if (cRate >= 0) cRate: 10, if (cRate >= 0) cPct: 9, cNote: 20,
  };
  final heights = <int, double>{0: 40, 1: 28, 2: 22, 3: 20, 4: 38, if (o.signatures) sigRow: 50};

  final heads = [
    'الرقم', if (cReg >= 0) 'رقم القيد', 'اسم الطالب', 'الصف', 'الشعبة',
    for (final m in ms) ...[
      if (o.full) for (final h in compHeads) '${monthName(m, hijri)} - $h',
      '${monthName(m, hijri)} - المجموع', '${monthName(m, hijri)} - المحصلة',
    ],
    'مجموع المحصلات', 'المحصلة', if (cExam >= 0) 'الامتحان', 'النتيجة النهائية',
    if (cRate >= 0) 'التقدير', if (cRate >= 0) 'النسبة %', 'ملاحظات',
  ];
  final pdfHeads = [
    'م', 'اسم الطالب', for (final m in ms) monthName(m, hijri), 'المحصلة',
    if (cExam >= 0) 'الامتحان', 'النتيجة', if (cRate >= 0) 'التقدير',
  ];
  final fullTitle = '$title - $subject - $cls';
  return ReportData(
    ExportTable(fullTitle, heads, flat),
    () => buildTableReport(fullTitle, pdfHeads, pdfRows, school, yearTxt,
        landscape: true, flex: [0.7, 4, for (var i = 2; i < pdfHeads.length; i++) 1.2]),
    n,
    richXlsx: () async => buildXlsxSheet('كشف الدرجات الشامل المفصل', rows,
        merges: merges, colWidths: widths, rowHeights: heights),
  );
}

class _Calc {
  final List<List<String>> rows = [];
  double a = 0, b = 0, c = 0;
  int count = 0;
}

/// شهادات النتيجة بتصميم الإطار: [sem] 0/1 فصل، 2 سنوية.
Future<ReportData> _certReport(Scope sc, int sem, int? onlyStudent, String year) async {
  final rules = await Rules.load();
  final d = await Db.get();
  final cls = await Db.className(sc.classId);
  final subjects = await Db.subjectsOf(sc.classId);
  final all = await Db.students(classId: sc.classId, section: sc.section);
  final style = await loadCertStyle();
  final subjMax = sem == 2
      ? rules.subjectMax
      : sem == 0
          ? rules.maxW1 + rules.maxE1
          : rules.maxW2 + rules.maxE2;
  final calc = <int, _Calc>{};
  for (final st in all) {
    final k = _Calc();
    for (final sub in subjects) {
      final g = await d.query('grades',
          where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sub['id']]);
      double? n(String f) => g.isEmpty ? null : (g.first[f] as num?)?.toDouble();
      double? a, b;
      if (sem == 0) {
        a = n('t1_work');
        b = n('t1_exam');
      } else if (sem == 1) {
        a = n('t2_work');
        b = n('t2_exam');
      } else {
        final x = [n('t1_work'), n('t1_exam')], y = [n('t2_work'), n('t2_exam')];
        a = x.every((e) => e == null) ? null : x.fold<double>(0, (p, e) => p + (e ?? 0));
        b = y.every((e) => e == null) ? null : y.fold<double>(0, (p, e) => p + (e ?? 0));
      }
      final has = a != null || b != null;
      final c = (a ?? 0) + (b ?? 0);
      if (has) {
        k.a += a ?? 0;
        k.b += b ?? 0;
        k.c += c;
        k.count++;
      }
      k.rows.add(['${sub['name']}', nf(a), nf(b), has ? nf(c) : '',
        has ? rules.rating(subjMax == 0 ? 0 : c / subjMax * 100) : '']);
    }
    calc[st['id'] as int] = k;
  }
  final ranked = [for (final e in calc.entries) if (e.value.count > 0) e]
    ..sort((x, y) => y.value.c.compareTo(x.value.c));
  final ranks = competitionRanks([for (final e in ranked) e.value.c]);
  final rankOf = {for (var i = 0; i < ranked.length; i++) ranked[i].key: ranks[i]};

  final title = sem == 0
      ? 'نتيجة امتحان نهاية الفصل الدراسي الأول'
      : sem == 1
          ? 'نتيجة امتحان نهاية الفصل الدراسي الثاني'
          : 'نتيجة امتحان نهاية العام الدراسي';
  final heads = sem == 2
      ? ['الفصل الأول', 'الفصل الثاني', 'المجموع', 'التقدير']
      : ['المحصلة', 'الاختبار', 'المجموع', 'التقدير'];
  final data = <ResultCertData>[];
  final flat = <List<String>>[];
  for (final st in all) {
    final id = st['id'] as int;
    if (onlyStudent != null && id != onlyStudent) continue;
    final k = calc[id]!;
    final max = k.count * subjMax;
    final pct = max == 0 ? 0.0 : k.c / max * 100;
    final rank = rankOf[id];
    for (final r in k.rows) {
      flat.add(['${st['name']}', ...r]);
    }
    data.add(ResultCertData(
      name: '${st['name']}',
      regNo: '${st['reg_no'] ?? ''}',
      seat: '${st['seat_no'] ?? ''}',
      className: cls,
      section: '${st['section'] ?? ''}',
      address: '${st['address'] ?? ''}',
      photoPath: '${st['photo'] ?? ''}',
      heads: heads,
      rows: k.rows,
      totals: k.count == 0
          ? ['', '', '', '']
          : [nf(k.a), nf(k.b), nf(k.c), rules.rating(pct)],
      totalWords: k.count == 0 ? '' : arabicWords(k.c),
      rankText: rank == null ? '-' : ordinalAr(rank),
      percent: max == 0 ? '-' : pct.toStringAsFixed(1),
    ));
  }
  return ReportData(
      ExportTable('$title - $cls', ['الاسم', 'المادة', heads[0], heads[1], heads[2], heads[3]], flat),
      () => buildResultCerts(data, style, year, title),
      data.length);
}

/// كشف رصد الدرجات الفصلي بالشكل الرسمي (مادة واحدة أو كل مواد الصف).
Future<ReportData> _semesterSheetReport(Scope sc, int semester,
    List<Map<String, Object?>> students, String cls, String year,
    {required bool all}) async {
  final rules = await Rules.load();
  final sem = semester == 1 ? 1 : 0;
  final t1 = sem == 0;
  final wk = t1 ? 't1_work' : 't2_work', ex = t1 ? 't1_exam' : 't2_exam';
  final mw = t1 ? rules.maxW1 : rules.maxW2, me = t1 ? rules.maxE1 : rules.maxE2;
  final allSubs = await Db.subjectsOf(sc.classId);
  final chosen = all
      ? allSubs
      : allSubs.where((s) => s['id'] == sc.subjectId).toList();
  if (chosen.isEmpty) throw StateError('اختر المادة أولاً');
  final d = await Db.get();
  final subs = [for (final s in chosen) SheetSubject('${s['name']}', mw, me)];
  final minPass = (mw + me) * rules.passPercent / 100;
  final rows = <SheetRow>[];
  for (final st in students) {
    final w = <double?>[], e = <double?>[];
    var any = false;
    var failed = 0;
    for (final sub in chosen) {
      final g = await d.query('grades',
          where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sub['id']]);
      final m = g.isEmpty ? <String, Object?>{} : g.first;
      final a = (m[wk] as num?)?.toDouble(), b = (m[ex] as num?)?.toDouble();
      w.add(a);
      e.add(b);
      if (a != null || b != null) any = true;
      if ((a ?? 0) + (b ?? 0) < minPass) failed++;
    }
    final result = !any
        ? 'غائب'
        : failed == 0
            ? 'ناجح'
            : (!all || failed > rules.maxFailedSecondRound)
                ? 'راسب'
                : 'دور ثانٍ';
    rows.add(SheetRow('${st['name'] ?? ''}', '${st['gender'] ?? ''}', w, e, result));
  }
  final genders = {for (final s in students) '${s['gender'] ?? ''}'};
  final genderLabel = genders.isEmpty
      ? ''
      : genders.length > 1
          ? 'مختلط'
          : (genders.first == 'أنثى' ? 'إناث' : 'ذكور');
  final title = 'كشف رصد درجات المحصلة وامتحانات نهاية ${_semName(sem)} '
      'للعام الدراسي ($year)${all ? '' : ' - مادة ${chosen.first['name']}'}';
  final info = SheetInfo(
    title: title,
    school: await Db.setting('school'),
    className: cls,
    section: sc.section ?? '',
    genderLabel: genderLabel,
    office: await Db.setting('cert_office'),
    admin: await Db.setting('cert_admin'),
    sigNames: [
      await Db.setting('cert_principal'),
      await Db.setting('sig_exam_dir'),
      await Db.setting('sig_office_dir'),
      await Db.setting('sig_exam_gov'),
      await Db.setting('sig_office_gov'),
    ],
    emblem: await readImageBytes(await Db.setting('cert_emblem')),
  );
  final heads = [
    'م', 'اسم الطالب', 'الجنس',
    for (final s in subs) ...[
      '${s.name} - المحصلة (${nf(s.maxW)})',
      '${s.name} - الاختبار (${nf(s.maxE)})',
      '${s.name} - الإجمالي (${nf(s.maxW + s.maxE)})',
    ],
    'المجموع الكلي', 'النتيجة النهائية',
  ];
  final flat = <List<String>>[
    for (var i = 0; i < rows.length; i++)
      [
        '${i + 1}', rows[i].name, rows[i].gender,
        for (var j = 0; j < subs.length; j++) ...[
          nf(rows[i].w[j]), nf(rows[i].e[j]), nf(rows[i].sub(j)),
        ],
        nf(rows[i].total), rows[i].result,
      ]
  ];
  return ReportData(
    ExportTable('كشف رصد ${all ? 'جميع المواد' : chosen.first['name']} - ${_semName(sem)} - $cls',
        heads, flat),
    () => buildSemesterSheetPdf(info, subs, rows),
    rows.length,
    richXlsx: () async => buildSemesterSheetXlsx(info, subs, rows),
  );
}

Future<ReportData> buildReport(RKind kind, Scope sc,
    {int semester = 0, DateTime? date, int? onlyStudent, DetailedOptions? detailed}) async {
  final school = await Db.setting('school');
  final year = await Db.setting('year');
  final cls = await Db.className(sc.classId);
  final hijri = AppState.hijri.value;
  final students = (await Db.students(classId: sc.classId, section: sc.section))
      .where((s) => onlyStudent == null || s['id'] == onlyStudent)
      .toList();
  final d = await Db.get();

  switch (kind) {
    case RKind.classList:
      final heads = ['م', 'الاسم', 'رقم القيد', 'رقم الجلوس', 'الجنس', 'الشعبة', 'هاتف ولي الأمر'];
      final rows = <List<String>>[];
      for (var i = 0; i < students.length; i++) {
        final s = students[i];
        rows.add([
          '${i + 1}', '${s['name'] ?? ''}', '${s['reg_no'] ?? ''}',
          '${s['seat_no'] ?? ''}', '${s['gender'] ?? ''}',
          '${s['section'] ?? ''}', '${s['phone'] ?? ''}',
        ]);
      }
      final title = 'قائمة طلاب $cls';
      return ReportData(
          ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year,
              flex: [1, 5, 2, 2, 1.5, 1.5, 3]),
          rows.length);

    case RKind.results:
      final res = await classResults(sc.classId, section: sc.section);
      final heads = ['الترتيب', 'الاسم', 'رقم الجلوس', 'المجموع', 'النسبة', 'التقدير', 'النتيجة', 'المواد الراسب فيها'];
      final rows = [
        for (final r in res)
          [
            '${r.rank ?? '-'}', '${r.student['name']}', '${r.student['seat_no'] ?? '-'}',
            nf(r.result.total), '${r.result.percent.toStringAsFixed(1)}%',
            r.result.rating, r.result.status, r.result.failed.join('، '),
          ]
      ];
      return ReportData(ExportTable('نتائج $cls', heads, rows),
          () => buildResultSheet(cls, rows, school, year), rows.length);

    case RKind.semesterFull:
      return _semesterSheetReport(sc, semester, students, cls, year, all: true);

    case RKind.gradeSheet:
      return _semesterSheetReport(sc, semester, students, cls, year, all: false);

    case RKind.detailedSheet:
      return _detailedReport(sc, semester == 1 ? 1 : 0, students, cls, school, year, hijri,
          detailed ?? DetailedOptions());

    case RKind.notices:
      if (sc.subjectId == null) throw StateError('اختر المادة أولاً');
      final rules = await Rules.load();
      final cfg = await MonthlyCfg.load();
      final sem = semester == 1 ? 1 : 0;
      final range = await _range(sem);
      final subject = await _subjectName(sc.subjectId);
      final semLabel = _semName(sem);
      final avgMax = sem == 0 ? rules.maxW1 : rules.maxW2;
      final examMax = sem == 0 ? rules.maxE1 : rules.maxE2;
      final data = <NoticeData>[];
      for (final st in students) {
        final t = await _term(st['id'] as int, sc.subjectId!, sem, rules, cfg, range, hijri);
        data.add(NoticeData('${st['name']}', '${st['reg_no'] ?? ''}', cls,
            '${st['section'] ?? ''}', t.rows, nf(t.avg ?? 0), nf(t.exam ?? 0), nf(t.total)));
      }
      final monthHeads = ['الشهر', ...cfg.labels, 'المحصلة'];
      final table = ExportTable('إشعارات $subject - $semLabel',
          ['الاسم', 'رقم القيد', 'معدل الأشهر', 'الاختبار', 'المجموع'],
          [for (final n in data) [n.name, n.regNo, n.avg, n.exam, n.total]]);
      return ReportData(
          table,
          () => buildNotices(data, school, year, semLabel, subject, monthHeads, avgMax, examMax),
          data.length);

    case RKind.noticesAll:
    case RKind.studentSemester:
      final rules = await Rules.load();
      final cfg = await MonthlyCfg.load();
      final sem = semester == 1 ? 1 : 0;
      final range = await _range(sem);
      final subjects = await Db.subjectsOf(sc.classId);
      final avgMax = sem == 0 ? rules.maxW1 : rules.maxW2;
      final examMax = sem == 0 ? rules.maxE1 : rules.maxE2;
      final semLabel = _semName(sem);
      final data = <SemAllData>[];
      final flat = <List<String>>[];
      for (final st in students) {
        final rows = <List<String>>[];
        var total = 0.0;
        var count = 0;
        for (final sub in subjects) {
          final t = await _term(st['id'] as int, sub['id'] as int, sem, rules, cfg, range, hijri);
          rows.add(['${sub['name']}', t.avg == null ? '' : nf(t.avg), t.exam == null ? '' : nf(t.exam), t.has ? nf(t.total) : '']);
          flat.add(['${st['name']}', '${sub['name']}', t.avg == null ? '' : nf(t.avg), t.exam == null ? '' : nf(t.exam), t.has ? nf(t.total) : '']);
          if (t.has) {
            total += t.total;
            count++;
          }
        }
        final max = count * (avgMax + examMax);
        data.add(SemAllData('${st['name']}', '${st['reg_no'] ?? ''}', cls, '${st['section'] ?? ''}', rows,
            '${nf(total)} / ${nf(max)}', max == 0 ? '-' : '${(total / max * 100).toStringAsFixed(1)}%'));
      }
      return ReportData(
          ExportTable('تقرير فصلي - $semLabel - $cls',
              ['الاسم', 'المادة', 'معدل الأشهر', 'الاختبار', 'المجموع'], flat),
          () => buildSemesterAll(data, school, year, semLabel, avgMax, examMax,
              kind == RKind.noticesAll ? 4 : 1),
          data.length);

    case RKind.yearWork:
      if (sc.subjectId == null) throw StateError('اختر المادة أولاً');
      final rules = await Rules.load();
      final cfg = await MonthlyCfg.load();
      final sem = semester == 1 ? 1 : 0;
      final range = await _range(sem);
      final subject = await _subjectName(sc.subjectId);
      final avgMax = sem == 0 ? rules.maxW1 : rules.maxW2;
      final examMax = sem == 0 ? rules.maxE1 : rules.maxE2;
      final heads = [
        'م', 'الاسم',
        for (var m = range.$1; m <= range.$2; m++) monthName(m, hijri),
        'معدل الأشهر (${nf(avgMax)})', 'الاختبار (${nf(examMax)})',
        'المجموع (${nf(avgMax + examMax)})',
      ];
      final rows = <List<String>>[];
      for (var i = 0; i < students.length; i++) {
        final st = students[i];
        final t = await _term(st['id'] as int, sc.subjectId!, sem, rules, cfg, range, hijri);
        rows.add(['${i + 1}', '${st['name']}', for (final r in t.rows) r.last,
          t.avg == null ? '' : nf(t.avg), t.exam == null ? '' : nf(t.exam), t.has ? nf(t.total) : '']);
      }
      final title = 'المحصلة الشاملة - $subject - ${_semName(sem)} - $cls';
      return ReportData(ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year, landscape: true,
              flex: [0.8, 4, for (var i = 2; i < heads.length; i++) 1.4]),
          rows.length);

    case RKind.incomplete:
      final subjects = await Db.subjectsOf(sc.classId);
      final parts = <(String, String)>[
        if (semester != 1) ('t1_work', 'محصلة 1'),
        if (semester != 1) ('t1_exam', 'اختبار 1'),
        if (semester != 0) ('t2_work', 'محصلة 2'),
        if (semester != 0) ('t2_exam', 'اختبار 2'),
      ];
      final heads = ['م', 'الطالب', 'المادة', 'الناقص'];
      final rows = <List<String>>[];
      for (final st in students) {
        for (final sub in subjects) {
          final g = await d.query('grades',
              where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sub['id']]);
          final gr = g.isEmpty ? null : g.first;
          final miss = [for (final p in parts) if (gr == null || gr[p.$1] == null) p.$2];
          if (miss.isNotEmpty) {
            rows.add(['${rows.length + 1}', '${st['name']}', '${sub['name']}', miss.join('، ')]);
          }
        }
      }
      final title = 'كشف الدرجات غير المكتملة - ${_semName(semester)} - $cls';
      return ReportData(ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year, flex: [1, 4, 3, 4]),
          rows.length);

    case RKind.sectionFull:
      final rules = await Rules.load();
      final subjects = await Db.subjectsOf(sc.classId);
      final perSubject = semester == 2
          ? rules.subjectMax
          : semester == 0
              ? rules.maxW1 + rules.maxE1
              : rules.maxW2 + rules.maxE2;
      final heads = [
        'م', 'الاسم', for (final s in subjects) '${s['name']}', 'المجموع', 'النسبة',
      ];
      final rows = <List<String>>[];
      for (var i = 0; i < students.length; i++) {
        final st = students[i];
        var total = 0.0;
        var count = 0;
        final cells = <String>[];
        for (final sub in subjects) {
          final g = await d.query('grades',
              where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sub['id']]);
          double? n(String k) => g.isEmpty ? null : (g.first[k] as num?)?.toDouble();
          final parts = semester == 0
              ? [n('t1_work'), n('t1_exam')]
              : semester == 1
                  ? [n('t2_work'), n('t2_exam')]
                  : [n('t1_work'), n('t1_exam'), n('t2_work'), n('t2_exam')];
          if (parts.every((e) => e == null)) {
            cells.add('');
          } else {
            final v = parts.fold<double>(0, (a, e) => a + (e ?? 0));
            cells.add(nf(v));
            total += v;
            count++;
          }
        }
        final max = count * perSubject;
        rows.add(['${i + 1}', '${st['name']}', ...cells, count == 0 ? '' : nf(total),
          max == 0 ? '' : '${(total / max * 100).toStringAsFixed(1)}%']);
      }
      final title = 'كشف الشعبة الكامل - ${_semName(semester)} - $cls';
      return ReportData(ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year, landscape: true,
              flex: [0.7, 4, for (var i = 2; i < heads.length; i++) 1.3]),
          rows.length);

    case RKind.monthlySheet:
      if (sc.subjectId == null) throw StateError('اختر المادة أولاً');
      final cfg = await MonthlyCfg.load();
      final subject = await _subjectName(sc.subjectId);
      final label = monthName(sc.month, hijri);
      final rows0 = await Db.monthlyRows(sc.classId, sc.section, sc.subjectId!, sc.month);
      final heads = [
        'م', 'الاسم', 'رقم القيد',
        for (var i = 0; i < 4; i++) '${cfg.labels[i]} (${nf(cfg.maxes[i])})',
        'المجموع (${nf(cfg.total)})', 'المحوّلة (${nf(cfg.convertTo)})',
      ];
      final rows = <List<String>>[];
      for (var i = 0; i < rows0.length; i++) {
        final r = rows0[i];
        final v = [r['hw'], r['att'], r['oral'], r['written']].map((e) => e as num?).toList();
        final any = v.any((e) => e != null);
        final total = v.fold<double>(0, (a, e) => a + (e ?? 0));
        rows.add(['${i + 1}', '${r['name']}', '${r['reg_no'] ?? ''}',
          for (final e in v) nf(e), any ? nf(total) : '', any ? nf(cfg.convert(total)) : '']);
      }
      final title = 'كشف الدرجات الشهرية - $subject - شهر $label - $cls';
      return ReportData(ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year,
              flex: [1, 5, 2, 2, 2, 2, 2, 2, 2]),
          rows.length);

    case RKind.monthlyCerts:
      final cfg = await MonthlyCfg.load();
      final label = monthName(sc.month, hijri);
      final subjects = await Db.subjectsOf(sc.classId);
      final recorded = await Db.count(
          'SELECT COUNT(DISTINCT date) FROM attendance WHERE student_id IN '
          '(SELECT id FROM students WHERE class_id=?)',
          [sc.classId]);
      final data = <MonthlyCertData>[];
      final flat = <List<String>>[];
      for (final s in students) {
        final sid = s['id'] as int;
        final absent = await Db.count(
            "SELECT COUNT(*) FROM attendance WHERE student_id=? AND status='غائب'",
            [sid]);
        final abs = recorded > 0
            ? 'أيام الغياب: $absent (${(absent / recorded * 100).toStringAsFixed(1)}%)'
            : 'أيام الغياب: $absent';
        final rows = <MonthlyRowData>[];
        for (final sub in subjects) {
          final m = await d.query('monthly',
              where: 'student_id=? AND subject_id=? AND month=?',
              whereArgs: [sid, sub['id'], sc.month]);
          double? n(String k) => m.isEmpty ? null : (m.first[k] as num?)?.toDouble();
          final r = MonthlyRowData(sub['name'] as String, n('hw'), n('att'), n('oral'), n('written'));
          rows.add(r);
          flat.add(['${s['name']}', r.subject, nf(r.hw), nf(r.att), nf(r.oral),
            nf(r.written), r.has ? nf(r.total) : '', r.has ? nf(cfg.convert(r.total)) : '']);
        }
        data.add(MonthlyCertData('${s['name']}', s['seat_no'] as int?, cls, abs, rows));
      }
      final heads = ['الاسم', 'المادة', ...cfg.labels, 'المجموع', 'المحوّلة'];
      return ReportData(
          ExportTable('شهادات شهر $label - $cls', heads, flat),
          () => buildMonthlyCerts(data, school, year, label, cfg.labels, cfg.maxes, cfg.convertTo),
          data.length);

    case RKind.finalCerts:
      return _certReport(sc, 2, onlyStudent, year);

    case RKind.semesterCerts:
      return _certReport(sc, semester == 1 ? 1 : 0, onlyStudent, year);

    case RKind.attendance:
      final day = date ?? DateTime.now();
      final prefix = '${day.year}-${two(day.month)}-';
      final heads = ['م', 'الاسم', 'حاضر', 'غائب', 'متأخر', 'مستأذن', 'أيام مسجلة', 'نسبة الحضور'];
      final rows = <List<String>>[];
      for (var i = 0; i < students.length; i++) {
        final s = students[i];
        final res = await d.rawQuery(
            'SELECT status, COUNT(*) c FROM attendance WHERE student_id=? AND date LIKE ? GROUP BY status',
            [s['id'], '$prefix%']);
        int c(String st) {
          for (final e in res) {
            if (e['status'] == st) return e['c'] as int;
          }
          return 0;
        }
        final p = c('حاضر'), a = c('غائب'), l = c('متأخر'), x = c('مستأذن');
        final tot = p + a + l + x;
        rows.add(['${i + 1}', '${s['name']}', '$p', '$a', '$l', '$x', '$tot',
          tot == 0 ? '-' : '${((p + l) / tot * 100).toStringAsFixed(0)}%']);
      }
      final title = 'تقرير الحضور - ${gregMonths[day.month - 1]} ${day.year} - $cls';
      return ReportData(ExportTable(title, heads, rows),
          () => buildTableReport(title, heads, rows, school, year,
              flex: [1, 5, 1.5, 1.5, 1.5, 1.5, 2, 2]),
          rows.length);
  }
}
