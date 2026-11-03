import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data_io.dart';
import '../dates.dart';
import '../db.dart';
import '../logic.dart';
import '../pdf_reports.dart';
import '../report_engine.dart';
import '../widgets.dart';

typedef _Field = (String, String, double);

class GradesTab extends StatefulWidget {
  const GradesTab({super.key});
  @override
  State<GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<GradesTab> {
  int sem = 0; // 0 الفصل الأول، 1 الفصل الثاني
  int mode = 0; // 0 شهري، 1 المحصلة، 2 الاختبار
  bool get monthly => mode == 0;
  int mFrom = 1, mTo = 12;
  Scope? scope;
  Rules? rules;
  MonthlyCfg? cfg;
  List<DbRow> rows = [];
  bool filtersOpen = true;
  bool keypad = true;

  // حالة لوحة الأرقام
  int? selId;
  String? selCol;
  String entry = '';
  bool fresh = true;
  final _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    Db.setting('keypad').then((v) {
      if (mounted) setState(() => keypad = v != '0');
    });
    _setSem(0);
  }

  Future<void> _load() async {
    final sc = scope;
    rules = await Rules.load();
    cfg = await MonthlyCfg.load();
    if (sc == null || sc.subjectId == null) {
      if (mounted) setState(() => rows = []);
      return;
    }
    final raw = monthly
        ? await Db.monthlyRows(sc.classId, sc.section, sc.subjectId!, sc.month)
        : await Db.gradeRows(sc.classId, sc.section, sc.subjectId!);
    rows = [for (final e in raw) Map<String, Object?>.from(e)];
    selId = null;
    selCol = null;
    if (mounted) setState(() {});
  }

  List<_Field> get fields {
    final r = rules, c = cfg;
    if (r == null || c == null) return [];
    if (monthly) {
      return [
        ('hw', c.labels[0], c.hw), ('att', c.labels[1], c.att),
        ('oral', c.labels[2], c.oral), ('written', c.labels[3], c.written),
      ];
    }
    final _Field w = sem == 0
        ? ('t1_work', 'المحصلة (من الأشهر)', r.maxW1)
        : ('t2_work', 'المحصلة (من الأشهر)', r.maxW2);
    final _Field e = sem == 0
        ? ('t1_exam', 'اختبار المنتصف', r.maxE1)
        : ('t2_exam', 'اختبار نهاية الفصل', r.maxE2);
    return mode == 1 ? [w] : [e];
  }

  /// يضبط الفصل ونطاق أشهره من الإعدادات.
  Future<void> _setSem(int v) async {
    sem = v;
    final f = int.tryParse(await Db.setting('sem${v + 1}_from')) ?? 1;
    final t = int.tryParse(await Db.setting('sem${v + 1}_to')) ?? 12;
    mFrom = f.clamp(1, 12).toInt();
    mTo = (t < f ? f : t).clamp(1, 12).toInt();
    selId = null;
    if (mounted) setState(() {});
  }

  double _sum(DbRow r) => fields.fold<double>(
      0, (a, f) => a + ((r[f.$1] as num?)?.toDouble() ?? 0));
  double get _maxSum => fields.fold<double>(0, (a, f) => a + f.$3);

  // ---------------- حفظ قيمة ----------------
  void _store(DbRow r, String col, double? v) {
    final sc = scope!;
    setState(() => r[col] = v);
    if (monthly) {
      Db.saveMonthly(r['id'] as int, sc.subjectId!, sc.month, col, v);
    } else {
      Db.saveGrade(r['id'] as int, sc.subjectId!, col, v);
    }
  }

  void _onChange(DbRow r, _Field f, String t) {
    double? v;
    if (t.trim().isNotEmpty) {
      v = double.tryParse(t.trim());
      if (v == null || v < 0 || v > f.$3) {
        toast(context, 'الدرجة يجب أن تكون بين 0 و ${nf(f.$3)}');
        return;
      }
    }
    _store(r, f.$1, v);
  }

  // ---------------- لوحة الأرقام ----------------
  DbRow? get _selRow {
    for (final r in rows) {
      if (r['id'] == selId) return r;
    }
    return null;
  }

  _Field? get _selField {
    for (final f in fields) {
      if (f.$1 == selCol) return f;
    }
    return null;
  }

