import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'arabic_text.dart';
import 'db.dart';
import 'logic.dart';
import 'results_service.dart';

/// الشهادة الرسمية: طباعة البيانات فقط على نموذج الوزارة الجاهز،
/// مع إمكانية ضبط موضع كل حقل بالبكسل (صفحة A4 = 1240×1754 بكسل).
const double kPageW = 1240, kPageH = 1754;
const double _k = 595.28 / 1240; // بكسل → نقطة PDF

class OEl {
  final String id, label, group, face; // face: f أمامي / b خلفي
  final double x, y, w;
  final String align; // r / c / l
  final bool on, ltr;
  const OEl(this.id, this.label, this.group, this.face, this.x, this.y, this.w,
      this.align,
      {this.on = true, this.ltr = false});
}

const kGroups = <String, String>{
  'student': 'بيانات الطالب (مجموعة)',
  'table': 'جدول الدرجات (مجموعة)',
  'result': 'مجموعة بيانات النتيجة',
  'sign': 'التواقيع (مجموعة)',
  'back': 'بيانات الوجه الخلفي (مجموعة)',
};

/// المواضع الافتراضية مأخوذة من نموذج الوزارة (الصفوف 1-8 الأساسي).
const kElements = <OEl>[
  OEl('gov', 'سطر اسم المحافظة', 'student', 'f', 760, 290, 330, 'r', on: false),
  OEl('school', 'سطر اسم المدرسة', 'student', 'f', 760, 372, 330, 'r', on: false),
  OEl('year', 'سطر العام الدراسي', 'student', 'f', 557, 340, 129, 'c', ltr: true),
  OEl('class', 'سطر اسم الصف', 'student', 'f', 913, 404, 200, 'r'),
  OEl('name', 'سطر اسم الطالب', 'student', 'f', 733, 450, 360, 'r'),
  OEl('gender', 'سطر النوع', 'student', 'f', 928, 487, 100, 'r'),
  OEl('nat', 'سطر الجنسية', 'student', 'f', 718, 487, 110, 'r'),
  OEl('rel', 'سطر الديانة', 'student', 'f', 713, 524, 110, 'r'),
  OEl('birthdate', 'سطر تاريخ الميلاد', 'student', 'f', 893, 561, 200, 'r', ltr: true),
  OEl('birthplace', 'سطر مكان الميلاد', 'student', 'f', 628, 561, 200, 'r'),
  OEl('regno', 'سطر رقم التسجيل', 'student', 'f', 867, 598, 100, 'r', ltr: true),
  OEl('table', 'جدول الدرجات', 'table', 'f', 240, 795, 0, 'c'),
  OEl('total', 'سطر المجموع النهائي', 'result', 'f', 890, 1268, 100, 'r', ltr: true),
  OEl('words', 'سطر المجموع كتابةً', 'result', 'f', 543, 1270, 260, 'r'),
  OEl('status', 'سطر النتيجة (ناجح/راسب)', 'result', 'f', 865, 1307, 100, 'r'),
  OEl('percent', 'سطر النسبة (المعدل)', 'result', 'f', 548, 1305, 80, 'r', ltr: true),
  OEl('rating', 'سطر التقدير', 'result', 'f', 859, 1346, 110, 'r'),
  OEl('rank', 'سطر الترتيب', 'result', 'f', 540, 1346, 120, 'r'),
  OEl('principal', 'سطر اسم المدير', 'sign', 'f', 830, 1500, 330, 'c', on: false),
  OEl('control', 'سطر اسم رئيس الكنترول', 'sign', 'f', 450, 1500, 330, 'c', on: false),
  OEl('vice', 'سطر اسم الوكيل', 'sign', 'f', 70, 1500, 330, 'c', on: false),
  OEl('b_hijri', 'العام الهجري (الخلف)', 'back', 'b', 702, 490, 200, 'c'),
  OEl('b_year', 'العام الميلادي (الخلف)', 'back', 'b', 350, 490, 200, 'c', ltr: true),
  OEl('b_name', 'اسم الطالب (الخلف)', 'back', 'b', 652, 525, 300, 'c'),
  OEl('b_class', 'الصف بالعربية (الخلف)', 'back', 'b', 702, 563, 200, 'c'),
  OEl('b_class_en', 'الصف بالإنجليزية (الخلف)', 'back', 'b', 350, 563, 200, 'c', ltr: true),
];

