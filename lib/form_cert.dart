import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'arabic_text.dart';
import 'cert.dart' show readImageBytes;
import 'db.dart';
import 'logic.dart';
import 'results_service.dart';

/// شهادة تقييم التلميذ على النموذج الرسمي (الورق المطبوع مسبقاً).
/// الإحداثيات كلها بوحدة "بكسل" على لوحة عرضها 1175 وارتفاعها 1662 (صفحة A4).
const double kFormW = 1175;
const double kFormH = 1662;
const double kRowH = 28; // ارتفاع سطر النص

/// عنصر نصي على النموذج.
class FormItem {
  final String id, label, group;
  final double x, y, w;
  final String anchor; // r: الحافة اليمنى، c: المنتصف، l: الحافة اليسرى
  final bool defaultOn;
  const FormItem(this.id, this.label, this.group, this.x, this.y,
      {this.anchor = 'r', this.w = 420, this.defaultOn = true});
}

const kFormItems = <FormItem>[
  // ---- بيانات الطالب ----
  FormItem('gov', 'سطر اسم المحافظة', 'student', 1050, 182, defaultOn: false),
  FormItem('school', 'سطر اسم المدرسة', 'student', 1055, 350, defaultOn: false),
  FormItem('year', 'سطر العام الدراسي', 'student', 589, 322, anchor: 'c', w: 220),
  FormItem('class', 'سطر اسم الصف', 'student', 1054, 383),
  FormItem('name', 'سطر اسم الطالب', 'student', 1035, 426, w: 520),
  FormItem('gender', 'سطر النوع', 'student', 974, 461, w: 200),
  FormItem('nation', 'سطر الجنسية', 'student', 785, 461, w: 200),
  FormItem('religion', 'سطر الديانة', 'student', 780, 496, w: 200),
  FormItem('dob', 'سطر تاريخ الميلاد', 'student', 985, 496, defaultOn: false, w: 260),
  FormItem('pob', 'سطر مكان الميلاد', 'student', 985, 531, defaultOn: false, w: 300),
  FormItem('regno', 'سطر رقم التسجيل', 'student', 911, 566, anchor: 'c', w: 160),
  // ---- جدول الدرجات (عنصر واحد) ----
  FormItem('table', 'جدول الدرجات', 'grades', 0, 0, w: 0),
  // ---- النتيجة ----
  FormItem('total', 'سطر المجموع النهائي', 'result', 938, 1200, w: 200),
  FormItem('words', 'سطر المجموع كتابةً', 'result', 761, 1203, w: 420),
  FormItem('status', 'سطر النتيجة (ناجح/راسب)', 'result', 914, 1238, w: 200),
  FormItem('grade', 'سطر التقدير', 'result', 918, 1274, w: 200),
  FormItem('percent', 'سطر النسبة (المعدل)', 'result', 574, 1235, anchor: 'c', w: 160),
  FormItem('rank', 'سطر الترتيب', 'result', 625, 1274, w: 200),
  // ---- التواقيع ----
  FormItem('principal', 'سطر اسم المدير', 'sign', 1050, 1500, defaultOn: false, w: 340),
  FormItem('control', 'سطر رئيس الكنترول', 'sign', 700, 1500, defaultOn: false, w: 340),
];

const kFormGroups = <(String, String)>[
  ('student', 'بيانات الطالب (مجموعة)'),
  ('grades', 'جدول الدرجات (مجموعة)'),
  ('result', 'مجموعة بيانات النتيجة'),
  ('sign', 'مجموعة التواقيع'),
];

/// مراكز أعمدة الجدول من اليمين لليسار:
/// محصلة ف1، اختبار ف1، مجموع ف1، محصلة ف2، اختبار ف2، مجموع ف2، المجموع النهائي.
const kColX = <double>[908, 800, 694, 583, 479, 373, 265];
const double kRowsTop = 753;
const double kRowStep = 34;

