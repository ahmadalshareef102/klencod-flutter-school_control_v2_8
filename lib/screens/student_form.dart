import 'dart:io';
import 'package:flutter/material.dart';
import '../data_io.dart';
import '../app_state.dart';
import '../dates.dart';
import '../db.dart';
import '../license.dart';
import '../widgets.dart';
import 'license_screen.dart';

class StudentForm extends StatefulWidget {
  final int? id;
  final int? presetClass;
  const StudentForm({super.key, this.id, this.presetClass});
  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  final name = TextEditingController();
  final regNo = TextEditingController();
  final section = TextEditingController(text: 'أ');
  final phone = TextEditingController();
  final guardian = TextEditingController();
  final notes = TextEditingController();
  final address = TextEditingController();
  String? photo;
  String gender = 'ذكر', status = 'مستجد', year = '';
  int classId = 1;
  DateTime? birth;
  DateTime regDate = DateTime.now();
  List<DbRow> classes = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _parse(Object? v) => v == null ? null : DateTime.tryParse('$v');

  Future<void> _load() async {
    classes = await Db.classes();
    year = await Db.setting('year');
    classId = widget.presetClass ?? 1;
    if (widget.id == null) {
      final dg = await Db.setting('default_gender');
      if (dg == 'أنثى') gender = 'أنثى';
    }
    if (widget.id != null) {
      final r = await (await Db.get())
          .query('students', where: 'id=?', whereArgs: [widget.id]);
      if (r.isNotEmpty) {
        final s = r.first;
        name.text = '${s['name'] ?? ''}';
        regNo.text = '${s['reg_no'] ?? ''}';
        section.text = '${s['section'] ?? 'أ'}';
        phone.text = '${s['phone'] ?? ''}';
        guardian.text = '${s['guardian'] ?? ''}';
        notes.text = '${s['notes'] ?? ''}';
        address.text = '${s['address'] ?? ''}';
        final ph = '${s['photo'] ?? ''}';
        photo = ph.isEmpty ? null : ph;
        gender = '${s['gender'] ?? 'ذكر'}';
        status = '${s['status'] ?? 'مستجد'}';
        classId = s['class_id'] as int;
        birth = _parse(s['birth']);
        regDate = _parse(s['reg_date']) ?? DateTime.now();
      }
    }
    if (mounted) setState(() => loading = false);
  }

  String _fmt(DateTime d) =>
      fmtDate(d, hijri: AppState.hijri.value, offset: AppState.hijriOffset);

  Future<void> _pick(bool isBirth) async {
    final init = (isBirth ? birth : regDate) ?? DateTime(2015);
    final d = await showDatePicker(
        context: context,
        initialDate: init,
        firstDate: DateTime(1980),
        lastDate: DateTime(2100));
    if (d != null) setState(() => isBirth ? birth = d : regDate = d);
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty) return toast(context, 'اكتب اسم الطالب');
    final reg = regNo.text.trim().isEmpty ? null : int.tryParse(regNo.text.trim());
    if (regNo.text.trim().isNotEmpty && reg == null) {
      return toast(context, 'رقم القيد يجب أن يكون رقماً');
    }
    final m = <String, Object?>{
      'name': name.text.trim(),
      'gender': gender,
      'class_id': classId,
      'section': section.text.trim().isEmpty ? 'أ' : section.text.trim(),
      'status': status,
      'phone': phone.text.trim(),
      'guardian': guardian.text.trim(),
      'notes': notes.text.trim(),
      'address': address.text.trim(),
      'photo': photo ?? '',
      'birth': birth == null ? null : isoDate(birth!),
      'reg_date': isoDate(regDate),
      if (reg != null) 'reg_no': reg,
    };
    if (widget.id == null) {
      try {
        final id = await Db.addStudent(m);
        final seat = await Db.seatOf(id);
        final shifted = Db.lastSeatShift;
        final alpha = (await Db.setting('seat_order')) != 'reg';
        if (mounted) {
          toast(
              context,
              alpha
                  ? 'أُدرج الطالب بترتيبه الأبجدي • رقم جلوسه $seat'
                      '${shifted > 1 ? ' • تغيّر رقم جلوس ${shifted - 1} طالب بعده' : ''}'
                  : 'تمت الإضافة • رقم جلوسه $seat');
        }
      } on LicenseLimitException catch (e) {
        if (mounted) await showLimitDialog(context, e.limit);
        return;
      }
    } else {
      await Db.updateStudent(widget.id!, m);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'إضافة طالب جديد' : 'تعديل بيانات الطالب'),
        actions: [
          TextButton.icon(
              onPressed: _save, icon: const Icon(Icons.check), label: const Text('حفظ')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          CircleAvatar(
            radius: 38,
            backgroundImage: (photo != null && File(photo!).existsSync())
                ? ResizeImage(FileImage(File(photo!)), width: 300)
                : null,
            child: (photo != null && File(photo!).existsSync())
                ? null
                : const Icon(Icons.person, size: 38),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await pickAndStoreImage('student');
                  if (p != null) setState(() => photo = p);
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('صورة الطالب'),
              ),
              if (photo != null)
                TextButton(
                    onPressed: () => setState(() => photo = null),
                    child: const Text('إزالة')),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'اسم الطالب رباعي')),
        const SizedBox(height: 12),
        TextField(
            controller: regNo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'رقم القيد / السجل', helperText: 'اتركه فارغاً للترقيم التلقائي')),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ذكر', label: Text('ذكر'), icon: Icon(Icons.male)),
            ButtonSegment(value: 'أنثى', label: Text('أنثى'), icon: Icon(Icons.female)),
          ],
          selected: {gender},
          onSelectionChanged: (s) {
            setState(() => gender = s.first);
            if (widget.id == null) Db.setSetting('default_gender', gender);
          },
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 3,
            child: Pick<int>(
              label: 'الصف',
              value: classId,
              items: [
                for (final c in classes)
                  DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']}'))
              ],
              onChanged: (v) => setState(() => classId = v!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
                controller: section,
                decoration: const InputDecoration(labelText: 'الفصل / الشعبة')),
          ),
        ]),
        const SizedBox(height: 12),
        Pick<String>(
          label: 'حالة القيد',
          value: status,
          items: [
            for (final s in ['مستجد', 'معيد', 'محوّل'])
              DropdownMenuItem(value: s, child: Text(s))
          ],
          onChanged: (v) => setState(() => status = v!),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _pick(false),
                icon: const Icon(Icons.event),
                label: Text('تاريخ التسجيل\n${_fmt(regDate)}', textAlign: TextAlign.center)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
                onPressed: () => _pick(true),
                icon: const Icon(Icons.cake_outlined),
                label: Text('تاريخ الميلاد\n${birth == null ? 'غير محدد' : _fmt(birth!)}',
                    textAlign: TextAlign.center)),
          ),
        ]),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'العام الدراسي'),
          child: Text(year),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: address,
            decoration: const InputDecoration(labelText: 'العنوان')),
        const SizedBox(height: 12),
        TextField(
            controller: guardian,
            decoration: const InputDecoration(labelText: 'اسم ولي الأمر')),
        const SizedBox(height: 12),
        TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'رقم ولي الأمر')),
        const SizedBox(height: 12),
        TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'ملاحظات')),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('حفظ الطالب')),
      ]),
    );
  }
}