// مراكز أعمدة الجدول (من اليمين لليسار) بالنسبة لإحداثي الجدول، وعرض كل عمود.
const _colCenters = <double>[718, 604.5, 492.5, 375, 266, 154, 40.5];
const _colW = 80.0;

// ------------------------------------------------------------------ التخطيط
class OLayout {
  final Map<String, Offset> pos = {};
  final Map<String, bool> vis = {};
  final Map<String, Offset> grp = {};
  double fontPx = 24, rowPitch = 35.86;
  bool bold = true;

  Offset basePos(OEl e) => pos[e.id] ?? Offset(e.x, e.y);
  Offset posOf(OEl e) => basePos(e) + (grp[e.group] ?? Offset.zero);
  bool on(OEl e) => vis[e.id] ?? e.on;

  void move(OEl e, double dx, double dy) {
    final b = basePos(e);
    pos[e.id] = Offset(b.dx + dx, b.dy + dy);
  }

  void moveGroup(String g, double dx, double dy) {
    final b = grp[g] ?? Offset.zero;
    grp[g] = Offset(b.dx + dx, b.dy + dy);
  }

  Map<String, Object?> toJson() => {
        'pos': {for (final e in pos.entries) e.key: [e.value.dx, e.value.dy]},
        'vis': vis,
        'grp': {for (final e in grp.entries) e.key: [e.value.dx, e.value.dy]},
        'font': fontPx,
        'pitch': rowPitch,
        'bold': bold,
      };

  static OLayout fromJson(Map<String, dynamic> j) {
    final l = OLayout();
    Offset o(Object? v) {
      final a = v as List;
      return Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
    }

    (j['pos'] as Map? ?? {}).forEach((k, v) => l.pos['$k'] = o(v));
    (j['grp'] as Map? ?? {}).forEach((k, v) => l.grp['$k'] = o(v));
    (j['vis'] as Map? ?? {}).forEach((k, v) => l.vis['$k'] = v == true);
    l.fontPx = (j['font'] as num?)?.toDouble() ?? 24;
    l.rowPitch = (j['pitch'] as num?)?.toDouble() ?? 35.86;
    l.bold = j['bold'] != false;
    return l;
  }

  OLayout copy() => OLayout.fromJson(jsonDecode(jsonEncode(toJson())) as Map<String, dynamic>);

  static Future<OLayout> load() async {
    try {
      final s = await Db.setting('official_layout');
      if (s.isEmpty) return OLayout();
      return OLayout.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return OLayout();
    }
  }

  Future<void> save() => Db.setSetting('official_layout', jsonEncode(toJson()));
}

// ------------------------------------------------------------------ البيانات
class OStudent {
  final int id;
  final String name;
  final Map<String, String> v;
  final List<List<String>> rows; // كل صف: 7 أعمدة من اليمين لليسار
  OStudent(this.id, this.name, this.v, this.rows);

  static OStudent sample() => OStudent(0, 'اسم الطالب الرباعي', {
        'gov': 'المحافظة', 'school': 'اسم المدرسة', 'year': '2025-2026',
        'class': 'الأول', 'name': 'اسم الطالب الرباعي', 'gender': 'ذكر',
        'nat': 'يمني', 'rel': 'مسلم', 'birthdate': '2015/03/04',
        'birthplace': 'مكان الميلاد', 'regno': '1',
        'total': '600', 'words': 'ستمائة', 'status': 'ناجح', 'percent': '100',
        'rating': 'ممتاز', 'rank': 'الأول',
        'principal': 'مدير المدرسة', 'control': 'رئيس الكنترول', 'vice': 'الوكيل',
        'b_hijri': '1447هـ', 'b_year': '2025-2026', 'b_name': 'اسم الطالب الرباعي',
        'b_class': 'الأول', 'b_class_en': 'First Grade',
      }, [
        for (var i = 0; i < 8; i++) ['20', '30', '50', '20', '30', '50', '100'],
      ]);
}

