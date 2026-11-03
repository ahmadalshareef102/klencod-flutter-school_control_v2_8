import 'dart:io';
import 'package:flutter/material.dart';
import '../data_io.dart';
import '../db.dart';
import '../form_cert.dart';
import '../pdf_reports.dart' show printPdf;
import '../widgets.dart';

/// عينة بيانات للمعاينة عند عدم وجود طلاب.
FormStudent _sample([FormStudent? real]) {
  const base = <String, String>{
    'gov': 'تعز', 'school': 'اسم المدرسة', 'year': '2025-2026',
    'class': 'الأول', 'name': 'اسم الطالب الرباعي', 'gender': 'ذكر',
    'nation': 'يمني', 'religion': 'مسلم', 'dob': '2018/05/12', 'pob': 'تعز',
    'regno': '1', 'total': '600', 'words': 'ستمائة', 'status': 'ناجح',
    'grade': 'ممتاز', 'percent': '100', 'rank': 'الأول',
    'principal': 'اسم المدير', 'control': 'رئيس الكنترول',
  };
  final v = Map<String, String>.from(base);
  real?.v.forEach((k, x) {
    if (x.isNotEmpty) v[k] = x;
  });
  final rows = (real != null && real.rows.isNotEmpty)
      ? real.rows
      : [for (var i = 0; i < 8; i++) ['20', '30', '50', '20', '30', '50', '100']];
  return FormStudent(real?.id ?? 0, v, rows);
}

