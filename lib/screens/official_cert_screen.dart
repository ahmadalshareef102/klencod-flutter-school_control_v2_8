import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../data_io.dart';
import '../db.dart';
import '../official_cert.dart';
import '../pdf_reports.dart';
import '../widgets.dart';

// ====================================================== معاينة صفحة A4 بالبكسل
class OfficialPageView extends StatelessWidget {
  final OStudent student;
  final OLayout layout;
  final String face; // f / b
  final String bgPath;
  final bool grid;
  final String? selected;
  const OfficialPageView({
    super.key,
    required this.student,
    required this.layout,
    required this.face,
    this.bgPath = '',
    this.grid = false,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final items = drawItems(student, layout, face);
    final hasBg = bgPath.isNotEmpty && File(bgPath).existsSync();
    return AspectRatio(
      aspectRatio: kPageW / kPageH,
      child: Container(
        color: Colors.white,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: kPageW,
            height: kPageH,
            child: Stack(children: [
              if (hasBg)
                Positioned.fill(
                    child: Image.file(File(bgPath),
                        fit: BoxFit.fill,
                        cacheWidth: 1000,
                        errorBuilder: (_, __, ___) => const SizedBox())),
              if (grid) Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              for (final it in items)
                Positioned(
                  left: it.x,
                  top: it.y,
                  child: SizedBox(
                    width: it.w,
                    child: Container(
                      decoration: it.id == selected
                          ? BoxDecoration(
                              color: Colors.red.withOpacity(.12),
                              border: Border.all(color: Colors.red, width: 2))
                          : null,
                      child: Text(it.text,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          textDirection: it.ltr ? TextDirection.ltr : TextDirection.rtl,
                          textAlign: it.align == 'r'
                              ? TextAlign.right
                              : it.align == 'l'
                                  ? TextAlign.left
                                  : TextAlign.center,
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Colors.black,
                              height: 1.25,
                              fontSize: layout.fontPx,
                              fontWeight: layout.bold ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final thin = Paint()
      ..color = Colors.grey.withOpacity(.25)
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = Colors.grey.withOpacity(.6)
      ..strokeWidth = 2;
    void label(String t, double x, double y) {
      final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(fontSize: 20, color: Colors.grey.shade700)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x, y));
    }

    for (var x = 0.0; x <= kPageW; x += 50) {
      final big = x % 100 == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, kPageH), big ? thick : thin);
      if (big && x > 0) label('${x.toInt()}', x + 3, 2);
    }
    for (var y = 0.0; y <= kPageH; y += 50) {
      final big = y % 100 == 0;
      canvas.drawLine(Offset(0, y), Offset(kPageW, y), big ? thick : thin);
      if (big && y > 0) label('${y.toInt()}', 3, y + 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ====================================================== الشاشة الرئيسية
class OfficialCertScreen extends StatefulWidget {
  const OfficialCertScreen({super.key});
  @override
  State<OfficialCertScreen> createState() => _OfficialCertScreenState();
}

class _OfficialCertScreenState extends State<OfficialCertScreen> {
  List<DbRow> classes = [];
  int classId = 1;
  String? section;
  List<String> sections = [];
  List<OStudent> list = [];
  int idx = 0;
  bool loading = true;
  String face = 'f';
  bool showBg = true;
  OLayout lay = OLayout();
  String bgF = '', bgB = '';

  OStudent get cur => list.isEmpty ? OStudent.sample() : list[idx];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    classes = await Db.classes();
    if (classes.isNotEmpty) classId = classes.first['id'] as int;
    lay = await OLayout.load();
    await _loadBg();
    await _load();
  }

  Future<void> _loadBg() async {
    bgF = await Db.setting('official_bg_front');
    bgB = await Db.setting('official_bg_back');
  }

  Future<void> _load() async {
    setState(() => loading = true);
    sections = await Db.sectionsOf(classId);
    if (section != null && !sections.contains(section)) section = null;
    list = await loadOfficial(classId, section: section);
    idx = 0;
    if (mounted) setState(() => loading = false);
  }

  void _go(int d) {
    if (list.isEmpty) return;
    setState(() => idx = (idx + d).clamp(0, list.length - 1));
  }

  Future<void> _editor() async {
    final r = await open<OLayout>(
        context,
        OfficialEditor(student: cur, layout: lay, bgF: bgF, bgB: bgB));
    if (r != null) setState(() => lay = r);
  }

  Future<void> _pickStudent() async {
    if (list.isEmpty) return;
    final v = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .75),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (_, i) => ListTile(
              selected: i == idx,
              leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))),
              title: Text(list[i].name),
              onTap: () => Navigator.pop(ctx, i),
            ),
          ),
        ),
      ),
    );
    if (v != null) setState(() => idx = v);
  }

