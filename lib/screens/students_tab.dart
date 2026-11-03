import 'package:flutter/material.dart';
import '../db.dart';
import '../license.dart';
import '../widgets.dart';
import 'license_screen.dart';
import 'excel_center.dart';
import 'student_form.dart';
import 'student_profile.dart';

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});
  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  int? classId;
  String? section;
  String q = '';
  String year = '';
  List<DbRow> classes = [], rows = [];
  List<String> sections = [];
  Map<int, String> names = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    classes = await Db.classes();
    names = {for (final c in classes) c['id'] as int: '${c['name']}'};
    sections = classId == null ? [] : await Db.sectionsOf(classId!);
    if (section != null && !sections.contains(section)) section = null;
    rows = await Db.students(classId: classId, section: section, q: q);
    year = await Db.setting('year');
    if (mounted) setState(() {});
  }

  Future<void> _go(Widget w) async {
    await open(context, w);
    _load();
  }

  Future<void> _addMenu() async {
    final v = await showOptions<String>(context, 'إضافة طلاب', const [
      Opt(Icons.person_add, 'إضافة طالب (نموذج كامل)', 'one'),
      Opt(Icons.playlist_add, 'إضافة قائمة أسماء دفعة واحدة', 'bulk',
          'الصق الأسماء، اسم في كل سطر'),
    ]);
    if (v == 'one') _go(StudentForm(presetClass: classId));
    if (v == 'bulk') _bulk();
  }

  Future<void> _excelMenu() async {
    final v = await showOptions<int>(context, 'Excel و CSV', const [
      Opt(Icons.upload_file, 'استيراد طلاب من ملف', 1),
      Opt(Icons.download, 'تصدير قائمة الطلاب', 0),
      Opt(Icons.table_chart_outlined, 'تنزيل قالب فارغ', 2),
    ]);
    if (v != null) _go(ExcelCenter(initialTab: v));
  }

  Future<void> _bulk() async {
    final text = TextEditingController();
    final sec = TextEditingController(text: section ?? 'أ');
    var cid = classId ?? 1;
    var gender = (await Db.setting('default_gender')) == 'أنثى' ? 'أنثى' : 'ذكر';
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('إضافة قائمة أسماء'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Pick<int>(
                label: 'الصف',
                value: cid,
                items: [
                  for (final c in classes)
                    DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}'))
                ],
                onChanged: (v) => set(() => cid = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: sec,
                  decoration: const InputDecoration(labelText: 'الفصل / الشعبة')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ذكر', label: Text('ذكور')),
                  ButtonSegment(value: 'أنثى', label: Text('إناث')),
                ],
                selected: {gender},
                onSelectionChanged: (s) => set(() => gender = s.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: text,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                    labelText: 'الأسماء', hintText: 'اسم الطالب في كل سطر'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await Db.setSetting('default_gender', gender);
    var n = 0;
    int? hitLimit;
    for (final line in text.text.split('\n')) {
      final name = line.trim();
      if (name.isEmpty) continue;
      try {
        await Db.addStudent({
          'name': name,
          'gender': gender,
          'class_id': cid,
          'section': sec.text.trim().isEmpty ? 'أ' : sec.text.trim(),
          'status': 'مستجد',
        }, reseat: false);
        n++;
      } on LicenseLimitException catch (e) {
        hitLimit = e.limit;
        break;
      }
    }
    if (n > 0) await Db.assignSeats(cid);
    if (mounted) toast(context, 'تمت إضافة $n طالب بالترتيب الأبجدي');
    if (hitLimit != null && mounted) await showLimitDialog(context, hitLimit);
    _load();
  }

  /// يغيّر جنس كل الطلاب المعروضين حالياً (حسب الصف والشعبة والبحث).
  Future<void> _setGender(String g) async {
    if (rows.isEmpty) return;
    if (!await confirmDialog(context,
        'تحويل ${rows.length} طالب (المعروضين الآن) إلى ${g == 'أنثى' ? 'إناث' : 'ذكور'}؟',
        ok: 'تحويل')) {
      return;
    }
    final d = await Db.get();
    final b = d.batch();
    for (final s in rows) {
      b.update('students', {'gender': g}, where: 'id=?', whereArgs: [s['id']]);
    }
    await b.commit(noResult: true);
    await Db.setSetting('default_gender', g);
    if (mounted) toast(context, 'تم تحويل ${rows.length} طالب');
    _load();
  }

  /// إعادة ترقيم الجلوس لصف (أو لكل الصفوف) أبجدياً أو حسب القيد.
  Future<void> _reseat(String order) async {
    final what = classId == null ? 'لكل الصفوف' : 'للصف المختار';
    final how = order == 'alpha' ? 'أبجدياً' : 'حسب ترتيب القيد';
    if (!await confirmDialog(
        context,
        'سيُعاد ترقيم الجلوس $what $how.\n'
        'إن كنت قد وزّعت اللجان أو طبعت بطاقات الجلوس فأعد طباعتها بعد ذلك.',
        ok: 'إعادة الترقيم')) {
      return;
    }
    final n = classId == null
        ? await Db.reseatAll(order: order)
        : await Db.assignSeats(classId!, order: order);
    await Db.setSetting('seat_order', order);
    if (mounted) toast(context, 'تمت إعادة الترقيم • تغيّر رقم جلوس $n طالب');
    _load();
  }

  Future<void> _more(DbRow s) async {
    final id = s['id'] as int;
    final v = await showOptions<String>(context, '${s['name']}', const [
      Opt(Icons.person_search, 'ملف الطالب', 'profile'),
      Opt(Icons.edit, 'تعديل البيانات', 'edit'),
      Opt(Icons.badge_outlined, 'طباعة بطاقة الطالب', 'card'),
      Opt(Icons.verified_outlined, 'طباعة شهادة النتيجة', 'cert'),
      Opt(Icons.delete_outline, 'حذف الطالب', 'delete'),
    ]);
    if (v == null || !mounted) return;
    switch (v) {
      case 'profile':
        _go(StudentProfile(id: id));
      case 'edit':
        _go(StudentForm(id: id));
      case 'card':
        await printStudentCard(context, id);
      case 'cert':
        await printStudentCert(context, id);
      case 'delete':
        await _delete(s);
    }
  }

  Future<void> _delete(DbRow s) async {
    if (await confirmDialog(context,
        'حذف الطالب «${s['name']}» مع كل درجاته وحضوره؟ لا يمكن التراجع.',
        ok: 'حذف', danger: true)) {
      await Db.deleteStudent(s['id'] as int);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      PageHeader('قائمة الطلاب',
          subtitle: 'العام الدراسي $year',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Chip(label: Text('${rows.length} طالب'), backgroundColor: cs.primaryContainer),
            PopupMenuButton<String>(
              tooltip: 'ترتيب الجلوس',
              icon: const Icon(Icons.sort_by_alpha),
              onSelected: (v) {
                if (v == 'F' || v == 'M') {
                  _setGender(v == 'F' ? 'أنثى' : 'ذكر');
                } else {
                  _reseat(v);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'alpha', child: Text('ترتيب أبجدي وإعادة ترقيم الجلوس')),
                PopupMenuItem(value: 'reg', child: Text('الترقيم حسب ترتيب القيد')),
                PopupMenuItem(value: 'F', child: Text('تحويل الطلاب المعروضين إلى إناث')),
                PopupMenuItem(value: 'M', child: Text('تحويل الطلاب المعروضين إلى ذكور')),
              ],
            ),
          ])),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          decoration: const InputDecoration(
              hintText: 'بحث بالاسم أو رقم القيد...', prefixIcon: Icon(Icons.search)),
          onChanged: (v) {
            q = v;
            _load();
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Expanded(
            child: Pick<int?>(
              label: 'الصف',
              value: classId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('جميع الصفوف')),
                for (final c in classes)
                  DropdownMenuItem<int?>(value: c['id'] as int, child: Text('${c['name']}'))
              ],
              onChanged: (v) {
                classId = v;
                section = null;
                _load();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Pick<String?>(
              label: 'الفصل / الشعبة',
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
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
                onPressed: _addMenu,
                icon: const Icon(Icons.add),
                label: const Text('إضافة طالب')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
                onPressed: _excelMenu,
                icon: const Icon(Icons.table_chart),
                label: const Text('Excel / CSV')),
          ),
        ]),
      ),
      Expanded(
        child: rows.isEmpty
            ? const Center(child: Text('لا يوجد طلاب. أضف طالباً أو استورد من Excel.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = rows[i];
                  final phone = '${s['phone'] ?? ''}';
                  final notes = '${s['notes'] ?? ''}';
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _go(StudentProfile(id: s['id'] as int)),
                      onLongPress: () => _more(s),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          CircleAvatar(
                              radius: 24,
                              backgroundColor: cs.primaryContainer,
                              child: Text('${s['reg_no'] ?? ''}',
                                  style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${s['name']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${names[s['class_id']] ?? ''} • ${s['section'] ?? ''}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (phone.isNotEmpty)
                                Text(phone, style: Theme.of(context).textTheme.bodySmall),
                              if (notes.isNotEmpty)
                                Text(notes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.primary)),
                            ]),
                          ),
                          IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _go(StudentForm(id: s['id'] as int))),
                          IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                              onPressed: () => _delete(s)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
    ]);
  }
}
