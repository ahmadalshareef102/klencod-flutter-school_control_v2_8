import 'dart:io';
import 'package:flutter/material.dart';
import '../arabic_text.dart';
import '../cert.dart';
import '../data_io.dart';
import '../db.dart';
import '../pdf_reports.dart';
import '../widgets.dart';

class CertSettingsScreen extends StatefulWidget {
  const CertSettingsScreen({super.key});
  @override
  State<CertSettingsScreen> createState() => _CertSettingsScreenState();
}

class _CertSettingsScreenState extends State<CertSettingsScreen> {
  static const textFields = <(String, String)>[
    ('school', 'اسم المدرسة'),
    ('cert_office', 'مكتب التربية والتعليم (مثال: مكتب التربية والتعليم م/ ...)'),
    ('cert_admin', 'إدارة التربية والتعليم (مثال: إدارة التربية والتعليم م/ ...)'),
    ('cert_control_head', 'اسم رئيس الكنترول'),
    ('cert_principal', 'اسم مدير المدرسة'),
    ('cert_vice', 'اسم وكيل المدرسة'),
    ('sig_exam_dir', 'اسم مدير الاختبارات بالمديرية (للكشوف)'),
    ('sig_office_dir', 'اسم مدير مكتب التربية بالمديرية (للكشوف)'),
    ('sig_exam_gov', 'اسم مدير الاختبارات بالمحافظة (للكشوف)'),
    ('sig_office_gov', 'اسم مدير مكتب التربية بالمحافظة (للكشوف)'),
  ];
  static const images = <(String, String)>[
    ('cert_emblem', 'شعار الجمهورية (أعلى الوسط)'),
    ('cert_logo', 'شعار المدرسة (أعلى اليسار + علامة مائية)'),
    ('cert_stamp', 'ختم المدرسة (أسفل الشهادة)'),
  ];
  final ctrls = <String, TextEditingController>{};
  final paths = <String, String>{};
  bool bg = true, frame = true;

  @override
  void initState() {
    super.initState();
    for (final f in textFields) {
      ctrls[f.$1] = TextEditingController();
      Db.setting(f.$1).then((v) {
        if (mounted) setState(() => ctrls[f.$1]!.text = v);
      });
    }
    for (final i in images) {
      Db.setting(i.$1).then((v) {
        if (mounted) setState(() => paths[i.$1] = v);
      });
    }
    Db.setting('cert_bg').then((v) => setState(() => bg = v != '0'));
    Db.setting('cert_frame').then((v) => setState(() => frame = v != '0'));
  }

  Future<void> _preview() async {
    try {
      final st = await loadCertStyle();
      const subjects = ['القرآن الكريم', 'التربية الإسلامية', 'اللغة العربية',
        'اللغة الإنجليزية', 'الرياضيات', 'العلوم', 'الاجتماعيات', 'السلوك'];
      final rows = [
        for (final s in subjects) [s, '19', '28', '47', 'ممتاز'],
      ];
      final bytes = await buildResultCerts([
        ResultCertData(
          name: 'الاسم الرباعي للطالب', regNo: '3720', seat: '1935',
          className: 'الرابع أساسي', section: '2', address: 'القرية الشمالية',
          photoPath: '', heads: const ['المحصلة', 'الاختبار', 'المجموع', 'التقدير'],
          rows: rows, totals: ['152', '224', '376', 'ممتاز'],
          totalWords: arabicWords(376), rankText: ordinalAr(1), percent: '94.0',
        )
      ], st, await Db.setting('year'), 'نتيجة امتحان نهاية الفصل الدراسي الأول');
      await printPdf(bytes, 'معاينة الشهادة');
    } catch (e) {
      if (mounted) toast(context, 'تعذرت المعاينة: $e');
    }
  }

  Widget _imageRow(String key, String label) {
    final p = paths[key] ?? '';
    final has = p.isNotEmpty && File(p).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey.withOpacity(.2)),
            child: has
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(p), fit: BoxFit.contain, cacheWidth: 200,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)))
                : const Icon(Icons.image_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('اختيار'),
                  onPressed: () async {
                    final np = await pickAndStoreImage(key);
                    if (np != null) {
                      await Db.setSetting(key, np);
                      setState(() => paths[key] = np);
                    }
                  },
                ),
                if (has)
                  TextButton(
                    onPressed: () async {
                      await Db.setSetting(key, '');
                      setState(() => paths[key] = '');
                    },
                    child: const Text('إزالة'),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إعدادات الشهادة'), actions: [
          TextButton.icon(
              onPressed: _preview,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('معاينة')),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('الترويسة والتواقيع', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final f in textFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: ctrls[f.$1],
                decoration: InputDecoration(labelText: f.$2),
                onChanged: (v) => Db.setSetting(f.$1, v.trim()),
              ),
            ),
          const SizedBox(height: 8),
          Text('الشعارات والختم', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final i in images) ...[
            _imageRow(i.$1, i.$2),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('خلفية خضراء فاتحة (ورق ملوّن)'),
            subtitle: const Text('أوقفه لتوفير الحبر عند الطباعة على ورق أبيض'),
            value: bg,
            onChanged: (v) {
              setState(() => bg = v);
              Db.setSetting('cert_bg', v ? '1' : '0');
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('الإطار الزخرفي البنفسجي'),
            value: frame,
            onChanged: (v) {
              setState(() => frame = v);
              Db.setSetting('cert_frame', v ? '1' : '0');
            },
          ),
          const SizedBox(height: 8),
          Text('صورة كل طالب تُضاف من نموذج الطالب، وعنوانه من حقل «العنوان».',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
