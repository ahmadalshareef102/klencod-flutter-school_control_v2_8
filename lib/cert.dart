import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'db.dart';

/// إعدادات تصميم الشهادة (من شاشة إعدادات الشهادة).
class CertStyle {
  final String school, office, admin, controlHead, principal, vice;
  final bool bg, frame;
  final Uint8List? emblem, logo, stamp;
  const CertStyle({
    this.school = '', this.office = '', this.admin = '',
    this.controlHead = '', this.principal = '', this.vice = '',
    this.bg = true, this.frame = true, this.emblem, this.logo, this.stamp,
  });
}

Future<Uint8List?> readImageBytes(String path) async {
  if (path.isEmpty) return null;
  try {
    final f = File(path);
    if (await f.exists()) return await f.readAsBytes();
  } catch (_) {}
  return null;
}

Future<CertStyle> loadCertStyle() async => CertStyle(
      school: await Db.setting('school'),
      office: await Db.setting('cert_office'),
      admin: await Db.setting('cert_admin'),
      controlHead: await Db.setting('cert_control_head'),
      principal: await Db.setting('cert_principal'),
      vice: await Db.setting('cert_vice'),
      bg: (await Db.setting('cert_bg')) != '0',
      frame: (await Db.setting('cert_frame')) != '0',
      emblem: await readImageBytes(await Db.setting('cert_emblem')),
      logo: await readImageBytes(await Db.setting('cert_logo')),
      stamp: await readImageBytes(await Db.setting('cert_stamp')),
    );

class ResultCertData {
  final String name, regNo, seat, className, section, address, photoPath;
  final List<String> heads; // ثلاثة أعمدة رقمية + التقدير
  final List<List<String>> rows; // مادة، أ، ب، ج، تقدير
  final List<String> totals; // أ، ب، ج، تقدير
  final String totalWords, rankText, percent;
  const ResultCertData({
    required this.name, required this.regNo, required this.seat,
    required this.className, required this.section, required this.address,
    required this.photoPath, required this.heads, required this.rows,
    required this.totals, required this.totalWords, required this.rankText,
    required this.percent,
  });
}

const _purple = PdfColor.fromInt(0xFF6A3FA0);
const _lavender = PdfColor.fromInt(0xFFD9CCEE);
const _paper = PdfColor.fromInt(0xFFE8F5E2);
const _head = PdfColor.fromInt(0xFFD7DFE6);
const _tint = PdfColor.fromInt(0xFFCDE6EE);
const _titleFill = PdfColor.fromInt(0xFFCFE8E2);

void _paintFrame(PdfGraphics c, PdfPoint size, bool bg, bool frame) {
  final w = size.x, h = size.y;
  if (bg) {
    c.setFillColor(_paper);
    c.drawRect(0, 0, w, h);
    c.fillPath();
  }
  if (!frame) return;
  const m = 14.0, band = 20.0;
  c.setFillColor(_lavender);
  c.drawRect(m, m, w - 2 * m, band);
  c.fillPath();
  c.drawRect(m, h - m - band, w - 2 * m, band);
  c.fillPath();
  c.drawRect(m, m, band, h - 2 * m);
  c.fillPath();
  c.drawRect(w - m - band, m, band, h - 2 * m);
  c.fillPath();
  c.setStrokeColor(_purple);
  c.setLineWidth(1.4);
  c.drawRect(m, m, w - 2 * m, h - 2 * m);
  c.strokePath();
  c.drawRect(m + band, m + band, w - 2 * (m + band), h - 2 * (m + band));
  c.strokePath();
  c.setFillColor(_purple);
  void diamond(double cx, double cy, double r) {
    c.moveTo(cx - r, cy);
    c.lineTo(cx, cy + r);
    c.lineTo(cx + r, cy);
    c.lineTo(cx, cy - r);
    c.closePath();
    c.fillPath();
  }

  const step = 13.0;
  for (var x = m + band; x < w - m - band - step / 2; x += step) {
    diamond(x + step / 2, m + band / 2, 4);
    diamond(x + step / 2, h - m - band / 2, 4);
  }
  for (var y = m; y < h - m - step / 2; y += step) {
    diamond(m + band / 2, y + step / 2, 4);
    diamond(w - m - band / 2, y + step / 2, 4);
  }
}

