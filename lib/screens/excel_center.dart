import 'package:flutter/material.dart';
import '../data_io.dart';
import '../dates.dart';
import '../db.dart';
import '../license.dart';
import '../logic.dart';
import '../app_state.dart';
import '../report_engine.dart';
import '../widgets.dart';
import 'detailed_options.dart';
import 'report_picker.dart';
import 'table_editor.dart';

class ExcelCenter extends StatefulWidget {
  final int initialTab; // 0 تصدير، 1 استيراد، 2 نماذج
  const ExcelCenter({super.key, this.initialTab = 0});
  @override
  State<ExcelCenter> createState() => _ExcelCenterState();
}

class _ExcelCenterState extends State<ExcelCenter> {
  late int tab = widget.initialTab;
  ReportSel? sel;
  List<int>? cols;
  RKind? colsKind;
  bool withTitle = false, busy = false;
  int importTarget = 0;
  Scope? impScope, tplScope, tplMulti, tplMonth;
  int tplSem = 2;
  String log = '';
  DetailedOptions detOpts = DetailedOptions();

  // ---------------- تصدير ----------------
  Future<void> _customize() async {
    final s = sel;
    if (s?.scope == null) return;
    if (s!.meta.kind == RKind.detailedSheet) {
      final o = await showDetailedOptions(context, detOpts);
      if (o != null) setState(() => detOpts = o);
      return;
    }
    try {
      final data = await buildReport(s!.meta.kind, s.scope!,
          semester: s.semester, date: s.date);
      final heads = data.table.heads;
      final chosen = {
        for (var i = 0; i < heads.length; i++)
          if (cols == null || colsKind != s.meta.kind || cols!.contains(i)) i
      };
      var title = withTitle;
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: const Text('تخصيص الترويسة والأعمدة'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(shrinkWrap: true, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تضمين عنوان التقرير واسم المدرسة'),
                  value: title,
                  onChanged: (v) => set(() => title = v),
                ),
                const Divider(),
                for (var i = 0; i < heads.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(heads[i]),
                    value: chosen.contains(i),
                    onChanged: (v) => set(() => v == true ? chosen.add(i) : chosen.remove(i)),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
            ],
          ),
        ),
      );
      if (ok == true && chosen.isNotEmpty) {
        setState(() {
          cols = chosen.toList()..sort();
          colsKind = s.meta.kind;
          withTitle = title;
        });
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر التحميل: $e');
    }
  }

  Future<void> _export(bool xlsx) async {
    final s = sel;
    if (s?.scope == null) return;
    setState(() => busy = true);
    try {
      final data = await buildReport(s!.meta.kind, s.scope!,
          semester: s.semester, date: s.date, detailed: detOpts);
      final custom = cols != null && colsKind == s.meta.kind;
      await shareReport(data,
          xlsx: xlsx,
          table: custom ? data.table.pick(cols!) : null,
          withTitle: withTitle,
          school: await Db.setting('school'),
          year: await Db.setting('year'));
    } catch (e) {
      if (mounted) toast(context, 'تعذر التصدير: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ---------------- استيراد ----------------
  Future<void> _import() async {
    try {
      final f = await pickAnyFile();
      if (f == null) return;
      final msg = await _runImport(parseTableFile(f));
      if (mounted) setState(() => log = msg);
    } catch (e) {
      if (mounted) setState(() => log = 'تعذر قراءة الملف: $e');
    }
  }

  Future<String> _runImport(List<List<String>> rows) async => switch (importTarget) {
        0 => await _importStudents(rows),
        1 => await _importGrades(rows),
        2 => await _importGradesMulti(rows),
        _ => await _importMonthly(rows),
      };

  /// يفتح الملف في المحرر لتعديله قبل تطبيقه في النظام.
  Future<void> _importEdit() async {
    try {
      final f = await pickAnyFile();
      if (f == null) return;
      final rows = parseTableFile(f);
      if (rows.isEmpty) return toast(context, 'الملف فارغ');
      if (!mounted) return;
      await open(
          context,
          TableEditorScreen(
            table: ExportTable(f.name, rows.first, rows.skip(1).toList()),
            onApply: (all) async {
              final m = await _runImport(all);
              if (mounted) setState(() => log = m);
              return m;
            },
          ));
    } catch (e) {
      if (mounted) setState(() => log = 'تعذر قراءة الملف: $e');
    }
  }

  /// يبني التقرير المختار ويفتحه في المحرر التفاعلي.
  Future<void> _openEditor() async {
    final s = sel;
    if (s?.scope == null) return;
    try {
      final data = await buildReport(s!.meta.kind, s.scope!,
          semester: s.semester, date: s.date, detailed: detOpts);
      if (!mounted) return;
      await open(context, TableEditorScreen(table: data.table));
    } catch (e) {
      if (mounted) toast(context, 'تعذر الفتح: $e');
    }
  }

  int _idx(List<String> head, List<String> keys) {
    for (var i = 0; i < head.length; i++) {
      for (final k in keys) {
        if (head[i].contains(k)) return i;
      }
    }
    return -1;
  }

  String _cell(List<String> r, int i) =>
      (i >= 0 && i < r.length) ? r[i].trim() : '';

  /// نافذة اختيار أعمدة الملف والجنس قبل استيراد الطلاب. تعيد null عند الإلغاء.
  Future<Map<String, Object>?> _askStudentColumns(List<List<String>> rows) async {
    final head = rows.first.map((e) => e.trim()).toList();
    var cols = 0;
    for (final r in rows.take(50)) {
      if (r.length > cols) cols = r.length;
    }
    final autoName = _idx(head, ['الاسم', 'اسم']);
    var hasHeader = autoName >= 0;
    final sel = <String, int>{
      'name': autoName >= 0 ? autoName : 0,
      'gender': _idx(head, ['الجنس', 'جنس']),
      'cls': _idx(head, ['الصف']),
      'sec': _idx(head, ['الشعبة', 'شعبة']),
      'phone': _idx(head, ['هاتف', 'جوال']),
      'notes': _idx(head, ['ملاحظ']),
      'reg': _idx(head, ['القيد', 'قيد', 'السجل']),
    };
    final saved = await Db.setting('default_gender');
    var mode = sel['gender']! >= 0 ? 'file' : (saved == 'ذكر' ? 'ذكر' : 'أنثى');
    if (!mounted) return null;
    const labels = <String, String>{
      'name': 'عمود الاسم (مطلوب)',
      'gender': 'عمود الجنس',
      'cls': 'عمود الصف',
      'sec': 'عمود الشعبة',
      'phone': 'عمود الهاتف',
      'notes': 'عمود الملاحظات',
      'reg': 'عمود رقم القيد',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          List<DropdownMenuItem<int>> items(bool required) => [
                if (!required) const DropdownMenuItem(value: -1, child: Text('— غير مستخدم —')),
                for (var i = 0; i < cols; i++)
                  DropdownMenuItem(
                      value: i,
                      child: Text(
                          hasHeader && i < head.length && head[i].isNotEmpty
                              ? 'عمود ${i + 1}: ${head[i]}'
                              : 'عمود ${i + 1}',
                          overflow: TextOverflow.ellipsis)),
              ];
          return AlertDialog(
            title: const Text('تحديد أعمدة الملف'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الصف الأول عناوين أعمدة'),
                  value: hasHeader,
                  onChanged: (v) => set(() => hasHeader = v),
                ),
                for (final k in labels.keys) ...[
                  const SizedBox(height: 8),
                  Pick<int>(
                    label: labels[k]!,
                    value: sel[k]! >= cols ? -1 : sel[k],
                    items: items(k == 'name'),
                    onChanged: (v) => set(() => sel[k] = v ?? -1),
                  ),
                ],
                const SizedBox(height: 14),
                const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('جنس الطلاب', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'أنثى', label: Text('كلهن إناث')),
                    const ButtonSegment(value: 'ذكر', label: Text('كلهم ذكور')),
                    ButtonSegment(
                        value: 'file',
                        label: const Text('من الملف'),
                        enabled: sel['gender']! >= 0),
                  ],
                  selected: {sel['gender']! < 0 && mode == 'file' ? 'أنثى' : mode},
                  onSelectionChanged: (v) => set(() => mode = v.first),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استيراد')),
            ],
          );
        },
      ),
    );
    if (ok != true) return null;
    if (mode != 'file') await Db.setSetting('default_gender', mode);
    return {
      ...sel,
      'header': hasHeader ? 1 : 0,
      'mode': mode == 'file' && sel['gender']! < 0 ? 'أنثى' : mode,
      'fallback': saved == 'ذكر' ? 'ذكر' : 'أنثى',
    };
  }

  Future<String> _importStudents(List<List<String>> rows) async {
    if (rows.isEmpty) return 'الملف فارغ';
    final classes = await Db.classes();
    final m = await _askStudentColumns(rows);
    if (m == null) return 'أُلغي الاستيراد';
    final hasHeader = m['header'] == 1;
    final iName = m['name'] as int;
    final iGender = m['gender'] as int;
    final iClass = m['cls'] as int;
    final iSec = m['sec'] as int;
    final iPhone = m['phone'] as int;
    final iNotes = m['notes'] as int;
    final iReg = m['reg'] as int;
    final mode = m['mode'] as String;
    var n = 0, skipped = 0;
    final touched = <int>{};
    for (var k = hasHeader ? 1 : 0; k < rows.length; k++) {
      final r = rows[k];
      final name = _cell(r, iName);
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      var cid = impScope?.classId ?? 1;
      final cText = _cell(r, iClass);
      if (cText.isNotEmpty) {
        for (final c in classes) {
          final cn = '${c['name']}';
          if (cn == cText || cn.contains(cText) || cText.contains(cn)) {
            cid = c['id'] as int;
            break;
          }
        }
      }
      final g = _cell(r, iGender);
      final female = mode == 'أنثى'
          ? true
          : mode == 'ذكر'
              ? false
              : g.isEmpty
                  ? m['fallback'] == 'أنثى'
                  : g.contains('أنث') || g.contains('انث') || g.contains('طالبة') ||
                      g.toLowerCase().startsWith('f');
      final reg = int.tryParse(_cell(r, iReg));
      try {
        await Db.addStudent({
        'name': name,
        'gender': female ? 'أنثى' : 'ذكر',
        'class_id': cid,
        'section': _cell(r, iSec).isEmpty ? (impScope?.section ?? 'أ') : _cell(r, iSec),
        'phone': _cell(r, iPhone),
        'notes': _cell(r, iNotes),
        'status': 'مستجد',
        'reg_date': isoDate(DateTime.now()),
        if (reg != null) 'reg_no': reg,
        }, reseat: false);
        touched.add(cid);
        n++;
      } on LicenseLimitException catch (e) {
        for (final c in touched) {
          await Db.assignSeats(c);
        }
        return 'توقف الاستيراد بعد $n طالب لأنك بلغت الحد المسموح (${e.limit}). '
            'تواصل مع المطور لتفعيل التطبيق ثم أعد استيراد الباقي.';
      }
    }
    for (final c in touched) {
      await Db.assignSeats(c);
    }
    return 'تم استيراد $n طالب (رُتّبوا أبجدياً في الجلوس)' + (skipped > 0 ? ' (تخطي $skipped صفاً فارغاً)' : '');
  }

  Future<String> _importGrades(List<List<String>> rows) async {
    final sc = impScope;
    if (sc == null || sc.subjectId == null) return 'اختر الصف والمادة أولاً';
    if (rows.isEmpty) return 'الملف فارغ';
    final rules = await Rules.load();
    final head = rows.first.map((e) => e.trim()).toList();
    final iReg = _idx(head, ['القيد', 'قيد']);
    final iName = _idx(head, ['الاسم', 'اسم']);
    final cols = {
      't1_work': (_idx(head, ['المحصلة 1', 'محصلة 1', 'المحصلة1']), rules.maxW1),
      't1_exam': (_idx(head, ['اختبار 1', 'الاختبار 1', 'اختبار1']), rules.maxE1),
      't2_work': (_idx(head, ['المحصلة 2', 'محصلة 2', 'المحصلة2']), rules.maxW2),
      't2_exam': (_idx(head, ['اختبار 2', 'الاختبار 2', 'اختبار2']), rules.maxE2),
    };
    if (iReg < 0 && iName < 0) return 'لم أجد عمود رقم القيد أو الاسم في الملف';
    final students = await Db.students(classId: sc.classId, section: sc.section);
    final byReg = {for (final s in students) '${s['reg_no']}': s['id'] as int};
    final byName = {for (final s in students) '${s['name']}'.trim(): s['id'] as int};
    var updated = 0, unmatched = 0, bad = 0;
    for (var k = 1; k < rows.length; k++) {
      final r = rows[k];
      final sid = byReg[_cell(r, iReg)] ?? byName[_cell(r, iName)];
      if (sid == null) {
        unmatched++;
        continue;
      }
      var any = false;
      for (final e in cols.entries) {
        final i = e.value.$1;
        final t = _cell(r, i);
        if (i < 0 || t.isEmpty) continue;
        final v = double.tryParse(t);
        if (v == null || v < 0 || v > e.value.$2) {
          bad++;
          continue;
        }
        await Db.saveGrade(sid, sc.subjectId!, e.key, v);
        any = true;
      }
      if (any) updated++;
    }
    return 'تم تحديث درجات $updated طالب'
        '${unmatched > 0 ? ' • لم يُطابَق $unmatched' : ''}'
        '${bad > 0 ? ' • قيم غير صالحة تم تجاهلها: $bad' : ''}';
  }

  // ---------------- نماذج ----------------
  Future<void> _studentTemplate(bool xlsx) => exportTable(
      ExportTable('قالب_الطلاب', [
        'الاسم', 'رقم القيد', 'الصف', 'الشعبة', 'الجنس', 'هاتف ولي الأمر', 'ملاحظات'
      ], [
        ['مثال: أحمد محمد علي حسن', '', 'الرابع أساسي', 'أ', 'ذكر', '', ''],
      ]),
      xlsx: xlsx);

  // ---------- أدوات المطابقة ----------
  String _norm(String s) => s
      .trim()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ـ', '')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// مكوّن الدرجة الفصلية من نص العنوان.
  String? _comp(String h) {
    final t = _norm(h).replaceAll(' ', '');
    if (t.contains('محصله1')) return 't1_work';
    if (t.contains('اختبار1') || t.contains('امتحان1')) return 't1_exam';
    if (t.contains('محصله2')) return 't2_work';
    if (t.contains('اختبار2') || t.contains('امتحان2')) return 't2_exam';
    return null;
  }

  DbRow? _matchSubject(String text, List<DbRow> subjects) {
    final t = _norm(text);
    DbRow? best;
    var len = 0;
    for (final sub in subjects) {
      final n = _norm('${sub['name']}');
      if (n.isNotEmpty && t.contains(n) && n.length > len) {
        best = sub;
        len = n.length;
      }
    }
    return best;
  }

  Map<String, double> _termMax(Rules r) => {
        't1_work': r.maxW1, 't1_exam': r.maxE1,
        't2_work': r.maxW2, 't2_exam': r.maxE2,
      };

  // ---------- استيراد عدة مواد في ملف واحد ----------
  Future<String> _importGradesMulti(List<List<String>> rows) async {
    final sc = impScope;
    if (sc == null) return 'اختر الصف أولاً';
    if (rows.length < 2) return 'الملف فارغ';
    final rules = await Rules.load();
    final maxOf = _termMax(rules);
    final subjects = await Db.subjectsOf(sc.classId);
    final head = rows.first.map((e) => e.trim()).toList();
    final iReg = _idx(head, ['القيد', 'قيد']);
    final iName = _idx(head, ['الاسم', 'اسم']);
    if (iReg < 0 && iName < 0) return 'لم أجد عمود رقم القيد أو الاسم في الملف';
    final students = await Db.students(classId: sc.classId, section: sc.section);
    final byReg = {for (final s in students) '${s['reg_no']}': s['id'] as int};
    final byName = {for (final s in students) _norm('${s['name']}'): s['id'] as int};
    int? sidOf(List<String> r) => byReg[_cell(r, iReg)] ?? byName[_norm(_cell(r, iName))];

    // هل الملف طويل (عمود «المادة») أم عريض (عمود لكل مادة ومكوّن)؟
    final iSub = head.indexWhere((h) => _norm(h) == 'الماده' || _norm(h) == 'المواد' || _norm(h) == 'اسم الماده');
    var cells = 0, unmatched = 0, bad = 0, unknownSubjects = 0;
    final touched = <int>{};

    Future<void> put(int sid, int subjectId, String col, String text) async {
      final t = text.trim();
      if (t.isEmpty) return;
      final v = double.tryParse(t);
      if (v == null || v < 0 || v > maxOf[col]!) {
        bad++;
        return;
      }
      await Db.saveGrade(sid, subjectId, col, v);
      cells++;
    }

    if (iSub >= 0) {
      final compCols = <int, String>{};
      for (var c = 0; c < head.length; c++) {
        final k = _comp(head[c]);
        if (k != null) compCols[c] = k;
      }
      if (compCols.isEmpty) return 'لم أجد أعمدة المحصلة والاختبار (مثل «المحصلة 1» و«اختبار 1»)';
      for (var k = 1; k < rows.length; k++) {
        final r = rows[k];
        final sid = sidOf(r);
        if (sid == null) {
          unmatched++;
          continue;
        }
        final sub = _matchSubject(_cell(r, iSub), subjects);
        if (sub == null) {
          unknownSubjects++;
          continue;
        }
        for (final e in compCols.entries) {
          await put(sid, sub['id'] as int, e.value, _cell(r, e.key));
        }
        touched.add(sid);
      }
    } else {
      final colMap = <int, (int, String)>{};
      for (var c = 0; c < head.length; c++) {
        final comp = _comp(head[c]);
        final sub = _matchSubject(head[c], subjects);
        if (comp != null && sub != null) colMap[c] = (sub['id'] as int, comp);
      }
      if (colMap.isEmpty) {
        return 'لم أتعرف على أعمدة المواد. اكتب العناوين بصيغة «الرياضيات - المحصلة 1» أو نزّل القالب من تبويب «النماذج».';
      }
      for (var k = 1; k < rows.length; k++) {
        final r = rows[k];
        final sid = sidOf(r);
        if (sid == null) {
          unmatched++;
          continue;
        }
        for (final e in colMap.entries) {
          await put(sid, e.value.$1, e.value.$2, _cell(r, e.key));
        }
        touched.add(sid);
      }
    }
    return 'تم تحديث $cells خانة لـ ${touched.length} طالب'
        '${unmatched > 0 ? ' • صفوف لم تُطابَق: $unmatched' : ''}'
        '${unknownSubjects > 0 ? ' • مواد غير معروفة: $unknownSubjects' : ''}'
        '${bad > 0 ? ' • قيم غير صالحة تم تجاهلها: $bad' : ''}';
  }

  // ---------- استيراد الدرجات الشهرية (مادة + شهر) ----------
  Future<String> _importMonthly(List<List<String>> rows) async {
    final sc = impScope;
    if (sc == null || sc.subjectId == null) return 'اختر الصف والمادة والشهر أولاً';
    if (rows.length < 2) return 'الملف فارغ';
    final cfg = await MonthlyCfg.load();
    final head = rows.first.map((e) => e.trim()).toList();
    final iReg = _idx(head, ['القيد', 'قيد']);
    final iName = _idx(head, ['الاسم', 'اسم']);
    if (iReg < 0 && iName < 0) return 'لم أجد عمود رقم القيد أو الاسم في الملف';
    const keys = ['hw', 'att', 'oral', 'written'];
    const fallback = ['واجب', 'مواظب', 'شفه', 'تحرير'];
    final cols = <int, int>{}; // عمود الملف -> رقم المكوّن 0..3
    for (var c = 0; c < head.length; c++) {
      final h = _norm(head[c]);
      for (var i = 0; i < 4; i++) {
        final label = _norm(cfg.labels[i]);
        if ((label.isNotEmpty && h.contains(label)) || h.contains(fallback[i])) {
          cols.putIfAbsent(c, () => i);
          break;
        }
      }
    }
    if (cols.isEmpty) {
      return 'لم أجد أعمدة المكونات (${cfg.labels.join('، ')}). نزّل القالب الشهري من تبويب «النماذج».';
    }
    final students = await Db.students(classId: sc.classId, section: sc.section);
    final byReg = {for (final s in students) '${s['reg_no']}': s['id'] as int};
    final byName = {for (final s in students) _norm('${s['name']}'): s['id'] as int};
    var cells = 0, unmatched = 0, bad = 0;
    final touched = <int>{};
    for (var k = 1; k < rows.length; k++) {
      final r = rows[k];
      final sid = byReg[_cell(r, iReg)] ?? byName[_norm(_cell(r, iName))];
      if (sid == null) {
        unmatched++;
        continue;
      }
      for (final e in cols.entries) {
        final t = _cell(r, e.key);
        if (t.isEmpty) continue;
        final v = double.tryParse(t);
        if (v == null || v < 0 || v > cfg.maxes[e.value]) {
          bad++;
          continue;
        }
        await Db.saveMonthly(sid, sc.subjectId!, sc.month, keys[e.value], v);
        cells++;
        touched.add(sid);
      }
    }
    return 'تم تحديث $cells خانة شهرية لـ ${touched.length} طالب'
        '${unmatched > 0 ? ' • صفوف لم تُطابَق: $unmatched' : ''}'
        '${bad > 0 ? ' • قيم غير صالحة تم تجاهلها: $bad' : ''}';
  }

  // ---------- قوالب جديدة ----------
  Future<void> _multiTemplate() async {
    final sc = tplMulti;
    if (sc == null) return toast(context, 'اختر الصف');
    final subjects = await Db.subjectsOf(sc.classId);
    final students = await Db.students(classId: sc.classId, section: sc.section);
    final d = await Db.get();
    final comps = <(String, String)>[
      if (tplSem != 1) ('t1_work', 'المحصلة 1'),
      if (tplSem != 1) ('t1_exam', 'اختبار 1'),
      if (tplSem != 0) ('t2_work', 'المحصلة 2'),
      if (tplSem != 0) ('t2_exam', 'اختبار 2'),
    ];
    final heads = [
      'رقم القيد', 'الاسم',
      for (final sub in subjects)
        for (final c in comps) '${sub['name']} - ${c.$2}',
    ];
    final rows = <List<String>>[];
    for (final st in students) {
      final row = ['${st['reg_no'] ?? ''}', '${st['name']}'];
      for (final sub in subjects) {
        final g = await d.query('grades',
            where: 'student_id=? AND subject_id=?', whereArgs: [st['id'], sub['id']]);
        for (final c in comps) {
          row.add(g.isEmpty ? '' : nf(g.first[c.$1] as num?));
        }
      }
      rows.add(row);
    }
    await exportTable(
        ExportTable('قالب_رصد_كل_المواد_${await Db.className(sc.classId)}', heads, rows),
        xlsx: true);
  }

  Future<void> _monthTemplate() async {
    final sc = tplMonth;
    if (sc == null || sc.subjectId == null) return toast(context, 'اختر الصف والمادة والشهر');
    final cfg = await MonthlyCfg.load();
    final rows0 = await Db.monthlyRows(sc.classId, sc.section, sc.subjectId!, sc.month);
    final heads = ['رقم القيد', 'الاسم', ...cfg.labels];
    final rows = [
      for (final r in rows0)
        ['${r['reg_no'] ?? ''}', '${r['name']}', nf(r['hw'] as num?), nf(r['att'] as num?),
          nf(r['oral'] as num?), nf(r['written'] as num?)]
    ];
    await exportTable(
        ExportTable('قالب_الدرجات_الشهرية_${await Db.className(sc.classId)}', heads, rows),
        xlsx: true);
  }

  Future<void> _gradeTemplate() async {
    final sc = tplScope;
    if (sc == null || sc.subjectId == null) return toast(context, 'اختر الصف والمادة');
    final rows0 = await Db.gradeRows(sc.classId, sc.section, sc.subjectId!);
    final rows = [
      for (final r in rows0)
        [
          '${r['reg_no'] ?? ''}', '${r['name']}', nf(r['t1_work'] as num?),
          nf(r['t1_exam'] as num?), nf(r['t2_work'] as num?), nf(r['t2_exam'] as num?),
        ]
    ];
    await exportTable(
        ExportTable('قالب_رصد_${await Db.className(sc.classId)}',
            ['رقم القيد', 'الاسم', 'المحصلة 1', 'اختبار 1', 'المحصلة 2', 'اختبار 2'], rows),
        xlsx: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مركز إكسل و CSV')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('تصدير'), icon: Icon(Icons.download)),
            ButtonSegment(value: 1, label: Text('استيراد'), icon: Icon(Icons.upload)),
            ButtonSegment(value: 2, label: Text('النماذج'), icon: Icon(Icons.table_chart)),
          ],
          selected: {tab},
          onSelectionChanged: (s) => setState(() => tab = s.first),
        ),
        const SizedBox(height: 14),
        if (tab == 0) ...[
          Text('تصدير التقارير والجداول المعتمدة',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('اختر نوع التقرير والصف للتصدير إلى Excel أو CSV.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          ReportPicker(onChanged: (s) => sel = s),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _customize,
              icon: const Icon(Icons.tune),
              label: Text(cols == null
                  ? 'تخصيص الترويسة والأعمدة'
                  : 'تخصيص الترويسة والأعمدة (${cols!.length} عمود)')),
          const SizedBox(height: 8),
          if (busy) const LinearProgressIndicator(),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: busy ? null : () => _export(true),
              icon: const Icon(Icons.table_chart),
              label: const Text('تصدير كملف Excel (.xlsx)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: busy ? null : () => _export(false),
              icon: const Icon(Icons.description_outlined),
              label: const Text('تصدير كملف CSV (.csv) بترميز UTF-8')),
          const SizedBox(height: 8),
          TextButton.icon(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit_note),
              label: const Text('فتح محرر الجداول التفاعلي لتعديل الأعمدة والصفوف مباشرة')),
        ],
        if (tab == 1) ...[
          Text('استيراد من Excel أو CSV', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('يُقبل xlsx وcsv. حمّل النموذج من تبويب «النماذج» لضمان ترتيب الأعمدة.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Pick<int>(
            label: 'ماذا تريد أن تستورد؟',
            value: importTarget,
            items: const [
              DropdownMenuItem(value: 0, child: Text('قائمة طلاب')),
              DropdownMenuItem(value: 1, child: Text('درجات مادة واحدة (فصلية)')),
              DropdownMenuItem(value: 2, child: Text('درجات عدة مواد في ملف واحد (فصلية)')),
              DropdownMenuItem(value: 3, child: Text('الدرجات الشهرية لمادة وشهر')),
            ],
            onChanged: (v) => setState(() => importTarget = v!),
          ),
          const SizedBox(height: 10),
          ScopeBar(
            key: ValueKey('imp$importTarget'),
            subject: importTarget == 1 || importTarget == 3,
            month: importTarget == 3,
            onChanged: (s) => impScope = s,
          ),
          const SizedBox(height: 6),
          Text(
              switch (importTarget) {
                0 => 'سيُضاف الطلاب إلى الصف المختار إن لم يحدد الملف عمود «الصف».',
                1 => 'أعمدة الملف: رقم القيد أو الاسم، ثم المحصلة 1 واختبار 1 والمحصلة 2 واختبار 2.',
                2 => 'عناوين الأعمدة «الرياضيات - المحصلة 1»، أو ملف طويل بعمود «المادة». '
                    'يُطابَق الطالب برقم القيد أو الاسم، ويُرفض أي رقم يتجاوز السقف.',
                _ => 'أعمدة الملف: رقم القيد أو الاسم، ثم أسماء المكونات الشهرية كما في الإعدادات.',
              },
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          FilledButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.upload_file),
              label: const Text('اختيار ملف وبدء الاستيراد')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _importEdit,
              icon: const Icon(Icons.edit_note),
              label: const Text('فتح الملف في المحرر وتعديله قبل الاستيراد')),
          if (log.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.primaryContainer.withOpacity(.4),
              child: Padding(padding: const EdgeInsets.all(14), child: Text(log)),
            ),
          ],
        ],
        if (tab == 2) ...[
          Text('نماذج جاهزة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('قالب الطلاب', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                        onPressed: () => _studentTemplate(true),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                        onPressed: () => _studentTemplate(false),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('CSV')),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('قالب رصد مادة بأسماء الطلاب',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ScopeBar(
                    key: const ValueKey('tpl'),
                    subject: true,
                    onChanged: (s) => tplScope = s),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                    onPressed: _gradeTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('تنزيل القالب (Excel)')),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('قالب رصد كل المواد في ملف واحد',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ScopeBar(key: const ValueKey('tplMulti'), onChanged: (s) => tplMulti = s),
                const SizedBox(height: 8),
                Pick<int>(
                  label: 'الفصل',
                  value: tplSem,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('الفصل الأول')),
                    DropdownMenuItem(value: 1, child: Text('الفصل الثاني')),
                    DropdownMenuItem(value: 2, child: Text('الفصلان معاً')),
                  ],
                  onChanged: (v) => setState(() => tplSem = v!),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                    onPressed: _multiTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('تنزيل القالب (Excel)')),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('قالب الدرجات الشهرية لمادة وشهر',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ScopeBar(
                    key: const ValueKey('tplMonth'),
                    subject: true,
                    month: true,
                    onChanged: (s) => tplMonth = s),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                    onPressed: _monthTemplate,
                    icon: const Icon(Icons.download),
                    label: const Text('تنزيل القالب (Excel)')),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