  Future<void> _print() async {
    final v = await showOptions<String>(context, 'طباعة الشهادة', const [
      Opt(Icons.person_outline, 'هذا الطالب — الوجه الأمامي', 'cf'),
      Opt(Icons.flip, 'هذا الطالب — الوجهان (أمامي وخلفي)', 'cb'),
      Opt(Icons.flip_to_back, 'هذا الطالب — الوجه الخلفي فقط', 'cx'),
      Opt(Icons.groups_outlined, 'كل طلاب الفصل — الوجه الأمامي', 'af'),
      Opt(Icons.groups_2_outlined, 'كل طلاب الفصل — الوجهان', 'ab'),
    ]);
    if (v == null) return;
    final all = v.startsWith('a');
    final data = all ? list : [cur];
    if (data.isEmpty) return toast(context, 'لا يوجد طلاب');
    try {
      final bytes = await buildOfficialPdf(data, lay,
          front: v[1] != 'x', back: v[1] == 'b' || v[1] == 'x', bg: showBg);
      await printPdf(bytes, all ? 'الشهادات الرسمية' : 'شهادة ${cur.name}');
    } catch (e) {
      if (mounted) toast(context, 'تعذرت الطباعة: $e');
    }
  }

  Future<void> _settings() async {
    const fields = <(String, String)>[
      ('official_gov', 'اسم المحافظة'),
      ('official_nat', 'الجنسية (الافتراضي: يمني)'),
      ('official_rel', 'الديانة (الافتراضي: مسلم)'),
      ('official_year', 'العام الدراسي الميلادي (مثل 2025-2026)'),
      ('official_hijri', 'العام الهجري (مثل 1447هـ)'),
    ];
    final ctrls = <String, TextEditingController>{};
    for (final f in fields) {
      ctrls[f.$1] = TextEditingController(text: await Db.setting(f.$1));
    }
    var f1 = bgF, f2 = bgB;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget imgRow(String title, String path, String key, void Function(String) assign) =>
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: path.isNotEmpty && File(path).existsSync()
                    ? Image.file(File(path), width: 40, height: 56, fit: BoxFit.cover, cacheWidth: 120)
                    : const Icon(Icons.image_outlined),
                title: Text(title),
                subtitle: Text(path.isEmpty ? 'لم تُحدد' : 'تم الاختيار'),
                trailing: Wrap(children: [
                  IconButton(
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: () async {
                        final p = await pickAndStoreImage(key);
                        if (p != null) set(() => assign(p));
                      }),
                  if (path.isNotEmpty)
                    IconButton(icon: const Icon(Icons.close), onPressed: () => set(() => assign(''))),
                ]),
              );
          return AlertDialog(
            title: const Text('إعدادات الشهادة الرسمية'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                        controller: ctrls[f.$1], decoration: InputDecoration(labelText: f.$2)),
                  ),
                const Divider(),
                imgRow('صورة النموذج — الوجه الأمامي', f1, 'obg_front', (p) => f1 = p),
                imgRow('صورة النموذج — الوجه الخلفي', f2, 'obg_back', (p) => f2 = p),
                const Text('تُستخدم صورة النموذج للمعاينة وضبط المواضع، ويمكن إيقافها عند الطباعة على الورقة الجاهزة.',
                    style: TextStyle(fontSize: 12)),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    for (final f in fields) {
      await Db.setSetting(f.$1, ctrls[f.$1]!.text.trim());
    }
    await Db.setSetting('official_bg_front', f1);
    await Db.setSetting('official_bg_back', f2);
    await _loadBg();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = face == 'f' ? bgF : bgB;
    return Scaffold(
      appBar: AppBar(title: const Text('الشهادة الرسمية على النموذج'), actions: [
        IconButton(
            tooltip: 'إعدادات الشهادة', icon: const Icon(Icons.settings), onPressed: _settings),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              Row(children: [
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
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pick<String?>(
                    label: 'الشعبة',
                    value: section,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('كل الشعب')),
                      for (final s in sections) DropdownMenuItem<String?>(value: s, child: Text(s)),
                    ],
                    onChanged: (v) {
                      section = v;
                      _load();
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (list.isEmpty)
                Card(
                    color: cs.tertiaryContainer,
                    child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('لا يوجد طلاب في هذا الصف. المعروض نموذج تجريبي لضبط المواضع.'))),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: cs.primaryContainer,
                    child: Row(children: [
                      Expanded(
                          child: Text(cur.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold))),
                      Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(list.isEmpty ? '-' : '${idx + 1} / ${list.length}')),
                    ]),
                  ),
                  Container(
                    color: Colors.grey.shade300,
                    padding: const EdgeInsets.all(8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: OfficialPageView(
                            student: cur,
                            layout: lay,
                            face: face,
                            bgPath: showBg ? path : ''),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(children: [
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          title: Text(face == 'f' ? 'وجه أمامي' : 'وجه خلفي'),
                          value: face == 'b',
                          onChanged: (v) => setState(() => face = v ? 'b' : 'f'),
                        ),
                      ),
                      Expanded(
                        child: SwitchListTile(
                          dense: true,
                          title: const Text('خلفية'),
                          value: showBg,
                          onChanged: (v) => setState(() => showBg = v),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(
                  'الطباعة تتبع مفتاح «خلفية»: أوقفه لطباعة البيانات فقط على الورقة الرسمية الجاهزة، وفعّله لطباعة النموذج مع البيانات.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('التنقل بين الطلاب', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                            onPressed: list.isEmpty || idx == 0 ? null : () => _go(-1),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('السابق')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                            onPressed: list.isEmpty || idx >= list.length - 1 ? null : () => _go(1),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('التالي')),
                      ),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _editor,
                        icon: const Icon(Icons.open_with),
                        label: const Text('المحاذاة'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: _pickStudent,
                        icon: const Icon(Icons.groups_outlined),
                        label: const Text('قائمة الطلاب'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: _print,
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة'))),
              ]),
            ]),
    );
  }
}

// ====================================================== محرر المواضع
class OfficialEditor extends StatefulWidget {
  final OStudent student;
  final OLayout layout;
  final String bgF, bgB;
  const OfficialEditor(
      {super.key,
      required this.student,
      required this.layout,
      required this.bgF,
      required this.bgB});
  @override
  State<OfficialEditor> createState() => _OfficialEditorState();
}

class _OfficialEditorState extends State<OfficialEditor> {
  late OLayout lay = widget.layout.copy();
  double step = 6;
  String face = 'f';
  bool bg = true;
  String? sel;