pw.Widget _ct(String s,
        {double size = 10,
        bool bold = false,
        pw.TextAlign align = pw.TextAlign.center,
        PdfColor? color}) =>
    pw.Text(s,
        textDirection: pw.TextDirection.rtl,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: size,
            color: color,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal));

List<T> _r<T>(List<T> l) => l.reversed.toList();

pw.Widget _cell(String s,
        {bool bold = false, double size = 10.5, PdfColor? fill}) =>
    pw.Container(
      color: fill,
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      alignment: pw.Alignment.center,
      child: _ct(s, bold: bold, size: size),
    );

pw.Widget _lineRow(String a, String b) => pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: _r([
        pw.Expanded(flex: 3, child: _ct(a, bold: true, size: 11, align: pw.TextAlign.right)),
        pw.Expanded(flex: 2, child: _ct(b, bold: true, size: 11, align: pw.TextAlign.right)),
      ]),
    );

pw.Widget _sign(String title, String name) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 22),
      child: pw.Column(children: [
        _ct(title, bold: true, size: 10),
        pw.SizedBox(height: 3),
        _ct(name.isEmpty ? '..................' : name, size: 9),
      ]),
    );

/// شهادات النتيجة بتصميم الإطار الزخرفي: شهادة في كل صفحة A4.
Future<Uint8List> buildResultCerts(List<ResultCertData> data, CertStyle st,
    String year, String title) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

  pw.MemoryImage? img(Uint8List? b) {
    if (b == null) return null;
    try {
      return pw.MemoryImage(b);
    } catch (_) {
      return null;
    }
  }

  final emblem = img(st.emblem), logo = img(st.logo), stamp = img(st.stamp);
  if (data.isEmpty) {
    doc.addPage(pw.Page(build: (_) => _ct('لا يوجد طلاب')));
  }

  for (final c in data) {
    final photoBytes = await readImageBytes(c.photoPath);
    final photo = img(photoBytes);

    final header = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: _r([
        pw.Expanded(
          flex: 4,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _ct('الجمهورية اليمنية', bold: true, size: 10, align: pw.TextAlign.right),
            _ct('وزارة التربية والتعليم', size: 9.5, align: pw.TextAlign.right),
            if (st.office.isNotEmpty) _ct(st.office, size: 9.5, align: pw.TextAlign.right),
            if (st.admin.isNotEmpty) _ct(st.admin, size: 9.5, align: pw.TextAlign.right),
            pw.SizedBox(height: 2),
            _ct(st.school, bold: true, size: 12, align: pw.TextAlign.right),
          ]),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Column(children: [
            _ct('بسم الله الرحمن الرحيم', bold: true, size: 12),
            pw.SizedBox(height: 4),
            if (emblem != null) pw.Image(emblem, height: 62),
          ]),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Column(children: [
            if (photo != null)
              pw.Container(
                width: 62,
                height: 78,
                decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.white, width: 3)),
                child: pw.Image(photo, fit: pw.BoxFit.cover),
              ),
            if (logo != null) ...[
              pw.SizedBox(height: 4),
              pw.Image(logo, height: 46),
            ],
          ]),
        ),
      ]),
    );

    final titleRow = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: _r([
        pw.Column(children: [
          _ct('رقم الجلوس', bold: true, size: 11),
          pw.SizedBox(height: 2),
          pw.Container(
            width: 88,
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(width: 1.2)),
            child: _ct(c.seat, bold: true, size: 14),
          ),
        ]),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: pw.BoxDecoration(
                color: _titleFill,
                border: pw.Border.all(width: 1.2),
                borderRadius: pw.BorderRadius.circular(3)),
            child: _ct(title, bold: true, size: 13),
          ),
        ),
      ]),
    );

    final heads = ['المواد الدراسية', ...c.heads];
    final widths = _r(<pw.TableColumnWidth>[
      const pw.FlexColumnWidth(3), const pw.FlexColumnWidth(1.2),
      const pw.FlexColumnWidth(1.2), const pw.FlexColumnWidth(1.2),
      const pw.FlexColumnWidth(1.4),
    ]);
    final table = pw.Table(
      border: pw.TableBorder.all(width: 1.1),
      columnWidths: {for (var i = 0; i < widths.length; i++) i: widths[i]},
      children: [
        pw.TableRow(children: _r([for (final h in heads) _cell(h, bold: true, fill: _head)])),
        for (final r in c.rows)
          pw.TableRow(children: _r([
            for (var i = 0; i < r.length; i++)
              _cell(r[i], bold: i == 0, fill: i == r.length - 1 ? _tint : null),
          ])),
        pw.TableRow(children: _r([
          _cell('المجموع العام', bold: true, fill: _head),
          for (var i = 0; i < c.totals.length; i++) _cell(c.totals[i], bold: true, fill: _tint),
        ])),
      ],
    );

    final wordsTable = pw.Table(
      border: pw.TableBorder.all(width: 1.1),
      columnWidths: {0: const pw.FlexColumnWidth(4), 1: const pw.FlexColumnWidth(2.4)},
      children: [
        pw.TableRow(children: _r([
          _cell('المجموع العام الكلي كتابة', bold: true, fill: _head),
          _cell(c.totalWords, bold: true, size: 10, fill: _tint),
        ])),
      ],
    );

    final rankTable = pw.Table(
      border: pw.TableBorder.all(width: 1.1),
      children: [
        pw.TableRow(children: _r([
          _cell('الترتيب', bold: true, fill: const PdfColor.fromInt(0xFFF4D6DD)),
          _cell(c.rankText, bold: true),
          _cell('المعدل', bold: true, fill: _tint),
          _cell('${c.percent} %', bold: true),
        ])),
      ],
    );

    final signs = pw.SizedBox(
      width: 120,
      child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        _sign('رئيس الكنترول', st.controlHead),
        _sign('رائد الصف', ''),
        _sign('مدير المدرسة', st.principal),
      ]),
    );

    final content = pw.SizedBox(
      width: 490,
      child: pw.Column(children: [
        header,
        pw.SizedBox(height: 8),
        titleRow,
        pw.SizedBox(height: 4),
        _ct('للعام الدراسي  $year', size: 11, bold: true),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _ct('بيانات الطالب', bold: true, size: 14, align: pw.TextAlign.right),
        ),
        pw.SizedBox(height: 4),
        _lineRow('رقم الطالب /  ${c.regNo}', 'الصف /  ${c.className}'),
        pw.SizedBox(height: 3),
        _lineRow('اسم الطالب /  ${c.name}', 'الشعبة /  (${c.section})'),
        pw.SizedBox(height: 3),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _ct('العنوان /  ${c.address}', bold: true, size: 11, align: pw.TextAlign.right),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: _r([
            pw.Expanded(
              child: pw.Column(children: [table, pw.SizedBox(height: 4), wordsTable, pw.SizedBox(height: 4), rankTable]),
            ),
            pw.SizedBox(width: 8),
            signs,
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: _r([
            pw.Column(children: [
              _ct('وكيل المدرسة', bold: true, size: 10),
              _ct(st.vice.isEmpty ? '..................' : st.vice, size: 9),
            ]),
            if (stamp != null) pw.Image(stamp, height: 80) else pw.SizedBox(height: 80),
            pw.SizedBox(width: 110),
          ]),
        ),
      ]),
    );

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: [
        pw.Positioned.fill(
          child: pw.CustomPaint(
            size: PdfPoint(PdfPageFormat.a4.width, PdfPageFormat.a4.height),
            painter: (canvas, size) => _paintFrame(canvas, size, st.bg, st.frame),
          ),
        ),
        if (logo != null)
          pw.Positioned.fill(
            child: pw.Center(
                child: pw.Opacity(opacity: 0.07, child: pw.Image(logo, width: 300))),
          ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(52, 46, 52, 40),
          child: pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.FittedBox(fit: pw.BoxFit.scaleDown, child: content),
          ),
        ),
      ]),
    ));
  }
  return doc.save();
}
