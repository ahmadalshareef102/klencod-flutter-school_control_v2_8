import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'data_io.dart';
import 'logic.dart';

/// كشف رصد درجات المحصلة وامتحانات نهاية الفصل بالشكل الرسمي:
/// ترويسة رسمية، ثم جدول (م، الاسم، الجنس، لكل مادة: محصلة/اختبار/إجمالي،
/// المجموع الكلي، النتيجة النهائية)، ثم تواقيع المعتمِدين.
class SheetSubject {
  final String name;
  final double maxW, maxE;
  const SheetSubject(this.name, this.maxW, this.maxE);
}

class SheetRow {
  final String name, gender, result;
  final List<double?> w, e; // محصلة واختبار لكل مادة
  const SheetRow(this.name, this.gender, this.w, this.e, this.result);

  double? sub(int i) =>
      (w[i] == null && e[i] == null) ? null : (w[i] ?? 0) + (e[i] ?? 0);
  double? get total {
    double? t;
    for (var i = 0; i < w.length; i++) {
      final s = sub(i);
      if (s != null) t = (t ?? 0) + s;
    }
    return t;
  }
}

class SheetInfo {
  final String title, school, className, section, genderLabel, number;
  final String office, admin;
  final List<String> sigNames; // مدير المدرسة، اختبارات المديرية، مكتب المديرية، اختبارات المحافظة، مكتب المحافظة
  final Uint8List? emblem;
  const SheetInfo({
    required this.title, required this.school, required this.className,
    required this.section, required this.genderLabel, this.number = '',
    this.office = '', this.admin = '', required this.sigNames, this.emblem,
  });
}

const kSigTitles = <String>[
  'مدير المدرسة',
  'مدير الاختبارات بالمديرية',
  'مدير مكتب التربية بالمديرية',
  'مدير الاختبارات بالمحافظة',
  'مدير مكتب التربية بالمحافظة',
];

const int kSheetRows = 25;

String _n(double? v) => v == null ? '' : nf(v);

// ============================== PDF ==============================
const _blue = PdfColor.fromInt(0xFFC9DAF3);
const _head = PdfColor.fromInt(0xFFEEF2F7);

