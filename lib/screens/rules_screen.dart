import 'package:flutter/material.dart';
import '../db.dart';
import '../widgets.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  static const sections = <(String, List<(String, String)>)>[
    ('سقوف الدرجات الفصلية لكل مادة', [
      ('max_t1_work', 'المحصلة الأولى'),
      ('max_t1_exam', 'اختبار نصف العام'),
      ('max_t2_work', 'المحصلة الثانية'),
      ('max_t2_exam', 'الاختبار النهائي'),
    ]),
    ('قواعد النجاح', [
      ('min_percent', 'نسبة النجاح في المادة %'),
      ('max_failed_second_round', 'أقصى عدد مواد للدور الثاني'),
    ]),
    ('حدود التقديرات (نسبة مئوية دنيا)', [
      ('r_excellent', 'ممتاز من'),
      ('r_verygood', 'جيد جداً من'),
      ('r_good', 'جيد من'),
      ('r_ok', 'مقبول من'),
    ]),
    ('الدرجات الشهرية (السقف)', [
      ('m_hw', 'المكوّن الأول'),
      ('m_att', 'المكوّن الثاني'),
      ('m_oral', 'المكوّن الثالث'),
      ('m_written', 'المكوّن الرابع'),
      ('m_convert', 'تتحول إلى (السقف الجديد)'),
    ]),
    ('أسماء مكونات الدرجة الشهرية', [
      ('ml_hw', 'اسم المكوّن الأول'),
      ('ml_att', 'اسم المكوّن الثاني'),
      ('ml_oral', 'اسم المكوّن الثالث'),
      ('ml_written', 'اسم المكوّن الرابع'),
    ]),
    ('نطاق أشهر كل فصل (رقم الشهر 1-12)', [
      ('sem1_from', 'الفصل الأول: من شهر'),
      ('sem1_to', 'الفصل الأول: إلى شهر'),
      ('sem2_from', 'الفصل الثاني: من شهر'),
      ('sem2_to', 'الفصل الثاني: إلى شهر'),
    ]),
    ('اللجان', [('committee_capacity', 'سعة اللجنة (عدد الطلاب)')]),
  ];
  static const textKeys = {'ml_hw', 'ml_att', 'ml_oral', 'ml_written'};
  final ctrls = <String, TextEditingController>{};
  bool sep = true;
  bool seatAlpha = true;

  @override
  void initState() {
    super.initState();
    Db.setting('separate_gender').then((v) => setState(() => sep = v == '1'));
    Db.setting('seat_order').then((v) => setState(() => seatAlpha = v != 'reg'));
    for (final sec in sections) {
      for (final f in sec.$2) {
        ctrls[f.$1] = TextEditingController();
        Db.setting(f.$1).then((v) {
          if (mounted) setState(() => ctrls[f.$1]!.text = v);
        });
      }
    }
  }

  Future<void> _reset() async {
    if (!await confirmDialog(context, 'استعادة القيم الافتراضية لكل القواعد؟')) return;
    for (final sec in sections) {
      for (final f in sec.$2) {
        final v = Db.defaults[f.$1] ?? '';
        await Db.setSetting(f.$1, v);
        ctrls[f.$1]?.text = v;
      }
    }
    await Db.setSetting('separate_gender', '1');
    await Db.setSetting('seat_order', 'alpha');
    setState(() {
      sep = true;
      seatAlpha = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('قواعد الدرجات والنتائج'), actions: [
          IconButton(
              tooltip: 'استعادة الافتراضي',
              icon: const Icon(Icons.restore),
              onPressed: _reset),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final sec in sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(sec.$1, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final f in sec.$2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: ctrls[f.$1],
                  keyboardType: textKeys.contains(f.$1)
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: f.$2),
                  onChanged: (v) => Db.setSetting(f.$1, v.trim()),
                ),
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('فصل الذكور عن الإناث في اللجان'),
            value: sep,
            onChanged: (v) {
              setState(() => sep = v);
              Db.setSetting('separate_gender', v ? '1' : '0');
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ترقيم الجلوس أبجدياً داخل كل صف'),
            subtitle: const Text(
                'الطالب الجديد (أو الذي نُسي) يدخل مكانه الأبجدي ويُعاد ترقيم من بعده'),
            value: seatAlpha,
            onChanged: (v) {
              setState(() => seatAlpha = v);
              Db.setSetting('seat_order', v ? 'alpha' : 'reg');
            },
          ),
          const SizedBox(height: 8),
          Text('تُطبَّق التغييرات فوراً. طابق القيم مع لوائح الوزارة.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