/// معاينة الشهادة على لوحة 1175×1662 مصغّرة لتناسب المساحة.
class FormPreview extends StatelessWidget {
  final FormStudent? student;
  final FormLayout layout;
  final String bgPath;
  final bool showBg, showData, grid;
  const FormPreview({
    super.key,
    required this.student,
    required this.layout,
    required this.bgPath,
    this.showBg = true,
    this.showData = true,
    this.grid = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = showBg && bgPath.isNotEmpty && File(bgPath).existsSync();
    final px = layout.fontSize * kFormW / 595.28;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: kFormW,
        height: kFormH,
        child: Stack(children: [
          Positioned.fill(child: Container(color: Colors.white)),
          if (hasBg)
            Positioned.fill(
                child: Image.file(File(bgPath),
                    fit: BoxFit.fill,
                    cacheWidth: 1200,
                    errorBuilder: (_, __, ___) => const SizedBox())),
          if (grid) Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          if (showData && student != null)
            for (final p in layoutTexts(student!, layout))
              Positioned(
                left: p.left,
                top: p.top,
                width: p.w,
                height: kRowH,
                child: Align(
                  alignment: p.anchor == 'r'
                      ? Alignment.centerRight
                      : p.anchor == 'c'
                          ? Alignment.center
                          : Alignment.centerLeft,
                  child: Text(p.text,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: px,
                          color: Colors.black)),
                ),
              ),
        ]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = Colors.blueGrey.withOpacity(.18)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = Colors.blueGrey.withOpacity(.45)
      ..strokeWidth = 1.5;
    for (var x = 0.0; x <= size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), x % 100 == 0 ? thick : thin);
    }
    for (var y = 0.0; y <= size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), y % 100 == 0 ? thick : thin);
    }
    void label(String t, Offset o) {
      final tp = TextPainter(
          text: TextSpan(
              text: t, style: const TextStyle(fontSize: 18, color: Colors.black54)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, o);
    }

    for (var x = 100.0; x < size.width; x += 100) {
      label('${x.toInt()}', Offset(x + 2, 0));
    }
    for (var y = 100.0; y < size.height; y += 100) {
      label('${y.toInt()}', Offset(2, y + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ======================= شاشة المعاينة والطباعة =======================
class FormCertScreen extends StatefulWidget {
  final int? classId, studentId;
  const FormCertScreen({super.key, this.classId, this.studentId});
  @override
  State<FormCertScreen> createState() => _FormCertScreenState();
}

class _FormCertScreenState extends State<FormCertScreen> {
  List<DbRow> classes = [];
  int classId = 1;
  String? section;
  List<String> sections = [];
  List<FormStudent> list = [];
  int idx = 0;
  FormLayout layout = FormLayout();
  String bgPath = '';
  bool showBg = false, showData = true, loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    classes = await Db.classes();
    classId = widget.classId ?? (classes.isEmpty ? 1 : classes.first['id'] as int);
    await _loadSettings();
    await _loadStudents(selectId: widget.studentId);
  }

  Future<void> _loadSettings() async {
    layout = await FormLayout.load();
    bgPath = await Db.setting('form_bg');
    final sb = await Db.setting('form_show_bg');
    showBg = sb.isEmpty ? bgPath.isNotEmpty : sb == '1';
    showData = (await Db.setting('form_show_data')) != '0';
  }

  Future<void> _loadStudents({int? selectId}) async {
    setState(() => loading = true);
    final d = await Db.get();
    final s = await d.rawQuery(
        'SELECT DISTINCT section FROM students WHERE class_id=? ORDER BY section',
        [classId]);
    sections = [for (final r in s) '${r['section'] ?? ''}'].where((e) => e.isNotEmpty).toList();
    if (section != null && !sections.contains(section)) section = null;
    list = await loadFormStudents(classId, section: section);
    idx = 0;
    if (selectId != null) {
      final i = list.indexWhere((e) => e.id == selectId);
      if (i >= 0) idx = i;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _editor() async {
    final saved = await open<bool>(
        context, FormLayoutEditor(sample: list.isEmpty ? null : list[idx]));
    await _loadSettings();
    if (saved == true || mounted) setState(() {});
  }

  Future<void> _print(List<FormStudent> items, String name) async {
    if (items.isEmpty) return;
    setState(() => busy = true);
    try {
      final bytes = await buildFormPdf(items, layout, showBg: showBg, showData: showData);
      await printPdf(bytes, name);
    } catch (e) {
      if (mounted) toast(context, 'تعذرت الطباعة: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = list.isEmpty ? null : list[idx];
    return Scaffold(
      appBar: AppBar(title: const Text('شهادة على النموذج الرسمي'), actions: [
        IconButton(
            tooltip: 'ضبط المحاذاة والموضع',
            icon: const Icon(Icons.tune),
            onPressed: _editor),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(children: [
                  Expanded(
                    child: Pick<int>(
                      label: 'الصف',
                      value: classId,
                      items: [
                        for (final c in classes)
                          DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}'))
                      ],
                      onChanged: (v) {
                        classId = v!;
                        section = null;
                        _loadStudents();
                      },
                    ),
                  ),
                  if (sections.length > 1) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Pick<String?>(
                        label: 'الشعبة',
                        value: section,
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('الكل')),
                          for (final s in sections) DropdownMenuItem<String?>(value: s, child: Text(s)),
                        ],
                        onChanged: (v) {
                          section = v;
                          _loadStudents();
                        },
                      ),
                    ),
                  ],
                ]),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(.25),
                      borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: list.isEmpty
                      ? const Center(child: Text('لا يوجد طلاب في هذا الصف'))
                      : Stack(children: [
                          InteractiveViewer(
                            minScale: 1,
                            maxScale: 6,
                            child: Center(
                              child: FormPreview(
                                  student: cur,
                                  layout: layout,
                                  bgPath: bgPath,
                                  showBg: showBg,
                                  showData: showData),
                            ),
                          ),
                          const Positioned(
                              top: 6,
                              left: 8,
                              child: Chip(
                                  label: Text('اضغط بإصبعين للتكبير والتحريك',
                                      style: TextStyle(fontSize: 11)))),
                        ]),
                ),
              ),
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    IconButton(
                        onPressed: idx > 0 ? () => setState(() => idx--) : null,
                        icon: const Icon(Icons.chevron_right)),
                    Expanded(
                      child: Text('${idx + 1} / ${list.length}  •  ${cur!.v['name']}',
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                        onPressed: idx < list.length - 1 ? () => setState(() => idx++) : null,
                        icon: const Icon(Icons.chevron_left)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, children: [
                  FilterChip(
                    label: const Text('عرض البيانات'),
                    selected: showData,
                    onSelected: (v) {
                      setState(() => showData = v);
                      Db.setSetting('form_show_data', v ? '1' : '0');
                    },
                  ),
                  FilterChip(
                    label: const Text('عرض خلفية النموذج'),
                    selected: showBg,
                    onSelected: (v) {
                      setState(() => showBg = v);
                      Db.setSetting('form_show_bg', v ? '1' : '0');
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy || cur == null
                          ? null
                          : () => _print([cur], 'شهادة ${cur.v['name']}'),
                      icon: const Icon(Icons.print),
                      label: const Text('طباعة هذا الطالب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy || list.isEmpty
                          ? null
                          : () => _print(list, 'شهادات الصف'),
                      icon: const Icon(Icons.print_outlined),
                      label: Text('طباعة الكل (${list.length})'),
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }
}

// ======================= محرر ضبط المواضع =======================
class FormLayoutEditor extends StatefulWidget {
  final FormStudent? sample;
  const FormLayoutEditor({super.key, this.sample});
  @override
  State<FormLayoutEditor> createState() => _FormLayoutEditorState();
}

class _FormLayoutEditorState extends State<FormLayoutEditor> {
  FormLayout L = FormLayout();
  String initial = '';
  String bgPath = '';
  double step = 5;
  bool grid = true, showBg = true, loading = true;
  late final FormStudent sample = _sample(widget.sample);
  final gov = TextEditingController(),
      nation = TextEditingController(),
      religion = TextEditingController();

  bool get dirty => L.toJson() != initial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    L = await FormLayout.load();
    initial = L.toJson();
    bgPath = await Db.setting('form_bg');
    gov.text = await Db.setting('form_gov');
    nation.text = await Db.setting('form_nation');
    religion.text = await Db.setting('form_religion');
    if (mounted) setState(() => loading = false);
  }

  FormStudent get _live {
    final v = Map<String, String>.from(sample.v);
    if (gov.text.trim().isNotEmpty) v['gov'] = gov.text.trim();
    if (nation.text.trim().isNotEmpty) v['nation'] = nation.text.trim();
    if (religion.text.trim().isNotEmpty) v['religion'] = religion.text.trim();
    return FormStudent(sample.id, v, sample.rows);
  }

  void _mv(String id, double dx, double dy) =>
      setState(() => L.move(id, dx * step, dy * step));

  Widget _arrows(String id) {
    Widget b(String t, double dx, double dy) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  minimumSize: const Size(0, 40)),
              onPressed: () => _mv(id, dx, dy),
              child: Text(t, style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        b('←', -1, 0),
        b('↑', 0, -1),
        b('↓', 0, 1),
        b('→', 1, 0),
      ]),
    );
  }

  Widget _card(String id, String title, {bool? enabled, ValueChanged<bool>? onToggle}) {
    final o = L.offset(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('X: ${o[0].toInt()}px | Y: ${o[1].toInt()}px',
                      style: const TextStyle(fontSize: 11))),
            ),
            if (enabled != null)
              Switch(value: enabled, onChanged: onToggle),
          ]),
          const SizedBox(height: 4),
          _arrows(id),
        ]),
      ),
    );
  }

  Future<void> _pickBg() async {
    try {
      final p = await pickAndStoreImage('form_bg');
      if (p == null) return;
      await Db.setSetting('form_bg', p);
      await Db.setSetting('form_show_bg', '1');
      if (mounted) setState(() => bgPath = p);
    } catch (e) {
      if (mounted) toast(context, 'تعذر اختيار الصورة: $e');
    }
  }

  Future<void> _save() async {
    await L.save();
    await Db.setSetting('form_gov', gov.text.trim());
    await Db.setSetting('form_nation', nation.text.trim());
    await Db.setSetting('form_religion', religion.text.trim());
    if (!mounted) return;
    toast(context, 'تم حفظ الإعدادات');
    Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    if (!await confirmDialog(context, 'استعادة المواضع الافتراضية لكل الحقول؟',
        ok: 'استعادة')) {
      return;
    }
    setState(() => L = FormLayout());
    if (mounted) toast(context, 'تمت إعادة الضبط (معاينة) — اضغط حفظ لتثبيتها');
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final byGroup = <String, List<FormItem>>{};
    for (final i in kFormItems) {
      byGroup.putIfAbsent(i.group, () => []).add(i);
    }
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirmDialog(context, 'تجاهل التغييرات غير المحفوظة؟',
            ok: 'تجاهل', danger: true);
        if (ok && mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('ضبط مواضع الحقول'), actions: [
          IconButton(
              tooltip: 'الشبكة',
              icon: Icon(grid ? Icons.grid_on : Icons.grid_off),
              onPressed: () => setState(() => grid = !grid)),
        ]),
        body: Column(children: [
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(.25),
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: FormPreview(
                      student: _live,
                      layout: L,
                      bgPath: bgPath,
                      showBg: showBg,
                      showData: true,
                      grid: grid),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 8), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Text('التحريك: ${step.toInt()} Px',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                            min: 1,
                            max: 30,
                            divisions: 29,
                            value: step,
                            onChanged: (v) => setState(() => step = v)),
                      ),
                    ]),
                    Row(children: [
                      const Expanded(child: Text('حجم الخط')),
                      IconButton(
                          onPressed: () => setState(
                              () => L.fontSize = (L.fontSize - 0.5).clamp(6.0, 30.0).toDouble()),
                          icon: const Icon(Icons.remove_circle_outline)),
                      Text(L.fontSize.toStringAsFixed(1)),
                      IconButton(
                          onPressed: () => setState(
                              () => L.fontSize = (L.fontSize + 0.5).clamp(6.0, 30.0).toDouble()),
                          icon: const Icon(Icons.add_circle_outline)),
                    ]),
                    Row(children: [
                      const Expanded(child: Text('تباعد صفوف الجدول')),
                      IconButton(
                          onPressed: () => setState(
                              () => L.rowStep = (L.rowStep - 1).clamp(20.0, 60.0).toDouble()),
                          icon: const Icon(Icons.remove_circle_outline)),
                      Text(L.rowStep.toStringAsFixed(0)),
                      IconButton(
                          onPressed: () => setState(
                              () => L.rowStep = (L.rowStep + 1).clamp(20.0, 60.0).toDouble()),
                          icon: const Icon(Icons.add_circle_outline)),
                    ]),
                  ]),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              bgPath.isEmpty
                                  ? 'لا توجد صورة للنموذج (اختيارية)'
                                  : 'تم اختيار صورة النموذج',
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      TextButton.icon(
                          onPressed: _pickBg,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('اختيار')),
                      if (bgPath.isNotEmpty)
                        TextButton(
                            onPressed: () async {
                              await Db.setSetting('form_bg', '');
                              setState(() => bgPath = '');
                            },
                            child: const Text('إزالة')),
                    ]),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إظهار الصورة في المعاينة'),
                      value: showBg,
                      onChanged: (v) => setState(() => showBg = v),
                    ),
                    TextField(
                        controller: gov,
                        decoration: const InputDecoration(labelText: 'اسم المحافظة'),
                        onChanged: (_) => setState(() {})),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                            controller: nation,
                            decoration: const InputDecoration(
                                labelText: 'الجنسية', hintText: 'يمني'),
                            onChanged: (_) => setState(() {})),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                            controller: religion,
                            decoration: const InputDecoration(
                                labelText: 'الديانة', hintText: 'مسلم'),
                            onChanged: (_) => setState(() {})),
                      ),
                    ]),
                  ]),
                ),
              ),
              for (final g in kFormGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(g.$2,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary)),
                ),
                _card('g:${g.$1}', 'تحريك المجموعة كلها'),
                for (final i in byGroup[g.$1] ?? <FormItem>[])
                  _card(i.id, i.label,
                      enabled: L.enabled(i),
                      onToggle: (v) => setState(() => L.on[i.id] = v)),
              ],
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ التغييرات')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                      onPressed: _reset, child: const Text('استعادة الافتراضي')),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
