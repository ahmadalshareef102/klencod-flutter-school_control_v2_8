import 'package:flutter/material.dart';
import '../data_io.dart';
import '../db.dart';
import '../distribution.dart';
import '../pdf_reports.dart';
import '../widgets.dart';

/// التوزيع المتقدم: ضوابط ← حصص اللجان ← معاينة وتعديل واعتماد.
class SmartDistributionScreen extends StatefulWidget {
  const SmartDistributionScreen({super.key});
  @override
  State<SmartDistributionScreen> createState() => _SmartDistributionState();
}

class _SmartDistributionState extends State<SmartDistributionScreen> {
  int step = 0, token = 0;
  List<DbRow> classes = [];
  List<DistStudent> all = [];
  Map<int, String> cname = {};
  final Set<int> use = {};
  bool separate = true, renumber = false, loading = true;
  final capCtrl = TextEditingController(text: '30');
  final mCtrl = TextEditingController(text: '0');
  final fCtrl = TextEditingController(text: '0');
  final xCtrl = TextEditingController(text: '0');
  List<CommitteeSpec> specs = [];
  PlanResult? plan;
  Map<int, List<int>> assign = {};
  List<String> issues = [];
  String school = '', year = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    classes = await Db.classes();
    cname = {for (final c in classes) c['id'] as int: '${c['name']}'};
    final rows = await Db.students();
    all = [
      for (final r in rows)
        DistStudent(r['id'] as int, '${r['name']}', r['class_id'] as int,
            '${r['gender'] ?? 'ذكر'}',
            seat: r['seat_no'] as int?)
    ];
    for (final s in all) {
      use.add(s.classId);
    }
    capCtrl.text = await Db.setting('committee_capacity');
    separate = (await Db.setting('separate_gender')) == '1';
    school = await Db.setting('school');
    year = await Db.setting('year');
    if (mounted) setState(() => loading = false);
  }

  int get capacity => int.tryParse(capCtrl.text.trim()) ?? 30;
  Map<int, DistStudent> get byId => {for (final s in all) s.id: s};
  List<DistStudent> get part => all.where((s) => use.contains(s.classId)).toList();

  int _count(int c, String g) => all
      .where((s) => s.classId == c && (g == 'X' || s.code == g))
      .length;

  void _generate() {
    if (use.isEmpty) return toast(context, 'اختر صفاً واحداً على الأقل');
    specs = autoSpecs(
      students: all,
      classes: use,
      separate: separate,
      capacity: capacity,
      males: int.tryParse(mCtrl.text.trim()) ?? 0,
      females: int.tryParse(fCtrl.text.trim()) ?? 0,
      mixed: int.tryParse(xCtrl.text.trim()) ?? 0,
    );
    token++;
    plan = null;
    setState(() => step = 1);
  }

  void _run() {
    final r = runDistribution(
        students: part, specs: specs, separate: separate, classNames: cname);
    plan = r;
    assign = {for (final e in r.assign.entries) e.key: [...e.value]};
    _recheck();
    setState(() => step = 2);
  }

  Map<int, String> get _gender => {for (final s in specs) s.no: s.gender};

  void _recheck() {
    final base = [
      ...plan?.errors ?? <String>[],
      ...plan?.warnings ?? <String>[],
    ];
    issues = {
      ...base,
      ...checkPlan(
        assign: assign,
        students: part,
        classes: use,
        capacity: capacity,
        separate: separate,
        committeeGender: _gender,
      ),
    }.toList();
  }

  List<DistStudent> _members(int no) {
    final m = byId;
    return [for (final id in assign[no] ?? <int>[]) m[id]!]..sort(compareAlpha);
  }

  Future<void> _move(DistStudent s, int from) async {
    final others = specs.where((e) => e.no != from).toList();
    final to = await showOptions<int>(context, 'نقل ${s.name} إلى لجنة', [
      for (final e in others)
        Opt(Icons.meeting_room_outlined, 'لجنة ${e.no} (${e.label})', e.no,
            '${assign[e.no]?.length ?? 0} طالب حالياً'),
    ]);
    if (to == null) return;
    assign[from]!.remove(s.id);
    assign[to] = [...?assign[to], s.id];
    _recheck();
    setState(() {});
  }

  Map<int, int> _seats() {
    final out = <int, int>{};
    for (final no in assign.keys) {
      final m = _members(no);
      for (var i = 0; i < m.length; i++) {
        out[m[i].id] = no * 1000 + i + 1;
      }
    }
    return out;
  }

  List<CommitteeDetail> _details() {
    final seats = renumber ? _seats() : <int, int>{};
    final out = <CommitteeDetail>[];
    final nos = assign.keys.toList()..sort();
    for (final no in nos) {
      final m = _members(no);
      if (m.isEmpty) continue;
      final counts = <String, int>{};
      for (final s in m) {
        final n = cname[s.classId] ?? '${s.classId}';
        counts[n] = (counts[n] ?? 0) + 1;
      }
      final spec = specs.firstWhere((e) => e.no == no, orElse: () => CommitteeSpec(no, 'X'));
      out.add(CommitteeDetail(
        no,
        spec.label,
        counts,
        m.where((s) => s.code == 'M').length,
        m.where((s) => s.code == 'F').length,
        [
          for (var i = 0; i < m.length; i++)
            [
              '${i + 1}', m[i].name, cname[m[i].classId] ?? '', m[i].gender,
              '${m[i].id}', '${seats[m[i].id] ?? m[i].seat ?? ''}',
            ]
        ],
      ));
    }
    return out;
  }

  Future<void> _approve() async {
    final errs = issues.where((e) => e.contains('بلا لجنة') || e.contains('لم يُدرجوا') || e.contains('مكرر')).toList();
    if (errs.isNotEmpty &&
        !await confirmDialog(context,
            'توجد مشاكل في التوزيع:\n${errs.take(4).join('\n')}\nهل تريد الاعتماد رغم ذلك؟',
            ok: 'اعتماد')) {
      return;
    }
    final d = await Db.get();
    final seats = renumber ? _seats() : <int, int>{};
    final ids = use.toList();
    await d.transaction((txn) async {
      await txn.rawUpdate(
          'UPDATE students SET committee_no=NULL WHERE class_id IN (${ids.map((_) => '?').join(',')})',
          ids);
      final b = txn.batch();
      for (final e in assign.entries) {
        for (final id in e.value) {
          b.update(
              'students',
              {
                'committee_no': e.key,
                if (renumber) 'seat_no': seats[id],
              },
              where: 'id=?',
              whereArgs: [id]);
        }
      }
      await b.commit(noResult: true);
    });
    if (mounted) toast(context, 'تم اعتماد التوزيع على ${assign.length} لجنة');
  }

  Future<void> _out(String action) async {
    final data = _details();
    if (data.isEmpty) return toast(context, 'لا توجد لجان للطباعة');
    try {
      if (action == 'print' || action == 'share') {
        final bytes = await buildCommitteeDetails(data, school, year);
        await printPdf(bytes, 'توزيع اللجان', share: action == 'share');
      } else {
        final rows = <List<String>>[
          for (final d in data)
            for (final r in d.rows) ['${d.no}', ...r]
        ];
        await exportTable(
            ExportTable('توزيع_اللجان',
                ['اللجنة', 'م', 'الاسم', 'الصف', 'الجنس', 'رقم القيد', 'رقم الجلوس'], rows),
            xlsx: action == 'xlsx');
      }
    } catch (e) {
      if (mounted) toast(context, 'تعذر التنفيذ: $e');
    }
  }

  // ---------------- الخطوة 1: الضوابط ----------------
  Widget _stepRules() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('1) الصفوف المشاركة', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      for (final c in classes)
        if (_count(c['id'] as int, 'X') > 0)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${c['name']}'),
            subtitle: Text(
                'ذكور ${_count(c['id'] as int, 'M')} • إناث ${_count(c['id'] as int, 'F')} • الكل ${_count(c['id'] as int, 'X')}'),
            value: use.contains(c['id']),
            onChanged: (v) => setState(() =>
                v == true ? use.add(c['id'] as int) : use.remove(c['id'] as int)),
          ),
      if (all.isEmpty) const Text('لا يوجد طلاب. أضف طلاباً أولاً.'),
      const Divider(),
      Text('2) الضوابط', style: Theme.of(context).textTheme.titleMedium),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('فصل الذكور عن الإناث'),
        subtitle: Text(separate
            ? 'لجان ذكور مستقلة ولجان إناث مستقلة، وكل جنس يُرتَّب أبجدياً وحده'
            : 'لجان مختلطة، وترتيب أبجدي واحد لطلاب كل صف'),
        value: separate,
        onChanged: (v) => setState(() => separate = v),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: capCtrl,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'السعة القصوى للجنة (عدد الطلاب)'),
      ),
      const SizedBox(height: 10),
      if (separate)
        Row(children: [
          Expanded(
            child: TextField(
              controller: mCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'عدد لجان الذكور', helperText: '0 = تلقائي'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: fCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'عدد لجان الإناث', helperText: '0 = تلقائي'),
            ),
          ),
        ])
      else
        TextField(
          controller: xCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'عدد اللجان', helperText: '0 = يُحسب من السعة'),
        ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: all.isEmpty ? null : _generate,
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('توليد اللجان والحصص تلقائياً'),
      ),
      const SizedBox(height: 6),
      Text(
          'سيوزّع التطبيق كل صف على اللجان بالتساوي، ثم تعدّل الحصص يدوياً في الخطوة التالية إن أردت.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  // ---------------- الخطوة 2: اللجان والحصص ----------------
  Widget _stepQuotas() {
    final cs = Theme.of(context).colorScheme;
    final classIds = use.toList()..sort();
    final groups = separate ? ['M', 'F'] : ['X'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الموزَّع من المتاح', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final c in classIds)
              for (final g in groups)
                Builder(builder: (_) {
                  final avail = _count(c, g);
                  if (avail == 0) return const SizedBox();
                  final placed = specs
                      .where((s) => s.gender == g)
                      .fold<int>(0, (a, s) => a + (s.quotas[c] ?? 0));
                  final ok = placed == avail;
                  return Text(
                    '${cname[c]} ${g == 'M' ? 'ذكور' : g == 'F' ? 'إناث' : ''}: $placed من $avail',
                    style: TextStyle(color: ok ? Colors.green : Colors.orange),
                  );
                }),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      for (final sp in specs)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('لجنة ${sp.no}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Chip(label: Text(sp.label), visualDensity: VisualDensity.compact),
                const Spacer(),
                Chip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      sp.total > capacity ? Colors.red.withOpacity(.25) : cs.primaryContainer,
                  label: Text('${sp.total} / $capacity'),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: () => setState(() {
                    specs.remove(sp);
                    token++;
                  }),
                ),
              ]),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in classIds)
                  if (_count(c, sp.gender) > 0)
                    SizedBox(
                      width: 104,
                      child: TextFormField(
                        key: ValueKey('q-${sp.no}-$c-$token'),
                        initialValue: '${sp.quotas[c] ?? 0}',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: '${cname[c]}', isDense: true),
                        onChanged: (t) => setState(() => sp.quotas[c] = int.tryParse(t.trim()) ?? 0),
                      ),
                    ),
              ]),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in separate ? ['M', 'F'] : ['X'])
          OutlinedButton.icon(
            onPressed: () => setState(() {
              final next = specs.isEmpty ? 1 : specs.map((e) => e.no).reduce((a, b) => a > b ? a : b) + 1;
              specs.add(CommitteeSpec(next, g));
              token++;
            }),
            icon: const Icon(Icons.add),
            label: Text(g == 'M' ? 'لجنة ذكور' : g == 'F' ? 'لجنة إناث' : 'لجنة'),
          ),
        TextButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة التوليد التلقائي')),
      ]),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: specs.isEmpty ? null : _run,
        icon: const Icon(Icons.play_arrow),
        label: const Text('تنفيذ التوزيع'),
      ),
    ]);
  }

  // ---------------- الخطوة 3: المعاينة ----------------
  Widget _stepPreview() {
    final cs = Theme.of(context).colorScheme;
    final nos = assign.keys.toList()..sort();
    final bad = issues.isNotEmpty;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        color: (bad ? Colors.orange : Colors.green).withOpacity(.16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(bad ? Icons.warning_amber : Icons.check_circle,
                  color: bad ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Text(bad ? 'تنبيهات التحقق' : 'التحقق سليم: كل الطلاب مدرجون بلا تكرار وضمن السعة',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            for (final i in issues) Text('• $i', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('إعادة ترقيم الجلوس حسب اللجنة'),
        subtitle: const Text('رقم الجلوس = رقم اللجنة×1000 + الترتيب الأبجدي داخلها'),
        value: renumber,
        onChanged: (v) => setState(() => renumber = v),
      ),
      for (final no in nos)
        Card(
          child: ExpansionTile(
            shape: const Border(),
            title: Text(
                'لجنة $no • ${specs.firstWhere((e) => e.no == no, orElse: () => CommitteeSpec(no, 'X')).label} • ${assign[no]!.length} طالب'),
            subtitle: Builder(builder: (_) {
              final m = _members(no);
              final counts = <String, int>{};
              for (final s in m) {
                final n = cname[s.classId] ?? '';
                counts[n] = (counts[n] ?? 0) + 1;
              }
              return Text(
                  'ذكور ${m.where((s) => s.code == 'M').length} • إناث ${m.where((s) => s.code == 'F').length}\n'
                  '${counts.entries.map((e) => '${e.key}: ${e.value}').join('، ')}',
                  style: TextStyle(color: cs.primary));
            }),
            children: [
              for (final s in _members(no))
                ListTile(
                  dense: true,
                  title: Text(s.name),
                  subtitle: Text('${cname[s.classId]} • ${s.gender}'),
                  trailing: IconButton(
                    tooltip: 'نقل إلى لجنة أخرى',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => _move(s, no),
                  ),
                ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _approve,
        icon: const Icon(Icons.verified),
        label: const Text('اعتماد التوزيع وحفظه'),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _out('print'),
              icon: const Icon(Icons.print),
              label: const Text('طباعة')),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _out('share'),
              icon: const Icon(Icons.ios_share),
              label: const Text('PDF')),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: OutlinedButton.icon(
              onPressed: () => _out('xlsx'),
              icon: const Icon(Icons.table_chart),
              label: const Text('Excel')),
        ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('التوزيع المتقدم للجان')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: SegmentedButton<int>(
            segments: [
              const ButtonSegment(value: 0, label: Text('الضوابط'), icon: Icon(Icons.tune)),
              ButtonSegment(
                  value: 1,
                  label: const Text('الحصص'),
                  icon: const Icon(Icons.grid_view),
                  enabled: specs.isNotEmpty),
              ButtonSegment(
                  value: 2,
                  label: const Text('المعاينة'),
                  icon: const Icon(Icons.fact_check_outlined),
                  enabled: plan != null),
            ],
            selected: {step},
            onSelectionChanged: (s) => setState(() => step = s.first),
          ),
        ),
        Expanded(child: [_stepRules(), _stepQuotas(), _stepPreview()][step]),
      ]),
    );
  }
}