  Future<void> _save() async {
    await lay.save();
    if (!mounted) return;
    toast(context, 'تم حفظ المواضع');
    Navigator.pop(context, lay);
  }

  Future<void> _reset() async {
    if (!await confirmDialog(context, 'استعادة المواضع الافتراضية لكل الحقول؟', ok: 'استعادة')) {
      return;
    }
    setState(() {
      lay = OLayout();
      toast(context, 'تمت إعادة الضبط (معاينة) — اضغط حفظ لتثبيتها');
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final els = kElements.where((e) => e.face == face).toList();
    final groups = kGroups.keys.where((g) => els.any((e) => e.group == g)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المحاذاة وضبط المواضع')),
      body: Column(children: [
        Container(
          height: h * .40,
          width: double.infinity,
          color: Colors.grey.shade300,
          padding: const EdgeInsets.all(6),
          child: Center(
            child: OfficialPageView(
              student: widget.student,
              layout: lay,
              face: face,
              grid: true,
              selected: sel,
              bgPath: bg ? (face == 'f' ? widget.bgF : widget.bgB) : '',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(children: [
            Text('التحريك: ${step.round()} px'),
            Expanded(
              child: Slider(
                  min: 1, max: 50, divisions: 49, value: step,
                  onChanged: (v) => setState(() => step = v)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ التغييرات')),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FilledButton.tonal(onPressed: _reset, child: const Text('استعادة الافتراضي')),
            ),
            Switch(value: bg, onChanged: (v) => setState(() => bg = v)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'f', label: Text('الوجه الأمامي')),
              ButtonSegment(value: 'b', label: Text('الوجه الخلفي')),
            ],
            selected: {face},
            onSelectionChanged: (s) => setState(() {
              face = s.first;
              sel = null;
            }),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Row(children: [
                    Text('حجم الخط: ${lay.fontPx.round()}'),
                    Expanded(
                      child: Slider(
                          min: 14, max: 40, divisions: 26, value: lay.fontPx.clamp(14, 40).toDouble(),
                          onChanged: (v) => setState(() => lay.fontPx = v)),
                    ),
                  ]),
                  if (face == 'f')
                    Row(children: [
                      Text('تباعد صفوف الجدول: ${lay.rowPitch.toStringAsFixed(1)}'),
                      Expanded(
                        child: Slider(
                            min: 25, max: 50, divisions: 50, value: lay.rowPitch.clamp(25, 50).toDouble(),
                            onChanged: (v) => setState(() => lay.rowPitch = v)),
                      ),
                    ]),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('خط عريض'),
                    value: lay.bold,
                    onChanged: (v) => setState(() => lay.bold = v),
                  ),
                ]),
              ),
            ),
            for (final g in groups)
              _MoveCard(
                title: kGroups[g]!,
                info: 'X: ${(lay.grp[g]?.dx ?? 0).round()} px | Y: ${(lay.grp[g]?.dy ?? 0).round()} px',
                onMove: (dx, dy) => setState(() => lay.moveGroup(g, dx * step, dy * step)),
              ),
            for (final e in els)
              _MoveCard(
                title: e.label,
                info: 'X: ${lay.basePos(e).dx.round()} px | Y: ${lay.basePos(e).dy.round()} px',
                selected: sel == e.id,
                on: lay.on(e),
                onOn: (v) => setState(() => lay.vis[e.id] = v),
                onTap: () => setState(() => sel = e.id),
                onMove: (dx, dy) => setState(() {
                  sel = e.id;
                  lay.move(e, dx * step, dy * step);
                }),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _MoveCard extends StatelessWidget {
  final String title, info;
  final bool selected;
  final bool? on;
  final ValueChanged<bool>? onOn;
  final VoidCallback? onTap;
  final void Function(int dx, int dy) onMove;
  const _MoveCard({
    required this.title,
    required this.info,
    required this.onMove,
    this.selected = false,
    this.on,
    this.onOn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? Colors.red : cs.outlineVariant, width: selected ? 2 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
              if (on != null) Switch(value: on!, onChanged: onOn),
            ]),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(visualDensity: VisualDensity.compact, label: Text(info)),
            ),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                _Rep(Icons.west, () => onMove(-1, 0)),
                _Rep(Icons.north, () => onMove(0, -1)),
                _Rep(Icons.south, () => onMove(0, 1)),
                _Rep(Icons.east, () => onMove(1, 0)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// زر سهم: ضغطة = خطوة، والضغط المطوّل = تكرار سريع.
class _Rep extends StatefulWidget {
  final IconData icon;
  final VoidCallback onStep;
  const _Rep(this.icon, this.onStep);
  @override
  State<_Rep> createState() => _RepState();
}

class _RepState extends State<_Rep> {
  Timer? t;

  void _stop() {
    t?.cancel();
    t = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            onTap: widget.onStep,
            onLongPressStart: (_) {
              widget.onStep();
              t = Timer.periodic(const Duration(milliseconds: 70), (_) => widget.onStep());
            },
            onLongPressEnd: (_) => _stop(),
            onLongPressCancel: _stop,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.6),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(widget.icon),
            ),
          ),
        ),
      );
}