  void _select(DbRow r, String col) {
    final v = r[col] as num?;
    setState(() {
      selId = r['id'] as int;
      selCol = col;
      entry = v == null ? '' : nf(v);
      fresh = true;
      filtersOpen = false;
    });
    final key = _keys[selId!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.1, duration: const Duration(milliseconds: 200));
      }
    });
  }

  void _commit() {
    final r = _selRow, col = selCol;
    if (r == null || col == null) return;
    final v = entry.isEmpty ? null : double.tryParse(entry);
    _store(r, col, v);
  }

  void _digit(String d) {
    final f = _selField;
    if (f == null) return;
    var e = fresh ? '' : entry;
    if (d == '.') {
      if (e.contains('.')) return;
      if (e.isEmpty) e = '0';
      e += '.';
    } else {
      e += d;
    }
    final v = double.tryParse(e);
    if (v != null && v > f.$3) {
      toast(context, 'الحد الأقصى ${nf(f.$3)}');
      return;
    }
    setState(() {
      entry = e;
      fresh = false;
    });
    _commit();
  }

  void _backspace() {
    if (entry.isEmpty) return;
    setState(() {
      entry = entry.substring(0, entry.length - 1);
      fresh = false;
    });
    _commit();
  }

  void _clear() {
    setState(() {
      entry = '';
      fresh = false;
    });
    _commit();
  }

  void _absent() {
    setState(() {
      entry = '0';
      fresh = false;
    });
    _commit();
    _nextField();
  }

  void _nextField() {
    final r = _selRow;
    if (r == null) return;
    final fs = fields;
    final i = fs.indexWhere((f) => f.$1 == selCol);
    if (i >= 0 && i + 1 < fs.length) {
      _select(r, fs[i + 1].$1);
    } else {
      _nextStudent(first: true);
    }
  }

  void _nextStudent({bool first = false}) {
    final i = rows.indexWhere((r) => r['id'] == selId);
    if (i < 0 || i + 1 >= rows.length) {
      setState(() => selId = null);
      return;
    }
    _select(rows[i + 1], first ? fields.first.$1 : (selCol ?? fields.first.$1));
  }

  Widget _key(String label, VoidCallback f,
      {Color? bg, Color? fg, bool outlined = false}) {
    final child = Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox(
          height: 44,
          child: outlined
              ? OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: fg),
                  onPressed: f,
                  child: child)
              : FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: bg ?? Theme.of(context).colorScheme.primary,
                      foregroundColor: fg ?? Theme.of(context).colorScheme.onPrimary,
                      padding: EdgeInsets.zero),
                  onPressed: f,
                  child: child),
        ),
      ),
    );
  }

  Widget _keypadPanel() {
    final cs = Theme.of(context).colorScheme;
    final r = _selRow, f = _selField;
    if (r == null || f == null) return const SizedBox();
    Widget digitRow(List<Widget> kids) => Row(children: kids);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(0, 48)),
              onPressed: () => setState(() => selId = null),
              child: const Text('تم'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${f.$2} (الدرجة القصوى: ${nf(f.$3)})',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
                color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Text(entry.isEmpty ? '0' : entry,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final x in fields)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: SizedBox(
                      width: double.infinity,
                      child: Text('${x.$2} (${nf(x.$3)})',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11))),
                  selected: selCol == x.$1,
                  onSelected: (_) => _select(r, x.$1),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 2),
        digitRow([
          _key('1', () => _digit('1')), _key('2', () => _digit('2')),
          _key('3', () => _digit('3')),
          _key('غائب', _absent, outlined: true, fg: Colors.red),
        ]),
        digitRow([
          _key('4', () => _digit('4')), _key('5', () => _digit('5')),
          _key('6', () => _digit('6')),
          _key('حذف', _backspace, outlined: true, fg: cs.primary),
        ]),
        digitRow([
          _key('7', () => _digit('7')), _key('8', () => _digit('8')),
          _key('9', () => _digit('9')),
          _key('تفريغ', _clear, outlined: true, fg: cs.primary),
        ]),
        digitRow([
          _key('.', () => _digit('.')), _key('0', () => _digit('0')),
          _key('الحقل التالي', _nextField),
          _key('الطالب التالي', () => _nextStudent(), bg: cs.primary, fg: cs.onPrimary),
        ]),
      ]),
    );
  }

  // ---------------- قائمة الخيارات ----------------
  Future<void> _menu() async {
    final v = await showOptions<String>(
        context,
        monthly ? 'خيارات الرصد الشهري' : 'خيارات الرصد الفصلي',
        [
          Opt(Icons.dialpad, keypad ? 'إيقاف لوحة الأرقام' : 'تفعيل لوحة الأرقام',
              'keypad', 'الكتابة بلوحة أرقام مخصصة بدل لوحة المفاتيح'),
          const Opt(Icons.print, 'طباعة كشف الرصد (PDF)', 'print'),
          const Opt(Icons.ios_share, 'مشاركة PDF', 'share'),
          const Opt(Icons.table_chart, 'تصدير Excel (xlsx)', 'xlsx'),
          const Opt(Icons.description_outlined, 'تصدير CSV', 'csv'),
          if (!monthly)
            const Opt(Icons.swap_vert, 'ترحيل الشهري إلى المحصلة', 'transfer',
                'متوسط الدرجات الشهرية المحوّلة'),
          const Opt(Icons.cleaning_services_outlined, 'تصفير الدرجات المعروضة', 'reset'),
        ]);
    if (v == null || !mounted) return;
    if (v == 'keypad') {
      setState(() {
        keypad = !keypad;
        selId = null;
      });
      await Db.setSetting('keypad', keypad ? '1' : '0');
      return;
    }
    final sc = scope;
    if (sc == null || sc.subjectId == null) return toast(context, 'اختر المادة أولاً');
    try {
      switch (v) {
        case 'print':
        case 'share':
        case 'xlsx':
        case 'csv':
          final data = await buildReport(
              monthly ? RKind.monthlySheet : RKind.gradeSheet, sc,
              semester: sem);
          if (v == 'print') await printPdf(await data.pdf(), data.table.title);
          if (v == 'share') {
            await printPdf(await data.pdf(), data.table.title, share: true);
          }
          if (v == 'xlsx') await exportTable(data.table, xlsx: true);
          if (v == 'csv') await exportTable(data.table, xlsx: false);
        case 'transfer':
          await _transfer();
        case 'reset':
          await _reset();
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر التنفيذ: $e');
    }
  }

  Future<void> _reset() async {
    final sc = scope!;
    if (!await confirmDialog(context, 'تصفير الدرجات المعروضة للصف والمادة المحددين؟',
        ok: 'تصفير', danger: true)) {
      return;
    }
    final d = await Db.get();
    final sec = sc.section == null ? '' : ' AND section=?';
    final args = <Object?>[sc.subjectId, sc.classId, if (sc.section != null) sc.section];
    if (monthly) {
      await d.rawDelete(
          'DELETE FROM monthly WHERE subject_id=? AND month=${sc.month} AND student_id IN '
          '(SELECT id FROM students WHERE class_id=?$sec)',
          args);
    } else {
      await d.rawDelete(
          'DELETE FROM grades WHERE subject_id=? AND student_id IN '
          '(SELECT id FROM students WHERE class_id=?$sec)',
          args);
    }
    _load();
  }

  Future<void> _transfer() async {
    final sc = scope!;
    final r0 = <int>[];
    for (final k in ['sem1_from', 'sem1_to', 'sem2_from', 'sem2_to']) {
      r0.add(int.tryParse(await Db.setting(k)) ?? 1);
    }
    var target = 0;
    var from = r0[0], to = r0[1];
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('ترحيل الشهري إلى المحصلة'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Pick<int>(
              label: 'الهدف',
              value: target,
              items: const [
                DropdownMenuItem(value: 0, child: Text('المحصلة - الفصل الأول')),
                DropdownMenuItem(value: 1, child: Text('المحصلة - الفصل الثاني')),
              ],
              onChanged: (v) => set(() {
                target = v!;
                from = r0[target * 2];
                to = r0[target * 2 + 1];
              }),
            ),
            const SizedBox(height: 8),
            Pick<int>(
              label: 'من شهر',
              value: from,
              items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthName(m, AppState.hijri.value)))],
              onChanged: (v) => set(() => from = v!),
            ),
            const SizedBox(height: 8),
            Pick<int>(
              label: 'إلى شهر',
              value: to,
              items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthName(m, AppState.hijri.value)))],
              onChanged: (v) => set(() => to = v!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ترحيل')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final c = cfg!, r = rules!;
    final d = await Db.get();
    final students = await Db.students(classId: sc.classId, section: sc.section);
    var n = 0;
    for (final s in students) {
      final ms = await d.query('monthly',
          where: 'student_id=? AND subject_id=? AND month BETWEEN ? AND ?',
          whereArgs: [s['id'], sc.subjectId, from, to]);
      final vals = <double>[];
      for (final m in ms) {
        final v = [m['hw'], m['att'], m['oral'], m['written']].map((e) => e as num?).toList();
        if (v.any((e) => e != null)) {
          vals.add(c.convert(v.fold<double>(0, (a, e) => a + (e ?? 0))));
        }
      }
      if (vals.isEmpty) continue;
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      final max = target == 0 ? r.maxW1 : r.maxW2;
      final scaled = double.parse((avg / c.convertTo * max).toStringAsFixed(1));
      await Db.saveGrade(s['id'] as int, sc.subjectId!, target == 0 ? 't1_work' : 't2_work', scaled);
      n++;
    }
    if (mounted) toast(context, 'تم ترحيل متوسط الشهري لـ $n طالب');
  }

  // ---------------- الواجهة ----------------
  Widget _fieldBox(DbRow r, _Field f, ColorScheme cs) {
    final selected = selId == r['id'] && selCol == f.$1;
    final v = r[f.$1] as num?;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${f.$2} (${nf(f.$3)})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _select(r, f.$1),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withOpacity(.25)
                    : cs.surfaceContainerHighest.withOpacity(.5),
                border: selected ? Border.all(color: cs.primary, width: 2) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(v == null ? '0' : nf(v),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: v == null ? cs.onSurface.withOpacity(.4) : null)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fs = fields;
    final c = cfg;
    final showPad = keypad && selId != null;
    return Column(children: [
      PageHeader('رصد درجات الطلاب',
          subtitle:
              '${sem == 0 ? 'الفصل الدراسي الأول' : 'الفصل الدراسي الثاني'} • ${mode == 0 ? 'الشهري' : mode == 1 ? 'المحصلة' : 'الاختبار'}',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Chip(label: Text('${rows.length} طالب'), backgroundColor: cs.primaryContainer),
            IconButton(
                icon: Icon(filtersOpen ? Icons.expand_less : Icons.expand_more),
                onPressed: () => setState(() => filtersOpen = !filtersOpen)),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: _menu),
          ])),
      Offstage(
        offstage: !filtersOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text('الفصل الدراسي النشط',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary)),
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('الفصل الأول')),
                ButtonSegment(value: 1, label: Text('الفصل الثاني')),
              ],
              selected: {sem},
              onSelectionChanged: (s) async {
                await _setSem(s.first);
                _load();
              },
            ),
            const SizedBox(height: 10),
            ScopeBar(
              key: ValueKey('$sem-$mFrom-$mTo-$monthly'),
              subject: true,
              month: monthly,
              monthFrom: mFrom,
              monthTo: mTo,
              onChanged: (s) {
                scope = s;
                _load();
              },
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    label: Text('الشهري (${c == null ? '100' : nf(c.total)}→${c == null ? '20' : nf(c.convertTo)})')),
                ButtonSegment(
                    value: 1, label: Text('المحصلة (${rules == null ? '' : nf(sem == 0 ? rules!.maxW1 : rules!.maxW2)})')),
                ButtonSegment(
                    value: 2, label: Text('الاختبار (${rules == null ? '' : nf(sem == 0 ? rules!.maxE1 : rules!.maxE2)})')),
              ],
              selected: {mode},
              onSelectionChanged: (s) {
                mode = s.first;
                selId = null;
                _load();
              },
            ),
            if (monthly && c != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${c.labels.join(' + ')} = ${nf(c.total)} تتحول إلى ${nf(c.convertTo)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: rows.isEmpty
            ? const Center(child: Text('لا يوجد طلاب في هذا الاختيار'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  for (final r in rows) ...[
                    KeyedSubtree(
                      key: _keys.putIfAbsent(r['id'] as int, () => GlobalKey()),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                              color: selId == r['id'] ? cs.primary : Colors.transparent,
                              width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Chip(
                                  label: Text('${r['reg_no'] ?? ''}'),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: cs.primaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text('${r['name']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold))),
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(monthly && c != null
                                    ? 'المحوّلة: ${nf(c.convert(_sum(r)))}/${nf(c.convertTo)}'
                                    : 'المجموع: ${nf(_sum(r))}/${nf(_maxSum)}'),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (final f in fs)
                                if (keypad)
                                  _fieldBox(r, f, cs)
                                else
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: TextFormField(
                                        key: ValueKey(
                                            '${r['id']}-${f.$1}-${scope?.subjectId}-${scope?.month}-$mode-$sem'),
                                        initialValue: nf(r[f.$1] as num?),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        textAlign: TextAlign.center,
                                        decoration: InputDecoration(
                                            labelText: '${f.$2} (${nf(f.$3)})',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 10)),
                                        onChanged: (t) => _onChange(r, f, t),
                                      ),
                                    ),
                                  ),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
      if (showPad)
        _keypadPanel()
      else
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(.4),
              border: Border(top: BorderSide(color: cs.outlineVariant))),
          child: Row(children: [
            Expanded(
                child: Text('تم تحميل ${rows.length} طالب - ${sem == 0 ? 'الفصل الأول' : 'الفصل الثاني'}',
                    style: Theme.of(context).textTheme.bodySmall)),
            FilledButton.icon(
                onPressed: () => toast(context, 'تم حفظ جميع الدرجات'),
                icon: const Icon(Icons.check),
                label: const Text('حفظ')),
          ]),
        ),
    ]);
  }
}