Future<Uint8List> buildSemesterSheetPdf(
    SheetInfo info, List<SheetSubject> subs, List<SheetRow> rows) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/SheetFont-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/SheetFont-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
  pw.MemoryImage? emblem;
  if (info.emblem != null) {
    try {
      emblem = pw.MemoryImage(info.emblem!);
    } catch (_) {}
  }

  final k = subs.length;
  const margin = 16.0;
  final availW = PdfPageFormat.a4.landscape.width - margin * 2;
  const numW = 20.0, genW = 30.0, totW = 40.0, resW = 46.0, minName = 130.0;
  final subW = ((availW - numW - genW - totW - resW - minName) / (3 * k))
      .clamp(10.0, 34.0)
      .toDouble();
  final nameW = availW - numW - genW - totW - resW - 3 * k * subW;
  final fs = k > 8 ? 7.0 : 9.0; // خط الجسم
  final hs = k > 8 ? 6.8 : 8.5; // خط الترويسة
  const rh = 14.0;
  const hh = 17.0; // ارتفاع صف الترويسة

  pw.Widget cell(String s, double w,
          {double h = rh, bool b = true, double? size, PdfColor? fill,
          pw.Alignment al = pw.Alignment.center}) =>
      pw.Container(
        width: w,
        height: h,
        alignment: al,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
        decoration: pw.BoxDecoration(
            color: fill, border: pw.Border.all(width: 0.5)),
        child: pw.Text(s,
            maxLines: 1,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(
                fontSize: size ?? fs,
                fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  pw.Widget line(String s, {double size = 8.5, bool b = false,
          pw.TextAlign al = pw.TextAlign.right}) =>
      pw.Text(s,
          textDirection: pw.TextDirection.rtl,
          textAlign: al,
          style: pw.TextStyle(
              fontSize: size, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal));

  // الأعمدة من اليمين لليسار ثم تُعكس للعرض.
  List<T> rtl<T>(List<T> l) => l.reversed.toList();

  pw.Widget headerRow() {
    final groups = <pw.Widget>[
      cell('م', numW, h: hh * 2, b: true, size: hs, fill: _head),
      cell('اسم الطالب', nameW, h: hh * 2, b: true, size: hs + 1, fill: _head),
      cell('الجنس', genW, h: hh * 2, b: true, size: hs, fill: _blue),
      for (final s in subs)
        pw.Column(children: [
          cell(s.name, subW * 3, h: hh, b: true, size: hs, fill: _head),
          pw.Row(children: rtl([
            cell(nf(s.maxW), subW, h: hh, b: true, size: hs, fill: _head),
            cell(nf(s.maxE), subW, h: hh, b: true, size: hs, fill: _head),
            cell(nf(s.maxW + s.maxE), subW, h: hh, b: true, size: hs, fill: _blue),
          ])),
        ]),
      cell('المجموع الكلي', totW, h: hh * 2, b: true, size: hs - 0.5, fill: _blue),
      cell('النتيجة النهائية', resW, h: hh * 2, b: true, size: hs - 0.5, fill: _head),
    ];
    return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start, children: rtl(groups));
  }

  pw.Widget bodyRow(int no, SheetRow? r) {
    final cells = <pw.Widget>[
      cell('$no', numW, b: true),
      cell(r?.name ?? '', nameW, al: pw.Alignment.centerRight),
      cell(r?.gender ?? '', genW, fill: _blue),
      for (var i = 0; i < k; i++) ...[
        cell(r == null ? '' : _n(r.w[i]), subW),
        cell(r == null ? '' : _n(r.e[i]), subW),
        cell(r == null ? '' : _n(r.sub(i)), subW, b: true, fill: _blue),
      ],
      cell(r == null ? '' : _n(r.total), totW, b: true, fill: _blue),
      cell(r?.result ?? '', resW, b: true),
    ];
    return pw.Row(children: rtl(cells));
  }

  pw.Widget topHeader() => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // اليسار: بيانات الكشف
          pw.SizedBox(
            width: 250,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              line('مدرسة/ ${info.school.isEmpty ? '..................' : info.school}', b: true),
              line('الصف/ ${info.className}', b: true),
              line('الجنس/ ${info.genderLabel}', b: true),
              line('الشعبة/ ${info.section.isEmpty ? '....' : info.section}', b: true),
              line('الكشف/ ${info.number.isEmpty ? '....' : info.number}', b: true),
            ]),
          ),
          // الوسط: الشعار
          pw.SizedBox(
            width: 90,
            height: 64,
            child: emblem != null
                ? pw.Image(emblem, fit: pw.BoxFit.contain)
                : pw.Center(child: line('بسم الله الرحمن الرحيم', b: true, size: 10)),
          ),
          // اليمين: ترويسة رسمية
          pw.SizedBox(
            width: 290,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              line('الجمهورية اليمنية', b: true, size: 9.5),
              line('وزارة التربية والتعليم والبحث العلمي', b: true, size: 9.5),
              if (info.office.trim().isNotEmpty) line(info.office.trim(), size: 8.5),
              if (info.admin.trim().isNotEmpty) line(info.admin.trim(), size: 8.5),
            ]),
          ),
        ],
      );

  pw.Widget signatures() => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rtl([
          for (var i = 0; i < kSigTitles.length; i++)
            pw.SizedBox(
              width: availW / 5 - 4,
              child: pw.Column(children: [
                line(kSigTitles[i], b: true, size: 8, al: pw.TextAlign.center),
                pw.SizedBox(height: 3),
                line(
                    (i < info.sigNames.length && info.sigNames[i].trim().isNotEmpty)
                        ? 'أ/ ${info.sigNames[i].trim()}'
                        : '..........................',
                    size: 8,
                    al: pw.TextAlign.center),
              ]),
            ),
        ]),
      );

  final pages = rows.isEmpty ? 1 : ((rows.length + kSheetRows - 1) ~/ kSheetRows);
  for (var p = 0; p < pages; p++) {
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(margin, 14, margin, 12),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          topHeader(),
          pw.SizedBox(height: 4),
          pw.Center(child: line(info.title, b: true, size: 11.5, al: pw.TextAlign.center)),
          pw.SizedBox(height: 4),
          headerRow(),
          for (var i = 0; i < kSheetRows; i++)
            bodyRow(p * kSheetRows + i + 1,
                p * kSheetRows + i < rows.length ? rows[p * kSheetRows + i] : null),
          pw.Spacer(),
          signatures(),
        ],
      ),
    ));
  }
  return doc.save();
}