/// تخطيط محفوظ: إزاحات العناصر والمجموعات، وتفعيلها، وحجم الخط وتباعد الصفوف.
class FormLayout {
  final Map<String, List<double>> off;
  final Map<String, bool> on;
  double fontSize; // بالنقطة
  double rowStep;
  FormLayout({Map<String, List<double>>? off, Map<String, bool>? on,
      this.fontSize = 12, this.rowStep = kRowStep})
      : off = off ?? {},
        on = on ?? {};

  static const key = 'form_layout';

  bool enabled(FormItem i) => on[i.id] ?? i.defaultOn;
  List<double> offset(String id) => off[id] ?? const [0, 0];

  void move(String id, double dx, double dy) {
    final o = offset(id);
    off[id] = [o[0] + dx, o[1] + dy];
  }

  double posX(FormItem i) =>
      i.x + offset(i.id)[0] + offset('g:${i.group}')[0];
  double posY(FormItem i) =>
      i.y + offset(i.id)[1] + offset('g:${i.group}')[1];

  String toJson() => jsonEncode({
        'o': off,
        'e': on,
        'fs': fontSize,
        'rs': rowStep,
      });

  static FormLayout fromJson(String s) {
    if (s.isEmpty) return FormLayout();
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final o = <String, List<double>>{};
      (m['o'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
        final l = (v as List).map((e) => (e as num).toDouble()).toList();
        if (l.length == 2) o[k] = l;
      });
      final e = <String, bool>{};
      (m['e'] as Map<String, dynamic>? ?? {}).forEach((k, v) => e[k] = v == true);
      return FormLayout(
          off: o,
          on: e,
          fontSize: (m['fs'] as num?)?.toDouble() ?? 12,
          rowStep: (m['rs'] as num?)?.toDouble() ?? kRowStep);
    } catch (_) {
      return FormLayout();
    }
  }

  FormLayout copy() => FormLayout.fromJson(toJson());

  static Future<FormLayout> load() async => fromJson(await Db.setting(key));
  Future<void> save() => Db.setSetting(key, toJson());
}

/// بيانات شهادة طالب واحد.
class FormStudent {
  final int id;
  final Map<String, String> v; // قيم الحقول النصية بالمعرّف
  final List<List<String>> rows; // صفوف الجدول (7 أعمدة)
  FormStudent(this.id, this.v, this.rows);
}

/// نص موضوع على اللوحة (يستخدمه المعاين وملف PDF معاً).
class Placed {
  final String text;
  final double left, top, w; // بالبكسل
  final String anchor;
  Placed(this.text, this.left, this.top, this.w, this.anchor);
}

List<Placed> layoutTexts(FormStudent s, FormLayout L) {
  final out = <Placed>[];
  for (final i in kFormItems) {
    if (!L.enabled(i)) continue;
    if (i.id == 'table') {
      final dx = L.offset('table')[0] + L.offset('g:grades')[0];
      final dy = L.offset('table')[1] + L.offset('g:grades')[1];
      for (var r = 0; r < s.rows.length; r++) {
        for (var c = 0; c < kColX.length && c < s.rows[r].length; c++) {
          out.add(Placed(s.rows[r][c], kColX[c] + dx - 50,
              kRowsTop + L.rowStep * r + dy, 100, 'c'));
        }
      }
      continue;
    }
    final t = s.v[i.id] ?? '';
    if (t.isEmpty) continue;
    final x = L.posX(i), y = L.posY(i);
    final left = i.anchor == 'r'
        ? x - i.w
        : i.anchor == 'c'
            ? x - i.w / 2
            : x;
    out.add(Placed(t, left, y, i.w, i.anchor));
  }
  return out;
}

String _ordinalOnly(String className) => className
    .replaceAll('أساسي', '')
    .replaceAll('الثانوي', '')
    .replaceAll('علمي', '')
    .replaceAll('أدبي', '')
    .trim();

String _dateSlash(Object? v) {
  final s = '${v ?? ''}';
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}

