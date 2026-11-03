import 'package:flutter/material.dart';
import '../db.dart';
import '../widgets.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});
  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  int classId = 1;
  List<DbRow> classes = [], subjects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    classes = await Db.classes();
    subjects = await Db.subjectsOf(classId);
    if (mounted) setState(() {});
  }

  Future<String?> _ask(String title, String initial) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'اسم المادة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    final t = c.text.trim();
    return ok == true && t.isNotEmpty ? t : null;
  }

  bool _exists(String name, [int? exceptId]) => subjects.any(
      (s) => '${s['name']}'.trim() == name && s['id'] != exceptId);

  Future<void> _add() async {
    final n = await _ask('إضافة مادة جديدة', '');
    if (n == null) return;
    if (_exists(n)) return toast(context, 'هذه المادة موجودة مسبقاً');
    await (await Db.get()).insert('subjects', {'class_id': classId, 'name': n});
    _load();
  }

  Future<void> _rename(DbRow s) async {
    final n = await _ask('تعديل اسم المادة', '${s['name']}');
    if (n == null) return;
    if (_exists(n, s['id'] as int)) return toast(context, 'هذه المادة موجودة مسبقاً');
    await (await Db.get())
        .update('subjects', {'name': n}, where: 'id=?', whereArgs: [s['id']]);
    _load();
  }

  Future<void> _delete(DbRow s) async {
    if (!await confirmDialog(context,
        'حذف المادة «${s['name']}» مع كل درجاتها؟ لا يمكن التراجع.',
        ok: 'حذف', danger: true)) {
      return;
    }
    final d = await Db.get();
    await d.delete('grades', where: 'subject_id=?', whereArgs: [s['id']]);
    await d.delete('monthly', where: 'subject_id=?', whereArgs: [s['id']]);
    await d.delete('subjects', where: 'id=?', whereArgs: [s['id']]);
    _load();
  }

  Future<void> _menu() async {
    final v = await showOptions<String>(context, 'خيارات المواد', const [
      Opt(Icons.copy_all, 'نسخ مواد هذا الصف إلى صف آخر', 'copy'),
      Opt(Icons.restart_alt, 'استعادة مواد هذا الصف الافتراضية', 'reset',
          'يضيف المواد الناقصة فقط'),
    ]);
    if (v == null || !mounted) return;
    final d = await Db.get();
    if (v == 'reset') {
      final defaults = classId >= 10 ? Db.secSubjects : Db.basicSubjects;
      for (final n in defaults) {
        if (!_exists(n)) await d.insert('subjects', {'class_id': classId, 'name': n});
      }
    }
    if (v == 'copy') {
      final target = await showOptions<int>(context, 'انسخ إلى', [
        for (final c in classes)
          if (c['id'] != classId) Opt(Icons.school, '${c['name']}', c['id'] as int),
      ]);
      if (target == null) return;
      final existing = (await Db.subjectsOf(target)).map((e) => '${e['name']}').toSet();
      for (final s in subjects) {
        if (!existing.contains('${s['name']}')) {
          await d.insert('subjects', {'class_id': target, 'name': s['name']});
        }
      }
      if (mounted) toast(context, 'تم النسخ');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المواد الدراسية'), actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: _menu),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('إضافة مادة')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Pick<int>(
              label: 'الصف',
              value: classId,
              items: [
                for (final c in classes)
                  DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}'))
              ],
              onChanged: (v) {
                classId = v!;
                _load();
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = subjects[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text('${s['name']}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _rename(s)),
                      IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                          onPressed: () => _delete(s)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}