// ============================== Excel ==============================
/// ورقة xlsx منسّقة بنفس الهيكل (دمج الترويسة، مجاميع بمعادلات حية).
Uint8List buildSemesterSheetXlsx(
    SheetInfo info, List<SheetSubject> subs, List<SheetRow> rows) {
  final k = subs.length;
  final lastCol = 3 + 3 * k + 1; // فهرس عمود النتيجة
  final totalCol = 3 + 3 * k;
  final grid = <List<XCell?>>[];
  final merges = <String>[];

  List<XCell?> blank() => List<XCell?>.filled(lastCol + 1, null);
  String ref(int c, int r) => '${colLetter(c)}${r + 1}';
  void merge(int c1, int r1, int c2, int r2) => merges.add('${ref(c1, r1)}:${ref(c2, r2)}');

  // 0: العنوان
  var r0 = blank();
  r0[0] = XCell.text(info.title, 4);
  grid.add(r0);
  merge(0, 0, lastCol, 0);
  // 1: بيانات الكشف
  var r1 = blank();
  r1[0] = XCell.text(
      'المدرسة: ${info.school}    الصف: ${info.className}    الشعبة: ${info.section}    الجنس: ${info.genderLabel}',
      8);
  grid.add(r1);
  merge(0, 1, lastCol, 1);
  if (info.office.trim().isNotEmpty || info.admin.trim().isNotEmpty) {
    var r2 = blank();
    r2[0] = XCell.text([info.office.trim(), info.admin.trim()].where((e) => e.isNotEmpty).join('   |   '), 0);
    grid.add(r2);
    merge(0, 2, lastCol, 2);
  } else {
    grid.add(blank());
  }

  // 3..5: ترويسة الجدول
  final h1 = blank(), h2 = blank(), h3 = blank();
  final hr = grid.length; // فهرس أول صف ترويسة
  h1[0] = const XCell.text('م', 2);
  h1[1] = const XCell.text('اسم الطالب', 2);
  h1[2] = const XCell.text('الجنس', 2);
  for (var c = 0; c < 3; c++) {
    h2[c] = const XCell.text('', 2);
    h3[c] = const XCell.text('', 2);
    merge(c, hr, c, hr + 2);
  }
  for (var i = 0; i < k; i++) {
    final c0 = 3 + 3 * i;
    h1[c0] = XCell.text(subs[i].name, 6);
    h1[c0 + 1] = const XCell.text('', 6);
    h1[c0 + 2] = const XCell.text('', 6);
    merge(c0, hr, c0 + 2, hr);
    h2[c0] = const XCell.text('المحصلة', 2);
    h2[c0 + 1] = const XCell.text('الاختبار', 2);
    h2[c0 + 2] = const XCell.text('الإجمالي', 6);
    h3[c0] = XCell.num(subs[i].maxW, 2);
    h3[c0 + 1] = XCell.num(subs[i].maxE, 2);
    h3[c0 + 2] = XCell.num(subs[i].maxW + subs[i].maxE, 6);
  }
  h1[totalCol] = const XCell.text('المجموع الكلي', 6);
  h1[lastCol] = const XCell.text('النتيجة النهائية', 2);
  h2[totalCol] = const XCell.text('', 6);
  h3[totalCol] = const XCell.text('', 6);
  h2[lastCol] = const XCell.text('', 2);
  h3[lastCol] = const XCell.text('', 2);
  merge(totalCol, hr, totalCol, hr + 2);
  merge(lastCol, hr, lastCol, hr + 2);
  grid..add(h1)..add(h2)..add(h3);

  // الصفوف
  final count = rows.length < kSheetRows ? kSheetRows : rows.length;
  for (var i = 0; i < count; i++) {
    final r = i < rows.length ? rows[i] : null;
    final rowIdx = grid.length; // فهرس الصف (0-based)
    final line = blank();
    line[0] = XCell.num((i + 1).toDouble(), 3);
    line[1] = XCell.text(r?.name ?? '', 5);
    line[2] = XCell.text(r?.gender ?? '', 6);
    final totalRefs = <String>[];
    for (var j = 0; j < k; j++) {
      final c0 = 3 + 3 * j;
      final w = r?.w[j], e = r?.e[j];
      line[c0] = w == null ? const XCell.text('', 3) : XCell.num(w, 3);
      line[c0 + 1] = e == null ? const XCell.text('', 3) : XCell.num(e, 3);
      final s = r?.sub(j);
      line[c0 + 2] = XCell.formula(
          'IF(AND(${ref(c0, rowIdx)}="",${ref(c0 + 1, rowIdx)}=""),"",SUM(${ref(c0, rowIdx)}:${ref(c0 + 1, rowIdx)}))',
          n: s, str: s == null ? '' : null, s: 6);
      totalRefs.add(ref(c0 + 2, rowIdx));
    }
    final tot = r?.total;
    line[totalCol] = XCell.formula('IF(COUNT(${totalRefs.join(',')})=0,"",SUM(${totalRefs.join(',')}))',
        n: tot, str: tot == null ? '' : null, s: 6);
    line[lastCol] = XCell.text(r?.result ?? '', 3);
    grid.add(line);
  }

  // التواقيع
  grid.add(blank());
  final sigT = blank(), sigN = blank();
  final span = (lastCol + 1) ~/ 5;
  for (var i = 0; i < 5; i++) {
    final c1 = i * span;
    final c2 = i == 4 ? lastCol : c1 + span - 1;
    sigT[c1] = XCell.text(kSigTitles[i], 1);
    sigN[c1] = XCell.text(
        (i < info.sigNames.length && info.sigNames[i].trim().isNotEmpty)
            ? 'أ/ ${info.sigNames[i].trim()}'
            : '....................',
        0);
    if (c2 > c1) {
      merge(c1, grid.length, c2, grid.length);
      merge(c1, grid.length + 1, c2, grid.length + 1);
    }
  }
  grid..add(sigT)..add(sigN);

  final widths = <int, double>{0: 5, 1: 30, 2: 7};
  for (var i = 0; i < k * 3; i++) {
    widths[3 + i] = 7.5;
  }
  widths[totalCol] = 10;
  widths[lastCol] = 13;
  return buildXlsxSheet('كشف رصد الدرجات', grid,
      merges: merges, colWidths: widths, rowHeights: {0: 28});
}