/// يجهّز بيانات شهادات طلاب صف (مرتبين برقم الجلوس).
Future<List<FormStudent>> loadFormStudents(int classId,
    {String? section, int? onlyId}) async {
  final d = await Db.get();
  final ranked = await classResults(classId, section: section);
  ranked.sort((a, b) {
    final x = (a.student['seat_no'] as num?) ?? 0;
    final y = (b.student['seat_no'] as num?) ?? 0;
    return x.compareTo(y);
  });
  final subjects = await Db.subjectsOf(classId);
  final school = await Db.setting('school');
  final year = await Db.setting('year');
  final className = _ordinalOnly(await Db.className(classId));
  final nation = (await Db.setting('form_nation')).isEmpty
      ? 'يمني'
      : await Db.setting('form_nation');
  final religion = (await Db.setting('form_religion')).isEmpty
      ? 'مسلم'
      : await Db.setting('form_religion');
  final gov = await Db.setting('form_gov');
  final principal = await Db.setting('cert_principal');
  final control = await Db.setting('cert_control_head');

  final out = <FormStudent>[];
  for (final r in ranked) {
    final st = r.student;
    final id = st['id'] as int;
    if (onlyId != null && id != onlyId) continue;
    final rows = <List<String>>[];
    for (final sub in subjects) {
      final g = await d.query('grades',
          where: 'student_id=? AND subject_id=?', whereArgs: [id, sub['id']]);
      final m = g.isEmpty ? <String, Object?>{} : g.first;
      double n(String k) => (m[k] as num?)?.toDouble() ?? 0;
      final t1 = n('t1_work') + n('t1_exam');
      final t2 = n('t2_work') + n('t2_exam');
      rows.add([
        nf(n('t1_work')), nf(n('t1_exam')), nf(t1),
        nf(n('t2_work')), nf(n('t2_exam')), nf(t2),
        nf(t1 + t2),
      ]);
    }
    final res = r.result;
    final absent = res.status == 'غائب';
    final pct = double.parse(res.percent.toStringAsFixed(1));
    out.add(FormStudent(id, {
      'gov': gov,
      'school': school,
      'year': year,
      'class': className,
      'name': '${st['name'] ?? ''}',
      'gender': '${st['gender'] ?? ''}',
      'nation': nation,
      'religion': religion,
      'dob': _dateSlash(st['birth']),
      'pob': '${st['address'] ?? ''}',
      'regno': '${st['reg_no'] ?? ''}',
      'total': nf(res.total),
      'words': arabicWords(res.total.round()),
      'status': absent ? '' : res.status,
      'grade': absent ? '' : res.rating,
      'percent': nf(pct),
      'rank': r.rank == null ? '-' : ordinalAr(r.rank!),
      'principal': principal,
      'control': control,
    }, rows));
  }
  return out;
}

/// يبني ملف PDF: صفحة A4 لكل طالب. [showBg] لرسم صورة النموذج،
/// و[showData] لرسم البيانات (أوقف الخلفية عند الطباعة على الورق الرسمي).
Future<Uint8List> buildFormPdf(List<FormStudent> list, FormLayout L,
    {bool showBg = false, bool showData = true}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
  pw.MemoryImage? bg;
  if (showBg) {
    final b = await readImageBytes(await Db.setting('form_bg'));
    if (b != null) {
      try {
        bg = pw.MemoryImage(b);
      } catch (_) {}
    }
  }
  final pageW = PdfPageFormat.a4.width, pageH = PdfPageFormat.a4.height;
  final k = pageW / kFormW; // نقطة لكل بكسل
  if (list.isEmpty) {
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('no students'))));
  }
  for (final s in list) {
    final kids = <pw.Widget>[];
    if (bg != null) {
      kids.add(pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Image(bg, width: pageW, height: pageH, fit: pw.BoxFit.fill)));
    }
    if (showData) {
      for (final p in layoutTexts(s, L)) {
        kids.add(pw.Positioned(
          left: p.left * k,
          top: p.top * k,
          child: pw.Container(
            width: p.w * k,
            height: kRowH * k,
            alignment: p.anchor == 'r'
                ? pw.Alignment.centerRight
                : p.anchor == 'c'
                    ? pw.Alignment.center
                    : pw.Alignment.centerLeft,
            child: pw.Text(p.text,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(fontSize: L.fontSize, font: font)),
          ),
        ));
      }
    }
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: kids),
    ));
  }
  return doc.save();
}