String _hijriDefault(String year) {
  final m = RegExp(r'14\d\d').firstMatch(year);
  return m == null ? '' : '${m.group(0)}هـ';
}

String _yearDefault(String year) {
  final m = RegExp(r'14\d\d').firstMatch(year);
  if (m == null) return year;
  final n = int.parse(m.group(0)!);
  return '${n + 578}-${n + 579}';
}

const _enClass = {
  1: 'First Grade', 2: 'Second Grade', 3: 'Third Grade', 4: 'Fourth Grade',
  5: 'Fifth Grade', 6: 'Sixth Grade', 7: 'Seventh Grade', 8: 'Eighth Grade',
  9: 'Ninth Grade', 10: 'First Secondary', 11: 'Second Secondary',
  12: 'Third Secondary',
};

Future<List<OStudent>> loadOfficial(int classId, {String? section}) async {
  final d = await Db.get();
  final subs = await Db.subjectsOf(classId);
  final cname = await Db.className(classId);
  final ranked = await classResults(classId);
  final yearSet = await Db.setting('year');
  final school = await Db.setting('school');
  Future<String> st(String k, String def) async {
    final v = (await Db.setting(k)).trim();
    return v.isEmpty ? def : v;
  }

  final gov = await Db.setting('official_gov');
  final nat = await st('official_nat', 'يمني');
  final rel = await st('official_rel', 'مسلم');
  final year = await st('official_year', _yearDefault(yearSet));
  final hijri = await st('official_hijri', _hijriDefault(yearSet));
  final principal = await Db.setting('cert_principal');
  final control = await Db.setting('cert_control_head');
  final vice = await Db.setting('cert_vice');
  final short = cname.replaceAll(' أساسي', '');
  final en = _enClass[classId] ?? '';

  final list = ranked
      .where((r) => section == null || r.student['section'] == section)
      .toList()
    ..sort((a, b) {
      final x = (a.student['seat_no'] as num?)?.toInt() ?? (1 << 30);
      final y = (b.student['seat_no'] as num?)?.toInt() ?? (1 << 30);
      return x != y ? x.compareTo(y) : '${a.student['id']}'.compareTo('${b.student['id']}');
    });

  final out = <OStudent>[];
  for (final r in list) {
    final s = r.student;
    final sid = s['id'] as int;
    final g = await d.query('grades', where: 'student_id=?', whereArgs: [sid]);
    final gm = {for (final e in g) e['subject_id'] as int: e};
    final rows = <List<String>>[];
    for (final sub in subs) {
      final row = gm[sub['id'] as int];
      double n(String k) => (row?[k] as num?)?.toDouble() ?? 0;
      final w1 = n('t1_work'), e1 = n('t1_exam'), w2 = n('t2_work'), e2 = n('t2_exam');
      rows.add([
        nf(w1), nf(e1), nf(w1 + e1), nf(w2), nf(e2), nf(w2 + e2),
        nf(w1 + e1 + w2 + e2),
      ]);
    }
    final res = r.result;
    final name = '${s['name']}';
    out.add(OStudent(sid, name, {
      'gov': gov, 'school': school, 'year': year, 'class': short, 'name': name,
      'gender': '${s['gender'] ?? ''}', 'nat': nat, 'rel': rel,
      'birthdate': '${s['birth'] ?? ''}'.replaceAll('-', '/'),
      'birthplace': '${s['address'] ?? ''}', 'regno': '${s['reg_no'] ?? ''}',
      'total': nf(res.total), 'words': arabicWords(res.total),
      'status': res.status, 'percent': res.percent.round().toString(),
      'rating': res.rating == '-' ? '' : res.rating,
      'rank': r.rank == null ? '' : ordinalAr(r.rank!),
      'principal': principal, 'control': control, 'vice': vice,
      'b_hijri': hijri, 'b_year': year, 'b_name': name, 'b_class': short,
      'b_class_en': en,
    }, rows));
  }
  return out;
}

// ------------------------------------------------------------------ عناصر الرسم
class ODraw {
  final String id, text, align;
  final double x, y, w;
  final bool ltr;
  const ODraw(this.id, this.x, this.y, this.w, this.text, this.align, this.ltr);
}

List<ODraw> drawItems(OStudent s, OLayout lay, String face) {
  final out = <ODraw>[];
  for (final e in kElements) {
    if (e.face != face || !lay.on(e)) continue;
    final p = lay.posOf(e);
    if (e.id == 'table') {
      for (var i = 0; i < s.rows.length; i++) {
        for (var j = 0; j < s.rows[i].length && j < _colCenters.length; j++) {
          out.add(ODraw('table', p.dx + _colCenters[j] - _colW / 2,
              p.dy + i * lay.rowPitch, _colW, s.rows[i][j], 'c', true));
        }
      }
      continue;
    }
    final t = s.v[e.id] ?? '';
    if (t.isEmpty) continue;
    out.add(ODraw(e.id, p.dx, p.dy, e.w, t, e.align, e.ltr));
  }
  return out;
}

// ------------------------------------------------------------------ PDF
Future<pw.MemoryImage?> _img(String path) async {
  if (path.isEmpty) return null;
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    return pw.MemoryImage(await f.readAsBytes());
  } catch (_) {
    return null;
  }
}

pw.TextAlign _pa(String a) => a == 'r'
    ? pw.TextAlign.right
    : a == 'l'
        ? pw.TextAlign.left
        : pw.TextAlign.center;

/// يبني ملف PDF: صفحة أمامية و/أو خلفية لكل طالب. [bg] = إظهار صورة النموذج خلف البيانات.
Future<Uint8List> buildOfficialPdf(List<OStudent> list, OLayout lay,
    {required bool front, required bool back, required bool bg}) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));
  final bgF = bg ? await _img(await Db.setting('official_bg_front')) : null;
  final bgB = bg ? await _img(await Db.setting('official_bg_back')) : null;
  const a4 = PdfPageFormat.a4;

  pw.Widget stack(OStudent s, String face, pw.MemoryImage? image) {
    final items = drawItems(s, lay, face);
    return pw.SizedBox(
      width: a4.width,
      height: a4.height,
      child: pw.Stack(children: [
        if (image != null)
          pw.Positioned(
              left: 0,
              top: 0,
              child: pw.Image(image, width: a4.width, height: a4.height, fit: pw.BoxFit.fill)),
        for (final it in items)
          pw.Positioned(
            left: it.x * _k,
            top: it.y * _k,
            child: pw.SizedBox(
              width: it.w * _k,
              child: pw.Text(it.text,
                  maxLines: 1,
                  textDirection: it.ltr ? pw.TextDirection.ltr : pw.TextDirection.rtl,
                  textAlign: _pa(it.align),
                  style: pw.TextStyle(
                      fontSize: lay.fontPx * _k,
                      fontWeight: lay.bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ),
      ]),
    );
  }

  for (final s in list) {
    if (front) {
      doc.addPage(pw.Page(
          pageFormat: a4, margin: pw.EdgeInsets.zero, build: (_) => stack(s, 'f', bgF)));
    }
    if (back) {
      doc.addPage(pw.Page(
          pageFormat: a4, margin: pw.EdgeInsets.zero, build: (_) => stack(s, 'b', bgB)));
    }
  }
  if (list.isEmpty || (!front && !back)) {
    doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('لا توجد بيانات'))));
  }
  return doc.save();
}
